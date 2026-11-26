#!/usr/bin/env bash
# TUM belbim-lab volume verisini siler. Yalnizca acik kullanici onayiyla.
# .env, CA dosyalari, kaynak kod ve host Docker imaj onbellegi korunur.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${TEMIZ_KURULUM_ONAYI:-}" = 'belbim-lab' ] || {
  echo 'Mevcut ekipler dahil TUM lab verileri silinir; acik onaydan sonra TEMIZ_KURULUM_ONAYI=belbim-lab verin.' >&2
  exit 2
}
[ "$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' .env)" = 'belbim-lab' ] || exit 2
[ "${COMPOSE_PROJECT_NAME:-belbim-lab}" = 'belbim-lab' ] || exit 2
grep -qx 'LAB_MODE=sandbox' lab.env || exit 2
kanit="${KANIT_DIZINI:-../kanit/faz-6/temiz-prova}"
mkdir -p "$kanit"
kanit="$(cd "$kanit" && pwd)"
export KANIT_DIZINI="$kanit"
docker compose --profile cekirdek --profile ci --profile araclar config --volumes > "$kanit/silinecek-volumelar.txt"
docker ps -a --filter label=com.docker.compose.project=belbim-lab --format '{{.Names}} {{.ID}}' > "$kanit/container-once.txt"
echo 'Temiz kurulum: belbim-lab container ve volumelari kaldiriliyor.'
docker compose --profile cekirdek --profile ci --profile araclar down --volumes --remove-orphans > "$kanit/yik.log" 2>&1
docker volume ls --filter label=com.docker.compose.project=belbim-lab --format '{{.Name}}' > "$kanit/volume-silme-sonrasi.txt"
[ ! -s "$kanit/volume-silme-sonrasi.txt" ] || { echo 'Lab volumeu kaldi; duruldu.' >&2; exit 1; }
echo 'Bos volumelarla servisler baslatiliyor.'
/usr/bin/make up-ci > "$kanit/up-ci.log" 2>&1
echo 'Bootstrap calisiyor.'
/usr/bin/make bootstrap > "$kanit/bootstrap.log" 2>&1
echo 'Cekirdek ve CI on kontrolleri calisiyor.'
/usr/bin/make dogrula > "$kanit/cekirdek.log" 2>&1
/usr/bin/make dogrula-ci > "$kanit/ci.log" 2>&1
echo 'On labin tam provasi basliyor.'
PROVA_VOLUME_SILME_ONAYI=ekip-99 PROVA_PAYLASILAN=0 bash dogrula/prova.sh
