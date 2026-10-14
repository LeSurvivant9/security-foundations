OUT_DIR = out
PDF = $(OUT_DIR)/main.pdf
SRC = main.tex
STY = mystyle.sty
METADATA = metadata.tex
SECTIONS = $(wildcard sections/*.tex)
BIB_FILES = $(wildcard *.bib)
LINT_FILES = $(SRC) $(STY) $(METADATA) $(SECTIONS)
FORMAT_FILES = $(SRC) $(STY) $(METADATA) $(SECTIONS)
LATEXMK = latexmk
LATEX_FLAGS = -lualatex -shell-escape -interaction=nonstopmode -halt-on-error -file-line-error -outdir=$(OUT_DIR)
CHKEX = chktex
LATEXINDENT = latexindent
UV = uv run

all: $(PDF)

$(PDF): $(SRC) $(STY) $(METADATA) $(SECTIONS) $(BIB_FILES) | $(OUT_DIR)
	$(LATEXMK) $(LATEX_FLAGS) $(SRC)

lint:
	@status=0; \
	$(CHKEX) -l .chktexrc $(LINT_FILES) || status=$$?; \
	$(UV) scripts/texify_lint.py $(LINT_FILES) || status=$$?; \
	exit $$status

check: lint all

format:
	$(LATEXINDENT) -w $(FORMAT_FILES)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

clean:
	$(LATEXMK) -C -outdir=$(OUT_DIR) $(SRC)
	rm -rf _minted-main
	rm -rf $(OUT_DIR)

.PHONY: all clean lint check format
