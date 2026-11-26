#!/usr/bin/env bash
# .env dosyasini .env.example'dan uretir ve bos sirlari doldurur. Host'ta calisir.
# Var olan degerlere dokunmaz; tekrar calistirmak guvenlidir.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo ".env olusturuldu"
fi
chmod 600 .env

uret() {
  head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-"$1"
}

# doldur ANAHTAR DEGER : anahtar bos ya da eksikse degeri yazar
doldur() {
  local anahtar="$1" deger="$2"
  if grep -q "^${anahtar}=..*" .env; then
    return 0
  fi
  if grep -q "^${anahtar}=" .env; then
    awk -v k="$anahtar" -v v="$deger" \
      'BEGIN { n = length(k) + 1 } substr($0, 1, n) == k "=" { print k "=" v; next } { print }' \
      .env > .env.tmp
    mv .env.tmp .env
    chmod 600 .env
  else
    printf '%s=%s\n' "$anahtar" "$deger" >> .env
  fi
  echo "  $anahtar uretildi"
}

# .env.example'a sonradan eklenen anahtarlar eski .env'de eksik olabilir.
while IFS='=' read -r anahtar deger; do
  case "$anahtar" in
    ''|'#'*) continue ;;
  esac
  grep -q "^${anahtar}=" .env || printf '%s=%s\n' "$anahtar" "$deger" >> .env
done < .env.example

doldur GITLAB_ROOT_PASSWORD "$(uret 24)"
doldur GITLAB_ADMIN_TOKEN "lab$(uret 30)"
doldur NEXUS_ADMIN_PASSWORD "$(uret 24)"
doldur LAB_SECRET "$(uret 40)"
doldur JENKINS_ADMIN_PASSWORD "$(uret 24)"
doldur SONAR_ADMIN_PASSWORD "Sq1-$(uret 24)"
doldur SONAR_DB_PASSWORD "$(uret 24)"

# lab.env: katilimci makinesinin okudugu, sir icermeyen ortam dosyasi.
# Her calistirmada lab.env.example'dan yeniden uretilir (sandbox degerleri .env'den gelir).
alan="$(sed -n 's/^LAB_DOMAIN=//p' .env | head -n 1)"
profil="$(sed -n 's/^SONAR_PROFILE=//p' .env | head -n 1)"
sed -e "s/kurum\.test/${alan}/g" \
    -e "s/^SONAR_PROFILE=.*/SONAR_PROFILE=${profil:-community}/" \
    lab.env.example > lab.env.tmp
if ! cmp -s lab.env.tmp lab.env 2>/dev/null; then
  mv lab.env.tmp lab.env
  echo "lab.env uretildi (${alan})"
else
  rm -f lab.env.tmp
fi
