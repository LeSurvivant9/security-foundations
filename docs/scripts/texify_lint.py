#!/usr/bin/env python3
import re
import sys
from dataclasses import dataclass
from pathlib import Path

SECTION_COMMANDS = {"section", "subsection", "part", "chapter", "lstinputlisting"}
ENVIRONMENTS_REQUIRING_LABEL = {
    "figure",
    "table",
    "equation",
    "algorithm",
    "lstlisting",
    "verbatim",
}
ILLEGAL_EXTENSIONS = {
    "input": [".tex"],
    "include": [".tex"],
    "subfile": [".tex"],
    "subfileinclude": [".tex"],
    "bibliography": [".bib"],
    "includegraphics": [
        ".pdf",
        ".png",
        ".jpg",
        ".jpeg",
        ".eps",
        ".svg",
        ".bmp",
        ".gif",
        ".tif",
        ".tiff",
        ".webp",
    ],
    "usepackage": [".sty"],
    "externaldocument": [".tex"],
}

COMMAND_RE = re.compile(r"\\([A-Za-z@]+)")
BEGIN_RE = re.compile(r"\\begin\{([^}]+)\}")
END_RE = re.compile(r"\\end\{([^}]+)\}")
LABEL_RE = re.compile(r"\\label\{[^}]+\}")
LISTING_LABEL_RE = re.compile(r"label\s*=\s*\{[^}]+\}|label\s*=\s*[^,\]]+")
ARG_RE = re.compile(r"\\([A-Za-z@]+)(?:\[[^\]]*\])?\{([^}]*)\}")
SENTENCE_RE = re.compile(
    r'(?<!\\)(?<=[.!?])(?:[\'"\)\]\u00bb]*)\s{1,}(?=[A-Za-z\u00c0-\u017f])'
)


@dataclass
class WarningItem:
    path: Path
    line: int
    message: str
    source: str = "texify-lint"


def strip_comments(line: str) -> str:
    escaped = False
    result: list[str] = []
    for char in line:
        if char == "%" and not escaped:
            break
        result.append(char)
        escaped = (char == "\\") and not escaped
        if char != "\\":
            escaped = False
    return "".join(result)


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def sentence_warnings(path: Path, lines: list[str]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    for index, raw_line in enumerate(lines, start=1):
        line = strip_comments(raw_line)
        if not line.strip():
            continue
        if SENTENCE_RE.search(line):
            warnings.append(
                WarningItem(path, index, "Sentence does not start on a new line")
            )
    return warnings


def extension_warnings(path: Path, lines: list[str]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    for index, raw_line in enumerate(lines, start=1):
        line = strip_comments(raw_line)
        if not line.strip():
            continue
        for match in ARG_RE.finditer(line):
            command = match.group(1)
            argument = match.group(2).strip()
            extensions = ILLEGAL_EXTENSIONS.get(command)
            if not extensions:
                continue
            for part in [
                piece.strip() for piece in argument.split(",") if piece.strip()
            ]:
                if any(part.endswith(ext) for ext in extensions):
                    warnings.append(
                        WarningItem(
                            path,
                            index,
                            "File argument should not include the extension",
                        )
                    )
                    break
    return warnings


def command_has_label(lines: list[str], start_index: int, command: str) -> bool:
    line = strip_comments(lines[start_index])
    if command == "lstinputlisting" and LISTING_LABEL_RE.search(line):
        return True

    for look_ahead in range(start_index, min(start_index + 4, len(lines))):
        candidate = strip_comments(lines[look_ahead])
        if not candidate.strip():
            continue
        if LABEL_RE.search(candidate):
            return True
        if look_ahead > start_index and COMMAND_RE.search(candidate):
            return False
    return False


def command_label_warnings(path: Path, lines: list[str]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    for index, raw_line in enumerate(lines):
        line = strip_comments(raw_line)
        for match in COMMAND_RE.finditer(line):
            command = match.group(1)
            if command not in SECTION_COMMANDS:
                continue
            if command_has_label(lines, index, command):
                continue
            warnings.append(WarningItem(path, index + 1, "Missing label"))
    return warnings


def environment_label_warnings(path: Path, lines: list[str]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    stack: list[tuple[str, int, bool]] = []

    for index, raw_line in enumerate(lines, start=1):
        line = strip_comments(raw_line)
        for begin_match in BEGIN_RE.finditer(line):
            environment = begin_match.group(1)
            stack.append((environment, index, False))

        if LABEL_RE.search(line):
            for pos in range(len(stack) - 1, -1, -1):
                env, start, has_label = stack[pos]
                if env in ENVIRONMENTS_REQUIRING_LABEL:
                    stack[pos] = (env, start, True)
                    break

        for end_match in END_RE.finditer(line):
            environment = end_match.group(1)
            for pos in range(len(stack) - 1, -1, -1):
                env, start, has_label = stack[pos]
                if env != environment:
                    continue
                stack.pop(pos)
                if env in ENVIRONMENTS_REQUIRING_LABEL and not has_label:
                    warnings.append(WarningItem(path, start, "Missing label"))
                break

    return warnings


def collect_warnings(path: Path) -> list[WarningItem]:
    lines = read_lines(path)
    warnings = []
    warnings.extend(sentence_warnings(path, lines))
    warnings.extend(extension_warnings(path, lines))
    warnings.extend(command_label_warnings(path, lines))
    warnings.extend(environment_label_warnings(path, lines))
    unique: dict[tuple[str, int, str], WarningItem] = {}
    for item in warnings:
        unique[(str(item.path), item.line, item.message)] = item
    return sorted(
        unique.values(), key=lambda item: (str(item.path), item.line, item.message)
    )


def main(argv: list[str]) -> int:
    paths = [Path(arg) for arg in argv[1:]]
    warnings: list[WarningItem] = []
    for path in paths:
        if path.suffix != ".tex":
            continue
        if path.exists():
            warnings.extend(collect_warnings(path))

    for item in warnings:
        print(
            f"Warning [{item.source}] in {item.path} line {item.line}: {item.message}"
        )

    return 2 if warnings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
