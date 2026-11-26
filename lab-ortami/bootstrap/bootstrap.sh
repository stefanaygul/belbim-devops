#!/usr/bin/env bash
# Lab ortamini kurar. Host'ta calisir (bash 3.2 uyumlu); tekrar calistirmak guvenlidir.
# Kullanim: bootstrap.sh [adim ...]   adimlar: gitlab nexus imajlar workstation ws-imajlar test-vm jenkins agent-ssh sonarqube
# jenkins, agent-ssh ve sonarqube adimlari yalnizca ci profili calisiyorsa varsayilan listeye girer.
#
# Host yalnizca container'lara komut verir; API cagrilari araclar container'inda,
# lab aginin icinden ve lab CA'sina guvenerek yapilir.
set -euo pipefail
cd "$(dirname "$0")/.."

ARACLAR="docker compose run --rm -T araclar"

adim() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

gitlab_token() {
  adim "GitLab yonetici token'i"
  local kod
  kod="$($ARACLAR bash -c 'curl -sS -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: ${GITLAB_ADMIN_TOKEN}" "https://gitlab.${LAB_DOMAIN}/api/v4/version"' || true)"
  if [ "$kod" = "200" ]; then
    echo "    tamam  token gecerli"
    return 0
  fi
  echo "    token olusturuluyor (gitlab-rails runner, yaklasik 1 dakika)"
  # Token degeri komut satirina yazilmaz: Ruby betigi standart giristen okunur.
  {
    printf 'deger = "%s"\n' "$(sed -n 's/^GITLAB_ADMIN_TOKEN=//p' .env | head -n 1)"
    cat <<'RUBY'
kullanici = User.find_by_username('root')
kullanici.personal_access_tokens.where(name: 'lab-bootstrap').find_each(&:revoke!)
token = kullanici.personal_access_tokens.build(
  name: 'lab-bootstrap',
  scopes: %w[api read_repository write_repository read_registry write_registry sudo],
  expires_at: 364.days.from_now
)
token.set_token(deger)
token.save!
puts 'lab-bootstrap token olusturuldu'
RUBY
  } | docker compose exec -T gitlab gitlab-rails runner -
}

gitlab() {
  gitlab_token
  $ARACLAR bash bootstrap/10-gitlab.sh
}

nexus() {
  adim "Nexus yonetici parolasi"
  # admin.password dosyasi yalnizca ilk kurulumda vardir.
  { docker compose exec -T nexus cat /nexus-data/admin.password 2>/dev/null || true; } \
    | $ARACLAR bash bootstrap/20-nexus-parola.sh
  $ARACLAR bash bootstrap/20-nexus.sh
}

imajlar() {
  bash bootstrap/30-temel-imajlar.sh
}

test_vm() {
  bash bootstrap/40-test-vm.sh
}

workstation() {
  bash bootstrap/50-workstation.sh
}

# Temel imajlar katilimci makinesinin Docker daemon'ina onceden yuklenir (LAB 03-A).
ws_imajlar() {
  bash bootstrap/35-workstation-imajlar.sh
}

jenkins() {
  $ARACLAR bash bootstrap/60-jenkins.sh
}

agent_ssh() {
  bash bootstrap/65-agent-ssh.sh
}
sonarqube() {
  $ARACLAR bash bootstrap/70-sonarqube.sh
}

if [ "$#" -eq 0 ]; then
  set -- gitlab nexus imajlar workstation ws-imajlar test-vm
  # ci profili (Jenkins, SonarQube) calisiyorsa onun adimlari da eklenir.
  if docker compose --profile ci ps --status running --services 2>/dev/null | grep -qx jenkins; then
    set -- "$@" jenkins agent-ssh sonarqube
  fi
fi
for a in "$@"; do
  case "$a" in
    gitlab) gitlab ;;
    nexus) nexus ;;
    imajlar) imajlar ;;
    test-vm) test_vm ;;
    workstation) workstation ;;
    ws-imajlar) ws_imajlar ;;
    jenkins) jenkins ;;
    agent-ssh) agent_ssh ;;
    sonarqube) sonarqube ;;
    *) echo "Bilinmeyen adim: $a" >&2; exit 2 ;;
  esac
done

# Nexus Community Edition, EULA kabul edilmeden paket indirmeyi 403 ile reddeder.
if ! $ARACLAR bash bootstrap/20-nexus.sh eula-denetle < /dev/null; then
  printf '\n\033[31mEKSIK\033[0m  Nexus Community Edition EULA kabul edilmemis; restore ve npm ci calismaz.\n'
  printf '       Metni okuyun: https://links.sonatype.com/products/nxrm/ce-eula\n'
  printf '       Kabul ediyorsaniz .env dosyasinda NEXUS_CE_EULA_KABUL=evet ve\n'
  printf '       NEXUS_CE_TELEMETRI_ONAY=evet yazip `make bootstrap` komutunu yeniden calistirin.\n'
  exit 1
fi

printf '\n\033[1mBootstrap tamamlandi.\033[0m Denetim icin: make dogrula\n'
