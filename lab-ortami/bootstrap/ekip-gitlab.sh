#!/usr/bin/env bash
# Bir ekibin GitLab'deki kaynaklari: rol degisimi, sifirlama, checkpoint.
# araclar container'inda calisir; yalnizca API ve git kullanir.
# YALNIZCA verilen ekibe dokunur: egitim/ekip-NN grubu, altindaki projeler ve
# ekipNN-lead / ekipNN-dev hesaplari. Baska ekibe ve global ayarlara dokunmaz.
#
#   ekip-gitlab.sh rol <NN> goster|degistir|asil
#   ekip-gitlab.sh sifirla <NN>
#   ekip-gitlab.sh checkpoint <NN> <lab-02a|lab-02b|lab-03a|lab-03b|lab-04a|lab-04b>
#       ortam: DEV_ANAHTAR, LEAD_ANAHTAR (workstation'daki acik SSH anahtarlari)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mod="${1:?rol|sifirla|checkpoint}"
nn="${2:?ekip numarasi}"
[[ "$nn" =~ ^[0-9][0-9]$ ]] || olum "ekip numarasi iki haneli olmali: $nn"
GRUP_YOLU="$GITLAB_GROUP/ekip-$nn"
PROJE_YOLU="$GRUP_YOLU/saha-ekipman-portal"
LEAD="ekip${nn}-lead"
DEV="ekip${nn}-dev"

zorunlu "grup $GRUP_YOLU" gl GET "/groups/$(urlenc "$GRUP_YOLU")"
GRUP_ID="$(jq -r '.id' <<<"$HTTP_BODY")"
kullanici_id() {
  zorunlu "kullanici $1" gl GET "/users?username=$(urlenc "$1")"
  jq -r '.[0].id // empty' <<<"$HTTP_BODY"
}
LEAD_ID="$(kullanici_id "$LEAD")"
DEV_ID="$(kullanici_id "$DEV")"
[ -n "$LEAD_ID" ] && [ -n "$DEV_ID" ] || olum "ekip hesaplari yok: $LEAD, $DEV"

seviye() { gl GET "/groups/$GRUP_ID/members/$1" && jq -r '.access_level' <<<"$HTTP_BODY"; }
seviye_adi() { case "$1" in 40) echo Maintainer ;; 30) echo Developer ;; *) echo "$1" ;; esac; }
rol_ayarla() {  # rol_ayarla <lead-seviye> <dev-seviye>
  zorunlu "rol $LEAD" gl PUT "/groups/$GRUP_ID/members/$LEAD_ID" --data-urlencode "access_level=$1"
  zorunlu "rol $DEV" gl PUT "/groups/$GRUP_ID/members/$DEV_ID" --data-urlencode "access_level=$2"
}
rol_goster() {
  printf '    %s: %s   %s: %s   (%s)\n' "$LEAD" "$(seviye_adi "$(seviye "$LEAD_ID")")" "$DEV" "$(seviye_adi "$(seviye "$DEV_ID")")" "$GRUP_YOLU"
}

# Token komut satirina yazilmaz; git onu ortamdan okuyan bir credential helper'dan alir.
git_gl() {
  git -c credential.helper= \
      -c credential.helper='!f() { echo username=root; echo "password=${GITLAB_ADMIN_TOKEN}"; }; f' "$@"
}

# Sunucunun bilgi satirlarini gizler; basarisizsa ciktinin tamamini gosterir.
git_it() {
  local cikti
  if ! cikti="$(git_gl push --quiet "$@" 2>&1)"; then
    printf '%s\n' "$cikti" >&2
    olum "git push basarisiz"
  fi
}

proje_id() {  # yoksa bos
  if gl GET "/projects/$(urlenc "$PROJE_YOLU")"; then jq -r '.id' <<<"$HTTP_BODY"; fi
}

# ---------------------------------------------------------------------------
rol_modu() {
  case "${1:-goster}" in
    goster) ;;
    degistir)
      l="$(seviye "$LEAD_ID")"; d="$(seviye "$DEV_ID")"
      rol_ayarla "$d" "$l"
      ;;
    asil) rol_ayarla 40 30 ;;
    *) olum "kullanim: ekip-gitlab.sh rol <NN> goster|degistir|asil" ;;
  esac
  rol_goster
}

# ---------------------------------------------------------------------------
sifirla_modu() {
  adim "GitLab: ekip-$nn sifirlaniyor"
  # Grubun projeleri: etkin olanlar ve silinmek uzere isaretli olanlar
  local kimlikler="" k yol i
  for filtre in "" "&active=false"; do
    zorunlu "proje listesi" gl GET "/groups/$GRUP_ID/projects?per_page=100&include_subgroups=true${filtre}"
    kimlikler="$kimlikler $(jq -r '.[].id' <<<"$HTTP_BODY")"
  done
  for k in $(printf '%s\n' $kimlikler | sort -un); do
    zorunlu "proje $k" gl GET "/projects/$k"
    yol="$(jq -r '.path_with_namespace' <<<"$HTTP_BODY")"
    case "$yol" in "$GRUP_YOLU"/*) ;; *) olum "beklenmeyen proje yolu: $yol" ;; esac
    if [ "$(jq -r '.marked_for_deletion_on // empty' <<<"$HTTP_BODY")" = "" ]; then
      # GitLab, registry'sinde imaj etiketi bulunan projeyi silmez: once etiketler silinir.
      local depo etiket silinen=0
      zorunlu "registry depolari" gl GET "/projects/$k/registry/repositories?per_page=100"
      for depo in $(jq -r '.[].id' <<<"$HTTP_BODY"); do
        zorunlu "registry etiketleri" gl GET "/projects/$k/registry/repositories/$depo/tags?per_page=100"
        for etiket in $(jq -r '.[].name' <<<"$HTTP_BODY"); do
          zorunlu "etiket silme $etiket" gl DELETE "/projects/$k/registry/repositories/$depo/tags/$(urlenc "$etiket")"
          silinen=$((silinen + 1))
        done
      done
      [ "$silinen" -eq 0 ] || tamam "registry: $silinen imaj etiketi silindi"
      zorunlu "proje silme $yol" gl DELETE "/projects/$k"
      zorunlu "proje $k" gl GET "/projects/$k"
      yol="$(jq -r '.path_with_namespace' <<<"$HTTP_BODY")"
    fi
    # Silme varsayilan olarak ertelenir; ayni adla yeniden olusturabilmek icin kalici silinir.
    gl DELETE "/projects/$k?permanently_remove=true&full_path=$(urlenc "$yol")" \
      || [ "$HTTP_CODE" = "404" ] || olum "kalici silme $yol: HTTP $HTTP_CODE $(head -c 200 <<<"$HTTP_BODY")"
    for i in $(seq 1 90); do
      gl GET "/projects/$k" || { [ "$HTTP_CODE" = "404" ] && break; }
      sleep 2
    done
    [ "$HTTP_CODE" = "404" ] || olum "proje hala duruyor: $yol"
    tamam "proje silindi: $yol"
  done
  [ -n "${kimlikler// /}" ] || tamam "silinecek proje yok"

  local u t
  for u in "$LEAD_ID" "$DEV_ID"; do
    zorunlu "anahtar listesi" gl GET "/users/$u/keys?per_page=100"
    for t in $(jq -r '.[].id' <<<"$HTTP_BODY"); do zorunlu "anahtar silme" gl DELETE "/users/$u/keys/$t"; done
    zorunlu "token listesi" gl GET "/personal_access_tokens?user_id=$u&state=active&per_page=100"
    for t in $(jq -r '.[].id' <<<"$HTTP_BODY"); do zorunlu "token iptali" gl DELETE "/personal_access_tokens/$t"; done
  done
  tamam "ekip hesaplarinin SSH anahtarlari ve token'lari kaldirildi"
  rol_ayarla 40 30
  rol_goster
}

# ---------------------------------------------------------------------------
anahtar_kaydet() {  # anahtar_kaydet <kullanici-id> <baslik> <acik-anahtar>
  local govde
  [ -n "$3" ] || return 0
  govde="$(awk '{print $2}' <<<"$3")"
  zorunlu "anahtar listesi" gl GET "/users/$1/keys?per_page=100"
  if jq -e --arg g "$govde" 'any(.[]; (.key | split(" ")[1]) == $g)' <<<"$HTTP_BODY" >/dev/null; then
    return 0
  fi
  zorunlu "SSH anahtari ($2)" gl POST "/users/$1/keys" --data-urlencode "title=$2" --data-urlencode "key=$3"
}

issue_kur() {  # issue_kur <proje-id> <iid> <baslik> <etiket> <durum: opened|closed>
  local p="$1" iid="$2"
  if ! gl GET "/projects/$p/issues/$iid"; then
    zorunlu "issue #$iid" gl POST "/projects/$p/issues" \
      --data-urlencode "iid=$iid" --data-urlencode "title=$3" --data-urlencode "labels=$4" \
      --data-urlencode "description=Checkpoint ile olusturuldu."
  fi
  local simdiki; simdiki="$(jq -r '.state' <<<"$HTTP_BODY")"
  if [ "$simdiki" != "$5" ]; then
    local olay=close; [ "$5" = "opened" ] && olay=reopen
    zorunlu "issue #$iid durumu" gl PUT "/projects/$p/issues/$iid" --data-urlencode "state_event=$olay"
  fi
}

checkpoint_modu() {
  local lab="${1:?lab}" ana_ref gelistirme_ref ek_branch="" etiketli=0 imajli=0 ci=false
  case "$lab" in
    lab-02a) ana_ref=checkpoint/lab-02a-main; gelistirme_ref=checkpoint/lab-02a ;;
    lab-02b) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-02b; etiketli=1 ;;
    lab-03a) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-02b; etiketli=1
             ek_branch="checkpoint/lab-03a:refs/heads/feature/9-docker" ;;
    lab-03b) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-03b; etiketli=1; imajli=1 ;;
    lab-04a) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-04a; etiketli=1; imajli=1; ci=true ;;
    lab-04b) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-04b; etiketli=1; imajli=1; ci=true ;;
    lab-05a) ana_ref=checkpoint/lab-02b-main; gelistirme_ref=checkpoint/lab-05a; etiketli=1; imajli=1; ci=true ;;
    final)   ana_ref=checkpoint/final-main;   gelistirme_ref=checkpoint/final;   etiketli=1; imajli=1; ci=true ;;
    *) olum "GitLab durumu olan checkpoint'ler: lab-02a lab-02b lab-03a lab-03b lab-04a lab-04b lab-05a final (gelen: $lab)" ;;
  esac

  adim "GitLab: ekip-$nn icin checkpoint/$lab"
  rol_ayarla 40 30
  anahtar_kaydet "$LEAD_ID" "workstation (lead)" "${LEAD_ANAHTAR:-}"
  anahtar_kaydet "$DEV_ID" "workstation (dev)" "${DEV_ANAHTAR:-}"
  tamam "roller asil durumda; workstation SSH anahtarlari hesaplarda kayitli"

  # Proje (yoksa ekip lideri adina olusturulur)
  local p; p="$(proje_id)"
  if [ -z "$p" ]; then
    zorunlu "proje olusturma" gl POST /projects -H "Sudo: $LEAD" \
      --data-urlencode "name=saha-ekipman-portal" --data-urlencode "path=saha-ekipman-portal" \
      --data-urlencode "namespace_id=$GRUP_ID" --data-urlencode "visibility=private" \
      --data-urlencode "initialize_with_readme=false"
    p="$(jq -r '.id' <<<"$HTTP_BODY")"
    tamam "proje olusturuldu: $PROJE_YOLU"
  else
    tamam "proje var: $PROJE_YOLU"
  fi

  # Ekibe ozel repo (CODEOWNERS ekip numarasiyla); SHA'lar ekip basina sabittir.
  EKIP_KISISEL="$nn" bash "$(dirname "$0")/sablon-hazirla.sh" "/tmp/ekip-$nn" >/dev/null 2>/tmp/sablon-hazirla.log \
    || { cat /tmp/sablon-hazirla.log >&2; olum "ekip reposu hazirlanamadi"; }
  cd "/tmp/ekip-$nn"
  local uzak="${GITLAB_URL}/${PROJE_YOLU}.git"
  local ana gelistirme
  ana="$(git rev-parse "$ana_ref")"; gelistirme="$(git rev-parse "$gelistirme_ref")"

  # Koruma kaldirilir, branch'ler zorla yazilir, koruma yeniden kurulur (yalnizca bu proje).
  local b
  koruma_kaldir() {
    for b in main develop; do
      gl DELETE "/projects/$p/protected_branches/$b" || [ "$HTTP_CODE" = "404" ] || olum "koruma kaldirilamadi: $b"
    done
    gl DELETE "/projects/$p/protected_tags/$(urlenc 'v*')" || [ "$HTTP_CODE" = "404" ] || olum "tag korumasi kaldirilamadi"
  }
  koruma_kaldir
  local refler=("+${ana}:refs/heads/main" "+${gelistirme}:refs/heads/develop")
  [ -z "$ek_branch" ] || refler+=("+${ek_branch}")
  git_it "$uzak" "${refler[@]}"
  koruma_kaldir   # GitLab, bos projeye ilk push'ta varsayilan branch'i kendiliginden korur
  # Bu checkpoint'te artik bulunmamasi gereken branch ve tag'ler
  local silinecek=() uzaktaki
  uzaktaki="$(git_gl ls-remote --heads --tags "$uzak" | awk '{print $2}')"
  for b in feature/3-stok-durumu feature/3-stok-durumu-arayuz release/1.0.0 hotfix/1.0.1 \
           feature/pipeline feature/sonar feature/siparis-ozeti feature/siparis-ozeti-testleri \
           feature/ortak-paket feature/deploy feature/12-miktar-dogrulama release/1.1.0; do
    grep -qx "refs/heads/$b" <<<"$uzaktaki" && silinecek+=(":refs/heads/$b")
  done
  if [ -z "$ek_branch" ] && grep -qx "refs/heads/feature/9-docker" <<<"$uzaktaki"; then
    silinecek+=(":refs/heads/feature/9-docker")
  fi
  # Bu checkpoint'te olmayan tag'ler silinir (v1.0.0 ve v1.0.1 asagida yeniden yazilir).
  for b in $(grep '^refs/tags/' <<<"$uzaktaki" | grep -v '\^{}$' | sed 's#^refs/tags/##'); do
    silinecek+=(":refs/tags/$b")
  done
  [ "${#silinecek[@]}" -eq 0 ] || git_it "$uzak" "${silinecek[@]}"
  local etiketler=""
  if [ "$etiketli" -eq 1 ]; then
    # v1.0.1 = LAB 02-B sonundaki main, v1.0.0 onun ilk ebeveyni; v1.1.0 = LAB 05-B sonundaki main
    local v101; v101="$(git rev-parse checkpoint/lab-02b-main)"
    GIT_COMMITTER_NAME="Egitim Ortami" GIT_COMMITTER_EMAIL="egitim@${LAB_DOMAIN}" GIT_COMMITTER_DATE="2026-11-03T14:25:00+03:00" \
      git tag -a -f v1.0.0 -m "release: v1.0.0" "${v101}~1" >/dev/null
    GIT_COMMITTER_NAME="Egitim Ortami" GIT_COMMITTER_EMAIL="egitim@${LAB_DOMAIN}" GIT_COMMITTER_DATE="2026-11-03T15:35:00+03:00" \
      git tag -a -f v1.0.1 -m "release: v1.0.1" "$v101" >/dev/null
    [ "$(git log -1 --format=%s "${v101}~1")" = "Merge branch 'release/1.0.0' into 'main'" ] || olum "v1.0.0 icin beklenen commit bulunamadi"
    etiketler="refs/tags/v1.0.0 refs/tags/v1.0.1"
    if [ "$lab" = "final" ]; then
      [ "$(git log -1 --format=%s "$ana")" = "Merge branch 'release/1.1.0' into 'main'" ] || olum "v1.1.0 icin beklenen commit bulunamadi"
      GIT_COMMITTER_NAME="Egitim Ortami" GIT_COMMITTER_EMAIL="egitim@${LAB_DOMAIN}" GIT_COMMITTER_DATE="2026-11-06T15:15:00+03:00" \
        git tag -a -f v1.1.0 -m "release: v1.1.0" "$ana" >/dev/null
      etiketler="$etiketler refs/tags/v1.1.0"
    fi
    # shellcheck disable=SC2086
    git_it "$uzak" $etiketler
  fi
  tamam "main@${ana:0:7} develop@${gelistirme:0:7}${ek_branch:+ feature/9-docker}$(printf '%s' "$etiketler" | sed 's#refs/tags/# #g')"

  zorunlu "proje ayarlari" gl PUT "/projects/$p" \
    --data-urlencode "default_branch=develop" --data-urlencode "merge_method=merge" \
    --data-urlencode "squash_option=default_off" \
    --data-urlencode "only_allow_merge_if_all_discussions_are_resolved=true" \
    --data-urlencode "only_allow_merge_if_pipeline_succeeds=$ci" \
    --data-urlencode "remove_source_branch_after_merge=true"
  # GitLab bos projeye ilk push'tan sonra varsayilan branch'i arka planda kendiliginden korur;
  # bu, yukaridaki kaldirmadan sonra da gerceklesebilir. Koruma varsa silinip yeniden kurulur.
  local deneme
  for b in main develop; do
    for deneme in 1 2 3; do
      gl DELETE "/projects/$p/protected_branches/$b" || [ "$HTTP_CODE" = "404" ] || olum "koruma kaldirilamadi: $b"
      gl POST "/projects/$p/protected_branches" \
        --data-urlencode "name=$b" --data-urlencode "push_access_level=0" \
        --data-urlencode "merge_access_level=40" --data-urlencode "allow_force_push=false" && break
      [ "$HTTP_CODE" = "409" ] || olum "koruma $b basarisiz (HTTP $HTTP_CODE): $(head -c 300 <<<"$HTTP_BODY")"
      sleep 2
    done
    zorunlu "koruma $b" gl GET "/projects/$p/protected_branches/$b"
    [ "$(jq -r '.push_access_levels[0].access_level' <<<"$HTTP_BODY")" = "0" ] || olum "koruma $b beklenen duzeyde degil"
  done
  if [ "$etiketli" -eq 1 ]; then
    zorunlu "tag korumasi" gl POST "/projects/$p/protected_tags" \
      --data-urlencode "name=v*" --data-urlencode "create_access_level=40"
  fi
  tamam "varsayilan branch develop; main ve develop korumali (push: No one, merge: Maintainers)$([ "$etiketli" -eq 1 ] && echo '; v* tag korumali')"

  issue_kur "$p" 1 "Katalogda stok durumu" "feature" closed
  case "$lab" in lab-02a) ;; *) issue_kur "$p" 2 "Boş ekipman koduyla talep açılabiliyor" "bug" closed ;; esac
  case "$lab" in
    lab-02a|lab-02b) ;;
    lab-03a) issue_kur "$p" 3 "Servisler için Docker imajları" "feature" opened ;;
    *) issue_kur "$p" 3 "Servisler için Docker imajları" "feature" closed ;;
  esac
  case "$lab" in lab-04a|lab-04b|lab-05a|final) issue_kur "$p" 4 "Her push'ta build ve test: Jenkins pipeline" "feature" closed ;; esac
  case "$lab" in lab-04b|lab-05a|final) issue_kur "$p" 5 "SonarQube analizi ve Quality Gate" "feature" closed ;; esac
  case "$lab" in lab-05a|final) issue_kur "$p" 6 "Ortak sözleşmeler Nexus'ta NuGet paketi olarak" "feature" closed ;; esac
  case "$lab" in final) issue_kur "$p" 7 "Miktarı 1'den küçük talep açılabiliyor" "bug" closed ;; esac
  tamam "issue kayitlari hazir (MR gecmisi checkpoint ile geri kurulmaz)"

  if [ "$ci" = "true" ]; then
    tamam "\"Pipelines must succeed\" acik (Jenkins baglantisi ekip-ci.sh ile kurulur)"
  else
    # Bu checkpoint'te Jenkins baglantisi yok: webhook, Jenkins token'lari kaldirilir.
    local k
    zorunlu "webhook listesi" gl GET "/projects/$p/hooks?per_page=100"
    for k in $(jq -r --arg u "$JENKINS_URL/" '.[] | select(.url | startswith($u)) | .id' <<<"$HTTP_BODY"); do
      zorunlu "webhook silme" gl DELETE "/projects/$p/hooks/$k"
    done
    zorunlu "access token listesi" gl GET "/projects/$p/access_tokens?per_page=100"
    for k in $(jq -r '.[] | select(.name == "jenkins" and .revoked == false) | .id' <<<"$HTTP_BODY"); do
      zorunlu "access token iptali" gl DELETE "/projects/$p/access_tokens/$k"
    done
    zorunlu "deploy token listesi" gl GET "/projects/$p/deploy_tokens?per_page=100"
    for k in $(jq -r --arg a "ekip${nn}-jenkins" '.[] | select(.username == $a) | .id' <<<"$HTTP_BODY"); do
      zorunlu "deploy token silme" gl DELETE "/projects/$p/deploy_tokens/$k"
    done
    tamam "Jenkins baglantisi yok: webhook, 'jenkins' access token'i ve deploy token'i kaldirildi; \"Pipelines must succeed\" kapali"
  fi

  if [ "$imajli" -eq 1 ]; then
    # Deploy token'lar: push icin read+write, test VM icin yalnizca read.
    zorunlu "deploy token listesi" gl GET "/projects/$p/deploy_tokens?per_page=100"
    local t
    for t in $(jq -r --arg a "ekip${nn}-deploy" --arg b "ekip${nn}-pull" '.[] | select(.username == $a or .username == $b) | .id' <<<"$HTTP_BODY"); do
      zorunlu "eski deploy token" gl DELETE "/projects/$p/deploy_tokens/$t"
    done
    local cikti="/lab/ortam/.cache/checkpoint/ekip${nn}.env"
    mkdir -p "$(dirname "$cikti")"
    ( umask 077; : > "$cikti" )
    zorunlu "deploy token (push)" gl POST "/projects/$p/deploy_tokens" \
      --data-urlencode "name=ekip${nn}-deploy" --data-urlencode "username=ekip${nn}-deploy" \
      --data-urlencode "scopes[]=read_registry" --data-urlencode "scopes[]=write_registry"
    printf 'DEPLOY_TOKEN=%s\n' "$(jq -r '.token' <<<"$HTTP_BODY")" >> "$cikti"
    zorunlu "deploy token (pull)" gl POST "/projects/$p/deploy_tokens" \
      --data-urlencode "name=ekip${nn}-pull" --data-urlencode "username=ekip${nn}-pull" \
      --data-urlencode "scopes[]=read_registry"
    printf 'PULL_TOKEN=%s\n' "$(jq -r '.token' <<<"$HTTP_BODY")" >> "$cikti"
    chown "${HOST_UID:-0}:${HOST_GID:-0}" "$cikti"
    tamam "deploy token'lar: ekip${nn}-deploy (read+write), ekip${nn}-pull (read)"
  fi
}

case "$mod" in
  rol) rol_modu "${3:-goster}" ;;
  sifirla) sifirla_modu ;;
  checkpoint) checkpoint_modu "${3:-}" ;;
  *) olum "kullanim: ekip-gitlab.sh rol|sifirla|checkpoint <NN> ..." ;;
esac
