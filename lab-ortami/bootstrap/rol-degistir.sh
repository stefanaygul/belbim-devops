#!/usr/bin/env bash
# Bir ekipte Maintainer ve Developer rollerini yer degistirir (LAB 02-A'da eslerin
# rol degisimi icin). Host'ta calisir. Yalnizca egitim/ekip-NN grubundaki iki uyeligi degistirir.
#   rol-degistir.sh <NN>          rolleri yer degistirir
#   rol-degistir.sh <NN> asil     ekipNN-lead Maintainer, ekipNN-dev Developer
#   rol-degistir.sh <NN> goster
set -euo pipefail
cd "$(dirname "$0")/.."
nn="$(printf '%02d' "$((10#${1:?kullanim: rol-degistir.sh <NN> [asil|goster]}))")"
docker compose run --rm -T araclar bash bootstrap/ekip-gitlab.sh rol "$nn" "${2:-degistir}" < /dev/null
