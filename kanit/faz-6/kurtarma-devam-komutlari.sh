#!/bin/bash
set -euo pipefail
cd /Users/stefanaygul/belbim-devops/lab-ortami
docker compose exec -T -u ekip02 workstation bash -l -s > ../kanit/faz-6/sifirla-ekip02-yerel-oncesi.log 2>&1 <<'WS'
set -euo pipefail
cd "$HOME"
eski_kod=0
docker compose -p ekip02 down --volumes --remove-orphans > /tmp/ekip02-eski-reset.log 2>&1 || eski_kod=$?
cat /tmp/ekip02-eski-reset.log
[ -n "$(docker ps -q --filter label=com.docker.compose.project=ekip02)" ]
[ -n "$(docker volume ls -q --filter label=com.docker.compose.project=ekip02)" ]
echo "GECTI eski komuttan sonra etiketi olan yerel container ve volume halen mevcut (cikis=$eski_kod)"
WS
EVET=1 bash bootstrap/sifirla-ekip.sh 02 > ../kanit/faz-6/sifirla-ekip02.log 2>&1
bash dogrula/ekip-durumu.sh 99 > ../kanit/faz-6/ekip99-kurtarma-sonrasi.txt 2>&1
/usr/bin/diff -u ../kanit/faz-6/ekip99-kurtarma-oncesi.txt ../kanit/faz-6/ekip99-kurtarma-sonrasi.txt > ../kanit/faz-6/ekip99-yalitim.diff
bash dogrula/ekip-durumu.sh 02 > ../kanit/faz-6/ekip02-sifirlama-sonrasi.txt 2>&1
/usr/bin/make dogrula > ../kanit/faz-6/cekirdek-son.log 2>&1
/usr/bin/make dogrula-ci > ../kanit/faz-6/ci-son.log 2>&1
/usr/bin/make onkontrol EKIP=01 > ../kanit/faz-6/katilimci01-onkontrol.log 2>&1
/usr/bin/make onkontrol EKIP=02 > ../kanit/faz-6/katilimci02-onkontrol.log 2>&1
