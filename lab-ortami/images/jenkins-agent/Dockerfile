# Jenkins agent (label: dotnet-docker): .NET SDK, Node.js, Docker CLI, git,
# dotnet-sonarscanner ve sonar-scanner. Docker daemon'i ayri container'dadir (agent-docker);
# agent ona ortak volume'daki unix soketiyle baglanir.
# Build context: lab-ortami/images; ek context `certs` = lab-ortami/certs.
ARG AGENT_TAG=3396.ve02b_5cde31b_2-4-jdk21
ARG DOTNET_SDK_TAG=10.0.404
ARG NODE_TAG=24.22.3-bookworm-slim
ARG DOCKER_TAG=29.10.0-dind

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_TAG} AS dotnet
FROM node:${NODE_TAG} AS node
FROM docker:${DOCKER_TAG} AS docker

FROM jenkins/inbound-agent:${AGENT_TAG}
ARG DOTNET_SONARSCANNER_VERSION=12.1.0
ARG SONAR_SCANNER_CLI_VERSION=8.5.0.16571
USER root
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq unzip openssh-client libicu-dev \
 && rm -rf /var/lib/apt/lists/*

# .NET SDK
COPY --from=dotnet /usr/share/dotnet /usr/share/dotnet
RUN ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet
# CI'da MSBuild'in yeniden kullanilabilir isci surecleri (node reuse) kapatilir: Jenkins build bitince
# surec agacini oldurur; sonraki build olmus surece baglanmaya calisirsa MSB4166 ("Child node exited
# prematurely") ile kirilir (Faz 5'te ekip-02'nin develop build'inde yasandi).
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false MSBUILDDISABLENODEREUSE=1

# Node.js + npm
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Docker CLI ve buildx (daemon yok)
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# SonarScanner for .NET (dotnet tool) ve sonar-scanner (CLI); surumler sabit.
RUN dotnet tool install --tool-path /opt/dotnet-tools dotnet-sonarscanner --version "${DOTNET_SONARSCANNER_VERSION}" \
 && curl -fsSL -o /tmp/ss.zip "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_CLI_VERSION}.zip" \
 && unzip -q /tmp/ss.zip -d /opt && mv "/opt/sonar-scanner-${SONAR_SCANNER_CLI_VERSION}" /opt/sonar-scanner && rm /tmp/ss.zip \
 && rm -rf /root/.nuget /root/.dotnet /tmp/NuGetScratch
ENV PATH="/opt/dotnet-tools:/opt/sonar-scanner/bin:${PATH}"

# Lab CA'si: isletim sistemi (git, curl, dotnet, npm), JVM (agent ve scanner) ve Node.
COPY --from=certs ca.crt /usr/local/share/ca-certificates/kurum-ca.crt
RUN update-ca-certificates >/dev/null \
 && keytool -importcert -noprompt -trustcacerts -alias kurum-ca \
      -file /usr/local/share/ca-certificates/kurum-ca.crt \
      -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit >/dev/null
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/kurum-ca.crt

# Docker soketi: agent-docker daemon'i soketi 990 numarali gruba acar.
RUN groupadd --gid 990 docker && usermod -aG docker jenkins
ENV DOCKER_HOST=unix:///run/agent-docker/docker.sock

COPY jenkins-agent/entrypoint.sh /usr/local/bin/lab-entrypoint
RUN chmod 0755 /usr/local/bin/lab-entrypoint
USER jenkins
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
