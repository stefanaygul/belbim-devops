#!/usr/bin/env bash
# Nexus yonetici parolasini .env'deki degere getirir. araclar container'inda calisir.
# Ilk kurulum parolasi (nexus-data/admin.password) standart giristen okunur;
# dosya yoksa (parola daha once degistirilmis) standart giris bos gelir.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Ilk kurulum parolasi varsa once o kullanilir: basarisiz her giris denemesi
# Nexus'un giris hiz sinirlayicisini tetikler ("Too many authentication attempts").
ilk="$(cat | tr -d '\r\n')"

if [ -z "$ilk" ]; then
  zorunlu "Nexus yonetici girisi (.env parolasi)" nx GET /v1/status/check
  tamam "Nexus yonetici parolasi gecerli"
  exit 0
fi

ilk_cfg="$(_curl_cfg nx-ilk "user = \"admin:${ilk}\"")"
# printf: parolanin sonuna satir sonu eklenmemeli
_istek "$ilk_cfg" PUT "${NEXUS_URL}/service/rest/v1/security/users/admin/change-password" \
    -H "Content-Type: text/plain" --data-binary @- < <(printf '%s' "$NEXUS_ADMIN_PASSWORD") \
  || olum "Parola degistirilemedi: HTTP $HTTP_CODE"
zorunlu "yeni parolayla giris" nx GET /v1/status/check
tamam "Nexus yonetici parolasi ayarlandi"
