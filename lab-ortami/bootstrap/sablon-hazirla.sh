#!/usr/bin/env bash
# Starter repoyu hedef ortama gore hazirlar. araclar container'inda calisir.
# Kullanim: sablon-hazirla.sh <cikti-klasoru>
#
# Starter repo `nexus.kurum.test` adresiyle yazilmistir (NuGet.config, src/web-ui/.npmrc).
# Hedef ortamin Nexus adresi farkliysa butun branch'lerde bu adres degistirilir.
# Yazar, tarih ve mesajlar korunur; ayni girdi her zaman ayni commit SHA'larini uretir.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cikti="${1:?cikti klasoru gerekli}"
kaynak="${STARTER_REPO:-/lab/portal-starter}"
eski="nexus.kurum.test"
yeni="${STARTER_NEXUS_HOST:-nexus.${LAB_DOMAIN}}"

git config --global --add safe.directory '*'
git config --global advice.detachedHead false

rm -rf "$cikti"
git clone --quiet --no-local "$kaynak" "$cikti"
cd "$cikti"
# Butun branch'leri yerel branch yap
for ref in $(git for-each-ref --format='%(refname)' refs/remotes/origin); do
  b="${ref#refs/remotes/origin/}"
  [ "$b" = "HEAD" ] && continue
  git show-ref --verify --quiet "refs/heads/$b" || git branch --quiet "$b" "$ref"
done
git remote remove origin

# EKIP_KISISEL=NN verilirse .gitlab/CODEOWNERS icindeki NN yer tutuculari o ekibe gore yazilir
# (checkpoint-uygula.sh kullanir; cozum betiklerindeki codeowners_kisisellestir ile ayni kural).
ekip="${EKIP_KISISEL:-}"
port=""
[ -z "$ekip" ] || port="$(ekip_portu "$ekip")"
if [ "$eski" != "$yeni" ] || [ -n "$ekip" ]; then
  [ "$eski" = "$yeni" ] || bilgi "Nexus adresi: $eski -> $yeni"
  [ -z "$ekip" ] || bilgi "CODEOWNERS: ekip-$ekip"
  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --tree-filter "
    if [ '$eski' != '$yeni' ]; then
      for f in NuGet.config src/web-ui/.npmrc; do
        [ -f \"\$f\" ] && sed -i 's#${eski//./\\.}#${yeni}#g' \"\$f\"
      done
    fi
    if [ -n '$ekip' ] && [ -f .gitlab/CODEOWNERS ]; then
      sed -i -e '/NN yerine/d' -e 's#@egitim/ekip-NN#@${GITLAB_GROUP}/ekip-${ekip}#g' -e 's#@ekipNN-lead#@ekip${ekip}-lead#g' .gitlab/CODEOWNERS
    fi
    if [ -n '$ekip' ]; then
      for f in Jenkinsfile ci/analyze.sh; do
        [ -f \"\$f\" ] && sed -i -e 's#ekip-NN#ekip-${ekip}#g' -e 's#ekipNN#ekip${ekip}#g' -e 's#PORT_NN#${port}#g' \"\$f\"
      done
      for f in src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj; do
        [ -f \"\$f\" ] && sed -i 's#Saha\.Common\.Contracts\.EkipNN#Saha.Common.Contracts.Ekip${ekip}#g' \"\$f\"
      done
    fi
    if [ '$eski' != '$yeni' ] && [ -f Jenkinsfile ]; then
      sed -i -e 's#gitlab\\.${eski#nexus.}#gitlab.${yeni#nexus.}#g' -e 's#test-vm\\.${eski#nexus.}#test-vm.${yeni#nexus.}#g' Jenkinsfile
    fi
    true
  " -- --all >/dev/null
  git for-each-ref --format='%(refname)' refs/original | xargs -r -n1 git update-ref -d
  if [ "$eski" != "$yeni" ] && git grep -q "$eski" $(git for-each-ref --format='%(refname:short)' refs/heads) -- NuGet.config src/web-ui/.npmrc; then
    olum "adres degisimi eksik kaldi"
  fi
fi
git checkout --quiet main
bilgi "sablon hazir: $(git for-each-ref --format='%(refname:short)@%(objectname:short)' refs/heads | tr '\n' ' ')"
