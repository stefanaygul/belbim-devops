#!/usr/bin/env bash
# Lab CA'sini ve servis sertifikasini uretir. araclar container'inda calisir.
# Var olan CA'ya dokunmaz; servis sertifikasi eksikse, alan adi degistiyse ya da
# 30 gun icinde bitecekse yeniden uretilir.
set -euo pipefail

D="${LAB_DOMAIN:?LAB_DOMAIN tanimli degil}"
cd /lab/ortam/certs

sahiplik() {
  if [ "${HOST_UID:-0}" != "0" ]; then
    chown "${HOST_UID}:${HOST_GID:-0}" "$@"
  fi
}

if [ ! -f ca.key ] || [ ! -f ca.crt ]; then
  echo "==> Lab CA'si uretiliyor ($D)"
  openssl genrsa -out ca.key 4096 2>/dev/null
  # nameConstraints: bu CA yalnizca lab alan adi icin sertifika imzalayabilir.
  # Host'un guven deposuna eklendiginde baska siteler icin kullanilamaz.
  openssl req -x509 -new -key ca.key -sha256 -days 3650 \
    -subj "/O=Egitim Ortami/CN=Egitim Lab Root CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "nameConstraints=critical,permitted;DNS:${D}" \
    -out ca.crt
  printf '%s\n' "$D" > ca.domain
  chmod 600 ca.key
  chmod 644 ca.crt ca.domain
  sahiplik ca.key ca.crt ca.domain
  rm -f server.crt server.key server.domain
fi

if [ "$(cat ca.domain 2>/dev/null)" != "$D" ]; then
  echo "HATA: certs/ altindaki CA '$(cat ca.domain 2>/dev/null)' alan adi icin uretilmis; LAB_DOMAIN simdi '$D'." >&2
  echo "      CA'yi yeniden uretmek icin certs/ca.* ve certs/server.* dosyalarini silin." >&2
  echo "      Yeni CA, onu guven deposuna eklemis her makineye yeniden dagitilmalidir." >&2
  exit 1
fi

yenile=0
if [ ! -f server.key ] || [ ! -f server.crt ]; then
  yenile=1
elif [ "$(cat server.domain 2>/dev/null)" != "$D" ]; then
  yenile=1
elif ! openssl verify -CAfile ca.crt server.crt >/dev/null 2>&1; then
  yenile=1
elif ! openssl x509 -in server.crt -noout -checkend 2592000 >/dev/null; then
  yenile=1
fi

if [ "$yenile" = "1" ]; then
  echo "==> Servis sertifikasi uretiliyor"
  openssl genrsa -out server.key 2048 2>/dev/null
  openssl req -new -key server.key -subj "/O=Egitim Ortami/CN=gitlab.${D}" -out server.csr
  cat > server.ext <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
subjectAltName=DNS:gitlab.${D},DNS:jenkins.${D},DNS:sonar.${D},DNS:nexus.${D}
EOF
  # 800 gun: macOS, kullanicinin ekledigi CA'larda 825 gunden uzun sertifikayi reddeder.
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -sha256 -days 800 -extfile server.ext -out server.crt 2>/dev/null
  rm -f server.csr server.ext
  printf '%s\n' "$D" > server.domain
  chmod 600 server.key
  chmod 644 server.crt server.domain
  sahiplik server.key server.crt server.domain ca.srl
fi

openssl verify -CAfile ca.crt server.crt
echo "CA parmak izi (SHA-256): $(openssl x509 -in ca.crt -noout -fingerprint -sha256 | cut -d= -f2)"
echo "Servis sertifikasi bitis: $(openssl x509 -in server.crt -noout -enddate | cut -d= -f2)"
