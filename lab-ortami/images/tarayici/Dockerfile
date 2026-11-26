# Arayuz adimlarini gercek tarayicida yapan arac imaji (Playwright + Chromium).
# Lab CA'si tarayicinin guven deposuna (NSS) eklenir; sertifika hatalari yok sayilmaz.
# Build context: lab-ortami/images
ARG PLAYWRIGHT_TAG=v1.65.1-noble
FROM mcr.microsoft.com/playwright:${PLAYWRIGHT_TAG}
ARG PLAYWRIGHT_NPM=1.65.1
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends libnss3-tools \
 && rm -rf /var/lib/apt/lists/*

# Betikler baska bir klasorden calisir; modul NODE_PATH ile bulunur (CommonJS).
WORKDIR /opt/ui
RUN npm init -y >/dev/null \
 && npm install --no-audit --no-fund "playwright@${PLAYWRIGHT_NPM}" \
 && npm cache clean --force >/dev/null 2>&1
ENV NODE_PATH=/opt/ui/node_modules \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY tarayici/entrypoint.sh /usr/local/bin/lab-entrypoint
RUN chmod 0755 /usr/local/bin/lab-entrypoint
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
CMD ["bash"]
