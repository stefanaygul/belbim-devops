#!/usr/bin/env bash
# GitLab: ayarlar, gruplar, kullanicilar, sablon proje, temel imaj projesi.
# araclar container'inda calisir; yalnizca API kullanir; tekrar calistirmak guvenlidir.
#
# Katilimciya birakilanlar burada YAPILMAZ: ekip projesi, branch korumasi,
# access token, deploy token, webhook.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# --- Ayarlar --------------------------------------------------------------
adim "GitLab ayarlari"
zorunlu "GitLab surumu" gl GET /version
bilgi "surum: $(jq -r '.version' <<<"$HTTP_BODY")"

# Yerel aga giden istekler kapali; izin listesinde yalnizca Jenkins adresi var.
zorunlu "ayarlar" gl PUT /application/settings \
  --data-urlencode "signup_enabled=false" \
  --data-urlencode "allow_local_requests_from_web_hooks_and_services=false" \
  --data-urlencode "allow_local_requests_from_system_hooks=false" \
  --data-urlencode "outbound_local_requests_whitelist[]=jenkins.${LAB_DOMAIN}" \
  --data-urlencode "auto_devops_enabled=false" \
  --data-urlencode "version_check_enabled=false" \
  --data-urlencode "gravatar_enabled=false" \
  --data-urlencode "default_branch_name=main"
izin="$(jq -c '.outbound_local_requests_whitelist' <<<"$HTTP_BODY")"
[ "$izin" = "[\"jenkins.${LAB_DOMAIN}\"]" ] || olum "giden istek izin listesi beklenen degil: $izin"
tamam "giden istek izin listesi: $izin"

# --- Gruplar --------------------------------------------------------------
# grup_kur <tam-yol> <ad> <gorunurluk> [ust-grup-id]  -> GRUP_ID
GRUP_ID=""
grup_kur() {
  local yol="$1" ad="$2" gorunurluk="$3" ust="${4:-}"
  if gl GET "/groups/$(urlenc "$yol")"; then
    GRUP_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
    if [ "$(jq -r '.visibility' <<<"$HTTP_BODY")" != "$gorunurluk" ]; then
      zorunlu "grup gorunurlugu $yol" gl PUT "/groups/$GRUP_ID" --data-urlencode "visibility=$gorunurluk"
    fi
    tamam "grup $yol (var)"
    return 0
  fi
  [ "$HTTP_CODE" = "404" ] || olum "grup sorgusu $yol: HTTP $HTTP_CODE"
  local veri=(--data-urlencode "name=$ad" --data-urlencode "path=${yol##*/}" --data-urlencode "visibility=$gorunurluk")
  [ -n "$ust" ] && veri+=(--data-urlencode "parent_id=$ust")
  zorunlu "grup olusturma $yol" gl POST /groups "${veri[@]}"
  GRUP_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
  tamam "grup $yol (olusturuldu)"
}

adim "Gruplar"
grup_kur "$GITLAB_GROUP" "Egitim" public
KOK_ID="$GRUP_ID"
grup_kur "$GITLAB_GROUP/sablonlar" "sablonlar" public "$KOK_ID"
SABLON_GRUP_ID="$GRUP_ID"

# --- Kullanicilar ve ekip alt gruplari --------------------------------------
# kullanici_kur <kullanici-adi> <ad> -> KULLANICI_ID
KULLANICI_ID=""
kullanici_kur() {
  local kullanici="$1" ad="$2"
  zorunlu "kullanici sorgusu" gl GET "/users?username=$(urlenc "$kullanici")"
  KULLANICI_ID="$(jq -r '.[0].id // empty' <<<"$HTTP_BODY")"
  if [ -n "$KULLANICI_ID" ]; then
    tamam "kullanici $kullanici (var)"
    return 0
  fi
  # Parola govdede gider; komut satirina yazilmaz.
  local govde
  govde="$(jq -n --arg u "$kullanici" --arg n "$ad" --arg e "${kullanici}@${LAB_DOMAIN}" \
              --arg p "$(ekip_parola "$kullanici")" \
              '{username:$u, name:$n, email:$e, password:$p, skip_confirmation:true}')"
  zorunlu "kullanici olusturma $kullanici" gl POST /users \
    -H "Content-Type: application/json" --data-binary @- <<<"$govde"
  KULLANICI_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
  tamam "kullanici $kullanici (olusturuldu)"
}

# uye_kur <grup-id> <kullanici-id> <seviye>   (30 Developer, 40 Maintainer)
uye_kur() {
  local grup="$1" kullanici="$2" seviye="$3"
  if gl GET "/groups/$grup/members/$kullanici"; then
    if [ "$(jq -r '.access_level' <<<"$HTTP_BODY")" != "$seviye" ]; then
      zorunlu "uyelik guncelleme" gl PUT "/groups/$grup/members/$kullanici" --data-urlencode "access_level=$seviye"
    fi
    return 0
  fi
  zorunlu "uyelik" gl POST "/groups/$grup/members" \
    --data-urlencode "user_id=$kullanici" --data-urlencode "access_level=$seviye"
}

adim "Ekipler"
for nn in $(ekipler); do
  grup_kur "$GITLAB_GROUP/ekip-$nn" "ekip-$nn" private "$KOK_ID"
  ekip_grup="$GRUP_ID"
  kullanici_kur "ekip${nn}-lead" "Ekip $nn Lead"
  uye_kur "$ekip_grup" "$KULLANICI_ID" 40
  kullanici_kur "ekip${nn}-dev" "Ekip $nn Dev"
  uye_kur "$ekip_grup" "$KULLANICI_ID" 30
done

# --- Projeler ---------------------------------------------------------------
# proje_kur <tam-yol> <namespace-id> <aciklama> -> PROJE_ID
PROJE_ID=""
proje_kur() {
  local yol="$1" ns="$2" aciklama="$3"
  if gl GET "/projects/$(urlenc "$yol")"; then
    PROJE_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
    tamam "proje $yol (var)"
    return 0
  fi
  [ "$HTTP_CODE" = "404" ] || olum "proje sorgusu $yol: HTTP $HTTP_CODE"
  zorunlu "proje olusturma $yol" gl POST /projects \
    --data-urlencode "name=${yol##*/}" --data-urlencode "path=${yol##*/}" \
    --data-urlencode "namespace_id=$ns" --data-urlencode "visibility=public" \
    --data-urlencode "description=$aciklama" \
    --data-urlencode "initialize_with_readme=false"
  PROJE_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
  tamam "proje $yol (olusturuldu)"
}

adim "Temel imaj projesi"
proje_kur "$GITLAB_GROUP/base" "$KOK_ID" "Ic ayna: temel container imajlari"

adim "Sablon proje"
proje_kur "$GITLAB_GROUP/sablonlar/portal-starter" "$SABLON_GRUP_ID" "Saha Ekipman Talep Portali - starter"
SABLON_ID="$PROJE_ID"

# Starter repoyu hazirla: Nexus adresi bu ortamin adresiyle yazilir.
bash "$(dirname "$0")/sablon-hazirla.sh" /tmp/sablon
cd /tmp/sablon

uzak="${GITLAB_URL}/${GITLAB_GROUP}/sablonlar/portal-starter.git"
# Token komut satirina yazilmaz; git onu ortamdan okuyan bir credential helper'dan alir.
git_gl() {
  git -c credential.helper= \
      -c credential.helper='!f() { echo username=root; echo "password=${GITLAB_ADMIN_TOKEN}"; }; f' "$@"
}

yerel="$(git for-each-ref --format='%(objectname) %(refname)' refs/heads | sort)"
uzaktaki="$(git_gl ls-remote --heads "$uzak" | awk '{print $1" "$2}' | sort)"
if [ "$yerel" = "$uzaktaki" ]; then
  tamam "sablon branch'leri guncel"
else
  # main korumali oldugu icin gecmisi degisen bir sablon dogrudan itilemez:
  # koruma kaldirilir, itilir, yeniden kurulur. Yalnizca sablon projeye dokunur.
  gl DELETE "/projects/$SABLON_ID/protected_branches/main" || [ "$HTTP_CODE" = "404" ] \
    || olum "main korumasi kaldirilamadi: HTTP $HTTP_CODE"
  git_gl push --quiet --force --prune "$uzak" 'refs/heads/*:refs/heads/*'
  tamam "sablon branch'leri itildi: $(git for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ')"
fi
zorunlu "varsayilan branch" gl PUT "/projects/$SABLON_ID" --data-urlencode "default_branch=main"
if ! gl GET "/projects/$SABLON_ID/protected_branches/main"; then
  zorunlu "main korumasi" gl POST "/projects/$SABLON_ID/protected_branches" \
    --data-urlencode "name=main" --data-urlencode "push_access_level=40" --data-urlencode "merge_access_level=40"
fi
tamam "sablon proje: main korumali"
