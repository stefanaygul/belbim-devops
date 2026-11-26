#!/usr/bin/env bash
# CI profilinin (Faz 4) dogrulamasi: Jenkins, agent, agent'in Docker daemon'i, SonarQube.
# Host'ta calisir (bash 3.2 uyumlu). Ortamin yapilandirmasini degistirmez.
# Yan etkisi: agent'in Docker daemon'ina bir temel imaj cekilir (zaten yoksa) ve geri silinir.
# Kullanim: dogrula/ci.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source dogrula/lib.sh
source bootstrap/host-lib.sh

D="$(env_degeri LAB_DOMAIN)"
REGISTRY="gitlab.${D}:5050"
SONUC=0
AGENT="docker compose exec -T jenkins-agent"

for s in jenkins jenkins-agent agent-docker sonarqube sonar-db; do
  docker compose ps --status running --services 2>/dev/null | grep -qx "$s" || { echo "ci profili calismiyor ($s yok): make up-ci" >&2; exit 2; }
done

# --- 1. API tarafi ------------------------------------------------------------
docker compose run --rm -T araclar bash dogrula/ci-api.sh < /dev/null || SONUC=1

# --- 2. Agent: araclar, CA guveni, kendi Docker daemon'i ------------------------
baslik "Jenkins agent: araclar"
surum() { $AGENT sh -c "$1" 2>&1 < /dev/null | head -n 1 | tr -d '\r'; }
esit ".NET SDK" "$(sed -n 's/^ARG DOTNET_SDK_TAG=//p' images/jenkins-agent/Dockerfile | head -n 1)" "$(surum 'dotnet --version')"
esit "Node.js" "v$(sed -n 's/^ARG NODE_TAG=//p' images/jenkins-agent/Dockerfile | head -n 1 | cut -d- -f1)" "$(surum 'node --version')"
esit "SonarScanner for .NET (dotnet tool)" "$(sed -n 's/^ARG DOTNET_SONARSCANNER_VERSION=//p' images/jenkins-agent/Dockerfile | head -n 1)" "$($AGENT sh -c 'dotnet tool list --tool-path /opt/dotnet-tools' 2>/dev/null < /dev/null | awk '$1 == "dotnet-sonarscanner" { print $2 }')"
icerir "sonar-scanner CLI" "$(sed -n 's/^ARG SONAR_SCANNER_CLI_VERSION=//p' images/jenkins-agent/Dockerfile | head -n 1)" "$($AGENT sh -c 'sonar-scanner --version 2>&1' < /dev/null | tr '\n' ' ')"
icerir "git" "git version" "$(surum 'git --version')"
icerir "Docker CLI" "Docker version" "$(surum 'docker --version')"
esit "agent kullanicisi root degil" "jenkins" "$(surum 'id -un')"

baslik "Jenkins agent: kurum CA'si (TLS dogrulamasi acik)"
esit "curl https://gitlab.${D} (isletim sistemi deposu)" "200" "$(surum "curl -sS -o /dev/null -w '%{http_code}' --max-time 20 https://gitlab.${D}/users/sign_in")"
esit "curl https://nexus.${D}" "200" "$(surum "curl -sS -o /dev/null -w '%{http_code}' --max-time 20 https://nexus.${D}/service/rest/v1/status")"
icerir "git ls-remote (sablon proje, https)" "refs/heads/main" "$($AGENT sh -c "git ls-remote https://gitlab.${D}/egitim/sablonlar/portal-starter.git refs/heads/main" 2>&1 < /dev/null)"
esit "JVM deposu: https://sonar.${D} (scanner bu depoyu kullanir)" "kurum-ca" "$($AGENT sh -c 'keytool -list -cacerts -storepass changeit 2>/dev/null | grep -c -i "kurum\|lab"' < /dev/null | awk '{ print ($1 > 0) ? "kurum-ca" : "yok" }')"
esit "sslVerify kapatilmamis (git)" "" "$($AGENT sh -c 'git config --global --get http.sslVerify; git config --system --get http.sslVerify' 2>/dev/null < /dev/null | tr -d '\n')"

baslik "Jenkins agent: test VM SSH sunucu anahtari (5. gun deploy)"
esit "agent known_hosts icinde test-vm.${D}" "var" "$($AGENT sh -c "ssh-keygen -F test-vm.${D} -f ~/.ssh/known_hosts >/dev/null 2>&1 && echo var || echo yok" < /dev/null)"
esit "StrictHostKeyChecking kapatilmamis" "" "$($AGENT sh -c 'grep -h -i "StrictHostKeyChecking *no" ~/.ssh/config /etc/ssh/ssh_config /etc/ssh/ssh_config.d/* 2>/dev/null' < /dev/null)"

baslik "Agent'in Docker daemon'i (agent-docker)"
esit "agent ortak Docker config'inde registry girisi yok (job'lar ayri config kullanir)" "0" "$($AGENT sh -c 'if [ -f "$HOME/.docker/config.json" ]; then jq "(.auths // {}) | length" "$HOME/.docker/config.json"; else echo 0; fi' < /dev/null)"
esit "agent DOCKER_HOST" "unix:///run/agent-docker/docker.sock" "$(surum 'echo $DOCKER_HOST')"
bilgi_d="$($AGENT docker info --format '{{.Name}}|{{.ServerVersion}}|{{json .RegistryConfig.InsecureRegistryCIDRs}}|{{len .RegistryConfig.IndexConfigs}}' 2>&1 < /dev/null)"
gecti "daemon: $(cut -d'|' -f1,2 <<<"$bilgi_d")"
host_adi="$(docker info --format '{{.Name}}' 2>/dev/null)"
[ "$(cut -d'|' -f1 <<<"$bilgi_d")" != "$host_adi" ] && gecti "agent, host'un Docker daemon'ini kullanmiyor (host: $host_adi)" || kaldi "agent host'un Docker daemon'ini kullaniyor"
esit "insecure registry tanimi (yalnizca Docker'in varsayilan loopback araligi)" "127.0.0.0/8,::1/128" "$(cut -d'|' -f3 <<<"$bilgi_d" | tr -d '[]"' | tr ',' '\n' | sort | paste -sd, -)"
esit "registry CA'si daemon'da (certs.d)" "var" "$(docker compose exec -T agent-docker sh -c "test -s /etc/docker/certs.d/${REGISTRY}/ca.crt && echo var" 2>&1 < /dev/null)"
imaj="$(grep -E '^[^#]*nginx' bootstrap/temel-imajlar.tablo | head -n 1 | cut -d'|' -f1)"
if [ -n "$imaj" ]; then
  hedef="${REGISTRY}/egitim/base/${imaj}"
  vardi="$($AGENT docker images -q "$hedef" 2>/dev/null < /dev/null)"
  cikti="$($AGENT sh -c 'cfg=$(mktemp -d) || exit 1; trap "rm -rf \"$cfg\"" EXIT; docker --config "$cfg" pull -q "$1"' _ "$hedef" 2>&1 < /dev/null)"
  icerir "agent daemon'i temel imaji registry'den cekiyor (anonim, TLS dogrulamali)" "$hedef" "$cikti"
  [ -n "$vardi" ] || $AGENT docker rmi "$hedef" >/dev/null 2>&1 < /dev/null || true
fi

# --- 3. Host: daemon sayisi, soket, portlar, bellek sinirlari -------------------
baslik "Host: CI container'lari"
kimlikler="$(docker compose --profile cekirdek --profile ci ps -q)"
# shellcheck disable=SC2086
ayricalikli="$(docker inspect $kimlikler --format '{{if .HostConfig.Privileged}}{{index .Config.Labels "com.docker.compose.service"}}{{end}}' | grep . | sort | tr '\n' ' ')"
esit "kendi Docker daemon'i olan container'lar (tam uc tane)" "agent-docker test-vm workstation " "$ayricalikli"
# shellcheck disable=SC2086
soket="$(docker inspect $kimlikler --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' | grep -c -x -E '(/private)?/var/run/docker\.sock|.*/\.docker/run/docker\.sock')"
esit "host Docker soketini baglayan container" "0" "$soket"
# shellcheck disable=SC2086
acik="$(docker inspect $kimlikler --format '{{range $p, $b := .NetworkSettings.Ports}}{{range $b}}{{.HostIp}} {{end}}{{end}}' | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ')"
esit "yayinlanan portlarin host adresi" "127.0.0.1 " "$acik"
for s in jenkins jenkins-agent agent-docker sonarqube sonar-db; do
  k="$(docker compose ps -q "$s")"
  sinir="$(docker inspect "$k" --format '{{.HostConfig.Memory}}')"
  [ "$sinir" -gt 0 ] && gecti "$s bellek siniri: $((sinir / 1024 / 1024)) MiB" || kaldi "$s icin bellek siniri yok"
done
https_port="$(env_degeri HOST_HTTPS_PORT)"
for ad in jenkins sonar; do
  case "$ad" in jenkins) yol="/login" ;; sonar) yol="/api/system/status" ;; esac
  kod="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 --cacert certs/ca.crt \
    --resolve "${ad}.${D}:${https_port}:127.0.0.1" "https://${ad}.${D}:${https_port}${yol}" 2>&1)"
  esit "host -> https://${ad}.${D} (lab CA'si ile, 127.0.0.1:${https_port})" "200" "$kod"
done

ozet || SONUC=1
if [ "$SONUC" -eq 0 ]; then
  printf '\n\033[32mCI PROFILI: GECTI\033[0m\n'
else
  printf '\n\033[31mCI PROFILI: KALDI\033[0m\n'
fi
exit "$SONUC"
