#!/usr/bin/env bash
# Eğitmen demosu (slayt "GitLab Package Registry'ye NuGet yayını"): ekibin ortak paketini
# GitLab'in proje düzeyindeki NuGet deposuna yayınlar. Host'ta çalışır (bash 3.2 uyumlu).
# Yalnızca verilen ekibin projesine dokunur; demo için kısa ömürlü bir deploy token üretir ve
# sonunda iptal eder. Token komut satırına ve çıktıya yazılmaz; NuGet kaynağı geçici bir
# yapılandırma dosyasında tanımlanır ve silinir (kullanıcının NuGet.Config'i değişmez).
# Kullanim: dogrula/demo-gitlab-paket.sh <NN>
set -euo pipefail
cd "$(dirname "$0")/.."
nn="$(printf '%02d' "$((10#${1:?kullanim: demo-gitlab-paket.sh <NN>}))")"
AR="docker compose run --rm -T araclar"

bilgiler="$($AR bash -c '
source bootstrap/lib.sh
P="/projects/$(urlenc egitim/ekip-$1/saha-ekipman-portal)"
zorunlu proje gl GET "$P"; id="$(jq -r .id <<<"$HTTP_BODY")"
gl GET "$P/deploy_tokens" >/dev/null
for t in $(jq -r ".[] | select(.username == \"ekip$1-paket\") | .id" <<<"$HTTP_BODY"); do gl DELETE "$P/deploy_tokens/$t" >/dev/null; done
zorunlu token gl POST "$P/deploy_tokens" --data-urlencode "name=ekip$1-paket" --data-urlencode "username=ekip$1-paket" \
  --data-urlencode "scopes[]=read_package_registry" --data-urlencode "scopes[]=write_package_registry" --data-urlencode "expires_at=$(date -u -d "+1 day" +%F)"
printf "PROJE_ID=%s\nTOKEN=%s\n" "$id" "$(jq -r .token <<<"$HTTP_BODY")"' _ "$nn" < /dev/null 2>/dev/null | grep -E '^(PROJE_ID|TOKEN)=')"
proje_id="$(printf '%s\n' "$bilgiler" | sed -n 's/^PROJE_ID=//p')"
[ -n "$proje_id" ] || { echo "deploy token uretilemedi" >&2; exit 1; }
echo "proje kimligi: $proje_id; deploy token: ekip${nn}-paket (read/write_package_registry, 1 gun)"

{ printf '%s\n' "$bilgiler" | sed -n 's/^TOKEN=/export TOKEN=/p'; printf 'export PROJE_ID=%s\n' "$proje_id"; cat <<'WS'
set -euo pipefail
cd ~/saha-ekipman-portal
gecici="$(mktemp -d)"; trap 'rm -rf "$gecici"' EXIT
cfg="$gecici/NuGet.Config"
printf '<?xml version="1.0" encoding="utf-8"?>\n<configuration><packageSources><clear /></packageSources></configuration>\n' > "$cfg"
kaynak="$GITLAB_URL/api/v4/projects/$PROJE_ID/packages/nuget/index.json"
echo "\$ dotnet nuget add source \"$kaynak\" --name gitlab --username ekip$EKIP-paket --password \"\$TOKEN\" --store-password-in-clear-text --configfile <gecici>"
dotnet nuget add source "$kaynak" --name gitlab --username "ekip$EKIP-paket" --password "$TOKEN" --store-password-in-clear-text --configfile "$cfg" > /dev/null
dotnet pack src/common-contracts -c Release -o "$gecici/out" > /dev/null
paket="$(ls "$gecici"/out/*.nupkg)"
echo "\$ dotnet nuget push $(basename "$paket") --source gitlab"
dotnet nuget push "$paket" --source gitlab --configfile "$cfg" 2>&1 | sed -E 's#(password|token)=[^ ]+#\1=***#Ig'
WS
} | docker compose exec -T -u "ekip${nn}" workstation bash -l -s

$AR bash -c '
source bootstrap/lib.sh
P="/projects/$(urlenc egitim/ekip-$1/saha-ekipman-portal)"
gl GET "$P/packages?package_type=nuget" >/dev/null && jq -r ".[] | \"GitLab Package Registry: \(.name) \(.version) (\(.package_type))\"" <<<"$HTTP_BODY"
gl GET "$P/deploy_tokens" >/dev/null
for t in $(jq -r ".[] | select(.username == \"ekip$1-paket\") | .id" <<<"$HTTP_BODY"); do gl DELETE "$P/deploy_tokens/$t" >/dev/null && echo "demo token iptal edildi"; done' _ "$nn" < /dev/null 2>&1 | grep -v 'Container '
