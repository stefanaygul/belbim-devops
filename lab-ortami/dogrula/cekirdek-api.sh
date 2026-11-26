#!/usr/bin/env bash
# Cekirdek ortamin ag icinden denetimi. araclar container'inda calisir.
# TLS dogrulamasi acik kalir: gecen her istek lab CA'sina guvenildigini de gosterir.
set -uo pipefail
source /lab/ortam/bootstrap/lib.sh
source /lab/ortam/dogrula/lib.sh

LAB_DNS="${LAB_SUBNET}.53"

# al <komut...>: istek basarisizsa denetimi KALDI sayar
al() {
  "$@" || { kaldi "istek basarisiz: $2 $3 (HTTP $HTTP_CODE)"; return 1; }
}

# `onbellek` kipi: workstation denetimlerinden sonra calisir; restore ve npm ci
# sirasinda paketlerin Nexus proxy depolarindan gectigini gosterir.
if [ "${1:-}" = "onbellek" ]; then
  baslik "Nexus proxy onbellegi"
  for depo in nuget.org-proxy npm-proxy; do
    al nx GET "/v1/components?repository=${depo}"
    sayi="$(jq '.items | length' <<<"$HTTP_BODY")"
    [ "${sayi:-0}" -gt 0 ] && gecti "$depo onbelleginde paket var (ilk sayfa: $sayi)" || kaldi "$depo onbellegi bos"
  done
  ozet
  exit $?
fi

# --- Ad cozumleme -----------------------------------------------------------
baslik "Ad cozumleme"
for ad in gitlab jenkins sonar nexus; do
  esit "${ad}.${LAB_DOMAIN} (ag takma adi)" "${LAB_SUBNET}.10" "$(getent hosts "${ad}.${LAB_DOMAIN}" | awk '{print $1}')"
  esit "${ad}.${LAB_DOMAIN} (lab DNS)" "${LAB_SUBNET}.10" "$(dig +short "@${LAB_DNS}" "${ad}.${LAB_DOMAIN}" A)"
done
esit "test-vm.${LAB_DOMAIN} (ag takma adi)" "${LAB_SUBNET}.20" "$(getent hosts "$TEST_VM" | awk '{print $1}')"
esit "test-vm.${LAB_DOMAIN} (lab DNS)" "${LAB_SUBNET}.20" "$(dig +short "@${LAB_DNS}" "$TEST_VM" A)"
[ -n "$(dig +short "@${LAB_DNS}" api.nuget.org A | head -n 1)" ] \
  && gecti "lab DNS dis adlari da cozuyor (api.nuget.org)" || kaldi "lab DNS dis adlari cozmuyor"

# --- TLS --------------------------------------------------------------------
baslik "TLS (dogrulama acik)"
for url in "$GITLAB_URL/users/sign_in" "$NEXUS_URL/service/rest/v1/status" "https://${REGISTRY}/v2/"; do
  kod="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$url" 2>/tmp/curl.err)" || kod="hata: $(cat /tmp/curl.err)"
  case "$url" in
    *"/v2/") esit "$url" "401" "$kod" ;;
    *)       esit "$url" "200" "$kod" ;;
  esac
done
# Lab CA'si olmadan ayni adres reddedilmeli (sertifikayi gercekten lab CA'si imzaliyor).
if curl -sS -o /dev/null --max-time 20 --cacert /etc/ssl/certs/ISRG_Root_X1.pem --capath /nonexistent "$GITLAB_URL/" 2>/tmp/curl.err; then
  kaldi "lab CA'si olmadan baglanti kabul edildi"
else
  icerir "lab CA'si olmadan baglanti reddediliyor" "certificate" "$(cat /tmp/curl.err)"
fi
konu="$(echo | openssl s_client -connect "gitlab.${LAB_DOMAIN}:443" -servername "gitlab.${LAB_DOMAIN}" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)"
icerir "sertifikayi veren: Egitim Lab Root CA" "Egitim Lab Root CA" "$konu"

# --- GitLab SSH (proxy uzerinden TCP gecisi) ---------------------------------
baslik "GitLab SSH"
anahtar="$(ssh-keyscan -T 10 -t ed25519 "gitlab.${LAB_DOMAIN}" 2>/dev/null | awk '{print $2}')"
esit "gitlab.${LAB_DOMAIN}:22 SSH host anahtari sunuyor" "ssh-ed25519" "$anahtar"
cikti="$(ssh -n -T -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "git@gitlab.${LAB_DOMAIN}" 2>&1)"
icerir "anahtarsiz SSH girisi GitLab tarafindan reddediliyor" "Permission denied (publickey" "$cikti"

# --- GitLab -----------------------------------------------------------------
baslik "GitLab"
al gl GET /metadata && esit "surum" "19.6.1" "$(jq -r '.version' <<<"$HTTP_BODY")"
esit "surum turu (enterprise)" "false" "$(jq -r '.enterprise' <<<"$HTTP_BODY")"

al gl GET /application/settings
esit "giden istek izin listesi" "[\"jenkins.${LAB_DOMAIN}\"]" "$(jq -c '.outbound_local_requests_whitelist' <<<"$HTTP_BODY")"
esit "webhook'lardan yerel aga istek" "false" "$(jq -r '.allow_local_requests_from_web_hooks_and_services' <<<"$HTTP_BODY")"
esit "kayit olma kapali" "false" "$(jq -r '.signup_enabled' <<<"$HTTP_BODY")"

al gl GET "/groups/$GITLAB_GROUP" && esit "grup $GITLAB_GROUP gorunurluk" "public" "$(jq -r '.visibility' <<<"$HTTP_BODY")"
al gl GET "/groups/$(urlenc "$GITLAB_GROUP/sablonlar")" && esit "grup sablonlar gorunurluk" "public" "$(jq -r '.visibility' <<<"$HTTP_BODY")"

for nn in $(ekipler); do
  yol="$GITLAB_GROUP/ekip-$nn"
  if gl GET "/groups/$(urlenc "$yol")"; then
    esit "grup $yol gorunurluk" "private" "$(jq -r '.visibility' <<<"$HTTP_BODY")"
    gid="$(jq -r '.id' <<<"$HTTP_BODY")"
    al gl GET "/groups/$gid/members"
    esit "ekip${nn}-lead rolu (40 = Maintainer)" "40" "$(jq -r --arg u "ekip${nn}-lead" '.[] | select(.username == $u) | .access_level' <<<"$HTTP_BODY")"
    esit "ekip${nn}-dev rolu (30 = Developer)" "30" "$(jq -r --arg u "ekip${nn}-dev" '.[] | select(.username == $u) | .access_level' <<<"$HTTP_BODY")"
    al gl GET "/groups/$gid/projects"
    # Bootstrap ekip projesi olusturmaz. Proje varsa bir lab yapilmis ya da checkpoint uygulanmistir;
    # o durumda bu denetim yeni kurulum icin anlamlidir ve bilgi olarak yazilir.
    if [ "$(jq 'length' <<<"$HTTP_BODY")" = "0" ]; then
      gecti "ekip-$nn altinda proje yok (katilimci olusturur)"
    else
      printf '  BILGI  ekip-%s altinda proje var: lab yapilmis ya da checkpoint uygulanmis (yeni kurulumda bos olur)\n' "$nn"
    fi
  else
    kaldi "grup $yol yok"
  fi
  # Hesap parolasi gecerli mi: registry token ucu kimlik bilgisini dogrular.
  for rol in lead dev; do
    kullanici="ekip${nn}-${rol}"
    cfg="$(_curl_cfg "u-$kullanici" "user = \"${kullanici}:$(ekip_parola "$kullanici")\"")"
    _istek "$cfg" GET "${GITLAB_URL}/jwt/auth?service=container_registry" || true
    esit "$kullanici parolasiyla giris" "200" "$HTTP_CODE"
  done
done
cfg="$(_curl_cfg u-yanlis 'user = "ekip01-lead:yanlis-parola"')"
_istek "$cfg" GET "${GITLAB_URL}/jwt/auth?service=container_registry" || true
[ "$HTTP_CODE" != "200" ] && gecti "yanlis parola reddediliyor (HTTP $HTTP_CODE)" || kaldi "yanlis parola kabul edildi"

# Sablon proje: anonim okunur, branch'ler starter repo ile ayni
sablon="$(urlenc "$GITLAB_GROUP/sablonlar/portal-starter")"
al gl GET "/projects/$sablon" && esit "sablon proje gorunurluk" "public" "$(jq -r '.visibility' <<<"$HTTP_BODY")"
esit "sablon varsayilan branch" "main" "$(jq -r '.default_branch' <<<"$HTTP_BODY")"
git config --global --add safe.directory '*'
yerel="$(bash /lab/ortam/bootstrap/sablon-hazirla.sh /tmp/sablon-dogrula >/dev/null 2>&1; git -C /tmp/sablon-dogrula for-each-ref --format='%(objectname:short) %(refname:short)' refs/heads | sort | tr '\n' ' ')"
uzak="$(git ls-remote --heads "${GITLAB_URL}/${GITLAB_GROUP}/sablonlar/portal-starter.git" | awk '{ sub("refs/heads/", "", $2); print substr($1, 1, 7) " " $2 }' | sort | tr '\n' ' ')"
esit "sablon branch'leri (anonim git ls-remote) starter ile ayni" "$yerel" "$uzak"
esit "sablonda .gitlab-ci.yml yok" "404" "$(gl GET "/projects/$sablon/repository/files/.gitlab-ci.yml?ref=main" >/dev/null 2>&1; echo "$HTTP_CODE")"

# --- Container Registry: temel imajlar ---------------------------------------
baslik "Container Registry (egitim/base, anonim okuma)"
while IFS='|' read -r hedef kaynak; do
  etiket="$(skopeo inspect --no-tags "docker://${REGISTRY}/${GITLAB_GROUP}/base/${hedef}" 2>/tmp/skopeo.err | jq -r '."Labels"."lab.kaynak" // "etiket yok"')"
  [ -n "$etiket" ] || etiket="hata: $(tail -n 1 /tmp/skopeo.err)"
  esit "$hedef" "$kaynak" "$etiket"
done <<'TABLO'
dotnet/sdk:10.0|mcr.microsoft.com/dotnet/sdk:10.0.404
dotnet/aspnet:10.0|mcr.microsoft.com/dotnet/aspnet:10.0.15
library/node:24-alpine|node:24.22.3-alpine3.24
nginxinc/nginx-unprivileged:stable-alpine|nginxinc/nginx-unprivileged:1.31.7-alpine3.24
TABLO

# --- Nexus ------------------------------------------------------------------
baslik "Nexus"
al nx GET /v1/repositories
depolar="$(jq -r '[.[] | .name + ":" + .format + ":" + .type] | sort | join(" ")' <<<"$HTTP_BODY")"
esit "depolar" "npm-group:npm:group npm-hosted:npm:hosted npm-proxy:npm:proxy nuget-group:nuget:group nuget-hosted:nuget:hosted nuget.org-proxy:nuget:proxy" "$depolar"
for d in nuget-hosted npm-hosted; do
  al nx GET "/v1/repositories/${d%%-*}/hosted/$d"
  esit "$d redeploy kapali" "ALLOW_ONCE" "$(jq -r '.storage.writePolicy' <<<"$HTTP_BODY")"
done
al nx GET /v1/security/realms/active
esit "etkin realm'ler" '["NexusAuthenticatingRealm","NpmToken","NuGetApiKey"]' "$(jq -c '.' <<<"$HTTP_BODY")"
al nx GET /v1/security/anonymous
esit "anonim okuma" "true" "$(jq -r '.enabled' <<<"$HTTP_BODY")"
esit "nuget-group anonim okunuyor" "200" "$(curl -sS -o /dev/null -w '%{http_code}' "$NEXUS_URL/repository/nuget-group/index.json")"
esit "nuget-group servis adresleri HTTPS" "https://nexus.${LAB_DOMAIN}/repository/nuget-group/v3/content/" \
  "$(curl -sS "$NEXUS_URL/repository/nuget-group/index.json" | jq -r '[.resources[] | select(."@type" | startswith("PackageBaseAddress"))][0]."@id"')"
esit "npm-group anonim okunuyor" "200" "$(curl -sS -o /dev/null -w '%{http_code}' "$NEXUS_URL/repository/npm-group/react")"
for nn in $(ekipler); do
  kullanici="ekip${nn}"
  cfg="$(_curl_cfg "nx-$kullanici" "user = \"${kullanici}:$(ekip_parola "nexus-${kullanici}")\"")"
  # Yonetici ucu: gecerli kimlikle 403 (yetki yok), gecersiz kimlikle 401 doner.
  _istek "$cfg" GET "${NEXUS_URL}/service/rest/v1/security/users" || true
  esit "Nexus $kullanici parolasiyla giris (yonetici ucunda 403 beklenir)" "403" "$HTTP_CODE"
done
al nx GET /v1/system/eula
bilgi "Community Edition EULA kabul durumu: $(jq -r '.accepted' <<<"$HTTP_BODY")"

ozet
