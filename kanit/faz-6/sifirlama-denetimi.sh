#!/bin/bash
set -euo pipefail
cd /Users/stefanaygul/belbim-devops/lab-ortami
exec > ../kanit/faz-6/sifirla-ekip02-dogrula.log 2>&1
docker compose run --rm -T araclar bash -s <<'API'
set -euo pipefail
source bootstrap/lib.sh
if gl GET /projects/egitim%2Fekip-02%2Fsaha-ekipman-portal; then olum 'Proje halen var'; fi
[ "$HTTP_CODE" = 404 ]; echo 'GECTI GitLab ekip02 projesi yok'
zorunlu paket nx GET '/v1/search?repository=nuget-hosted&name=Saha.Common.Contracts.Ekip02'
jq -e '.items|length==0' <<<"$HTTP_BODY" >/dev/null; echo 'GECTI Nexus ekip02 paketleri yok'
zorunlu jobs jk GET '/job/ekip-02/api/json?tree=jobs%5Bname%5D'
jq -e '.jobs|length==0' <<<"$HTTP_BODY" >/dev/null; echo 'GECTI Jenkins ekip02 job yok'
zorunlu credentials jk GET '/job/ekip-02/credentials/store/folder/domain/_/api/json?tree=credentials%5Bid%5D'
jq -e '.credentials|length==0' <<<"$HTTP_BODY" >/dev/null; echo 'GECTI Jenkins ekip02 credential yok'
cfg="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
_istek "$cfg" GET "$SONAR_URL/api/projects/search?projects=saha-portal-ekip02"
jq -e '.components|length==0' <<<"$HTTP_BODY" >/dev/null; echo 'GECTI SonarQube ekip02 projesi yok'
_istek "$cfg" GET "$SONAR_URL/api/user_tokens/search?login=ekip02"
jq -e '.userTokens|length==0' <<<"$HTTP_BODY" >/dev/null; echo 'GECTI SonarQube ekip02 token yok'
API
docker compose exec -T -u deploy test-vm bash -s <<'VM'
set -euo pipefail
[ -z "$(ls -A /opt/saha/ekip02)" ]
[ -z "$(docker ps -aq --filter label=com.docker.compose.project=ekip02)" ]
[ -z "$(docker volume ls -q --filter label=com.docker.compose.project=ekip02)" ]
! grep -q 'jenkins-ekip02$' ~/.ssh/authorized_keys
echo 'GECTI test VM ekip02 dizini/container/volume/Jenkins SSH anahtari temiz'
VM
docker compose exec -T -u ekip02 workstation bash -l -s <<'WS'
set -euo pipefail
[ ! -e "$HOME/saha-ekipman-portal" ]
[ ! -e "$HOME/.docker/config.json" ]
[ -z "$(docker ps -aq --filter label=com.docker.compose.project=ekip02)" ]
[ -z "$(docker volume ls -q --filter label=com.docker.compose.project=ekip02)" ]
echo 'GECTI workstation ekip02 repo/registry girisi/container/volume temiz'
WS
echo '8/8 sifirlama denetimi GECTI'
