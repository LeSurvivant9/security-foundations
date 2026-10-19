FROM kalilinux/kali-rolling@sha256:02f5d6c019e549b0f55da58e835cad5355ef1030c6b2645265a324e37dfc4acc

# Kali Rolling deliberately resolves the current package set at rebuild time.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dnsutils \
        hydra \
        iproute2 \
        iputils-ping \
        netcat-traditional \
        nmap \
        sqlmap \
        tealdeer \
        tcpdump \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Populate the command cheat-sheet cache at build time: the running Kali
# container deliberately has no default route outside the lab.
RUN useradd --create-home --shell /bin/bash kali \
    && su - kali -c 'tldr --update'

COPY --chmod=755 init-route.sh /usr/local/bin/init-route.sh
