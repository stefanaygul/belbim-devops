#!/bin/bash
set -euo pipefail
cd /Users/stefanaygul/belbim-devops/lab-ortami
exec > ../kanit/faz-6/docker-giris-yalitimi.log 2>&1
docker compose run --rm -T araclar bash -s <<'API'
set -euo pipefail
source bootstrap/lib.sh
j='/job/ekip-99/job/saha-portal-ekip99/job/v1.1.0'
zorunlu job jk GET "$j/api/json"
no="$(jq -r .nextBuildNumber <<<"$HTTP_BODY")"
zorunlu build jk POST "$j/build"
sonuc=''
for i in $(seq 1 120); do
  if jk GET "$j/$no/api/json"; then
    sonuc="$(jq -r 'if .building then "" else .result end' <<<"$HTTP_BODY")"
    [ -z "$sonuc" ] || break
  fi
  sleep 2
done
[ "$sonuc" = SUCCESS ] || olum "Yeni tag build #$no: $sonuc"
zorunlu console jk GET "$j/$no/consoleText"
printf '%s\n' "$HTTP_BODY" > .cache/faz6-yalitim-tag.log
grep -q '@tmp/docker-config/config.json' <<<"$HTTP_BODY"
grep -q 'rm -f .*docker-config/config.json' <<<"$HTTP_BODY"
echo "GECTI: ekip02 tokenlari iptal edildikten sonra ekip99 v1.1.0 #$no SUCCESS; workspace Docker config ve temizlik konsolda"
API
docker compose exec -T jenkins-agent sh -s <<'AGENT'
set -eu
[ ! -f "$HOME/.docker/config.json" ] || [ "$(jq '(.auths // {}) | length' "$HOME/.docker/config.json")" = 0 ]
[ -z "$(find /home/jenkins/agent/workspace -path '*@tmp/docker-config/config.json' -type f -print)" ]
echo 'GECTI: ortak Docker girisi yok; tamamlanan joblarin Docker config dosyalari temiz'
AGENT
cp .cache/faz6-yalitim-tag.log ../kanit/faz-6/docker-giris-yalitimi-tag.log
bash dogrula/lab.sh lab-05-b 99 > ../kanit/faz-6/lab-05-b-son.log 2>&1
