#!/usr/bin/env bash
# Bir ekibin butun kaynaklarinin ozetini yazar (GitLab, registry, test VM, workstation).
# Host'ta calisir; hicbir seyi degistirmez. Iki ciktinin `diff`i, arada o ekibe dokunulup
# dokunulmadigini gosterir (sifirla-ekip ve checkpoint-uygula yalitim testleri icin).
# Kullanim: dogrula/ekip-durumu.sh <NN>
set -uo pipefail
cd "$(dirname "$0")/.."
nn="$(printf '%02d' "$((10#${1:?kullanim: ekip-durumu.sh <NN>}))")"

echo "== GitLab (ekip-$nn)"
docker compose run --rm -T araclar bash -c '
source bootstrap/lib.sh
nn="$1"; grup="$GITLAB_GROUP/ekip-$nn"; p="/projects/$(urlenc "$grup/saha-ekipman-portal")"
gl GET "/groups/$(urlenc "$grup")/members?per_page=100" && jq -r ".[] | \"uye \(.username) \(.access_level)\"" <<<"$HTTP_BODY" | sort
for u in "ekip${nn}-lead" "ekip${nn}-dev"; do
  gl GET "/users?username=$u"; id="$(jq -r ".[0].id" <<<"$HTTP_BODY")"
  gl GET "/users/$id/keys" && echo "ssh-anahtari $u $(jq -r "[.[].key] | sort | join(\",\")" <<<"$HTTP_BODY" | sha256sum | cut -c1-12) ($(jq length <<<"$HTTP_BODY"))"
done
if gl GET "$p"; then
  echo "proje id=$(jq -r .id <<<"$HTTP_BODY") default=$(jq -r .default_branch <<<"$HTTP_BODY") olusturma=$(jq -r .created_at <<<"$HTTP_BODY")"
  gl GET "$p/repository/branches?per_page=100" && jq -r ".[] | \"branch \(.name) \(.commit.id) korumali=\(.protected)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/repository/tags?per_page=100" && jq -r ".[] | \"tag \(.name) \(.target)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/protected_branches" && jq -r ".[] | \"koruma \(.name) push=\([.push_access_levels[].access_level]|tostring) merge=\([.merge_access_levels[].access_level]|tostring)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/protected_tags" && jq -r ".[] | \"tag-koruma \(.name) \([.create_access_levels[].access_level]|tostring)\"" <<<"$HTTP_BODY"
  gl GET "$p/issues?per_page=100&scope=all" && jq -r ".[] | \"issue #\(.iid) \(.state) \(.updated_at)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/merge_requests?per_page=100&scope=all&state=all" && jq -r ".[] | \"mr !\(.iid) \(.state) \(.updated_at)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/deploy_tokens" && jq -r ".[] | \"deploy-token \(.username) \(.scopes|join(\",\")) id=\(.id)\"" <<<"$HTTP_BODY" | sort
  gl GET "$p/registry/repositories?tags=true&per_page=100" && for r in $(jq -r ".[].id" <<<"$HTTP_BODY"); do
    gl GET "$p/registry/repositories/$r/tags?per_page=100"
    for t in $(jq -r ".[].name" <<<"$HTTP_BODY" | sort); do
      gl GET "$p/registry/repositories/$r/tags/$t" && echo "imaj $(jq -r "\"\(.path) \(.digest)\"" <<<"$HTTP_BODY")"
    done
  done
else
  echo "proje yok"
fi
' _ "$nn" < /dev/null 2>&1

echo "== test VM (/opt/saha/ekip$nn)"
docker compose exec -T -u deploy test-vm bash -c '
nn="$1"
ls -la --time-style=+%s "/opt/saha/ekip$nn" | awk "NR>1 {print \$1, \$5, \$6, \$7}"
docker ps -a --filter "label=com.docker.compose.project=ekip$nn" --format "container {{.Names}} {{.ID}} {{.Image}} {{.State}}" | sort
docker volume ls -q --filter "label=com.docker.compose.project=ekip$nn" | sed "s/^/volume /"
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "/ekip-$nn/" | sort | sed "s/^/imaj /"
[ -f "/opt/saha/ekip$nn/.env" ] && { port="$(sed -n "s/^WEB_PORT=//p" "/opt/saha/ekip$nn/.env")"; echo "talepler $(curl -s --max-time 5 "http://localhost:$port/api/orders" | sha256sum | cut -c1-12)"; }
true' _ "$nn" < /dev/null 2>&1

echo "== workstation (ekip$nn)"
docker compose exec -T -u "ekip$nn" workstation bash -lc '
cd "$HOME"
ls -a | grep -v -E "^\.\.?$|^\.(bash|cache|dotnet|local|npm|nuget|templateengine|config|aspnet)" | sed "s/^/ev /"
if [ -d saha-ekipman-portal/.git ]; then
  cd saha-ekipman-portal
  echo "repo HEAD $(git rev-parse HEAD) $(git rev-parse --abbrev-ref HEAD)"
  git for-each-ref --format="ref %(refname) %(objectname)" refs/heads refs/tags | sort
  echo "calisma-agaci $(git status --porcelain | sha256sum | cut -c1-12)"
fi
[ -f "$HOME/.docker/config.json" ] && echo "docker-giris $(sha256sum < "$HOME/.docker/config.json" | cut -c1-12)"
[ -f "$HOME/.gitconfig" ] && echo "gitconfig $(sha256sum < "$HOME/.gitconfig" | cut -c1-12)"
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "^$IMG/" | sort | sed "s/^/imaj /"
docker ps -a --filter "label=com.docker.compose.project=ekip$EKIP" --format "container {{.Names}} {{.ID}} {{.State}}" | sort
true' < /dev/null 2>&1

echo "== Nexus (ekip-$nn)"
docker compose run --rm -T araclar bash -c 'source bootstrap/lib.sh; nx GET "/v1/search?repository=nuget-hosted&name=Saha.Common.Contracts.Ekip$1" >/dev/null && jq -r ".items[] | \"nexus-paket \(.name) \(.version) \(.assets[0].checksum.sha1 // \"-\")\"" <<<"$HTTP_BODY"' _ "$nn" < /dev/null 2>&1 | grep -v Container
echo "== test VM deploy kaydi (ekip-$nn)"
docker compose exec -T -u deploy test-vm sh -c "cat /opt/saha/ekip$nn/deploy-kayit.log 2>/dev/null | sed 's/^/deploy-kaydi /'; grep -c 'jenkins-ekip$nn\$' ~/.ssh/authorized_keys | sed 's/^/jenkins-anahtari /'" < /dev/null

echo "== CI (ekip-$nn): GitLab baglantisi, Jenkins, SonarQube"
if docker compose ps --status running --services 2>/dev/null | grep -qx jenkins; then
docker compose run --rm -T araclar bash -c '
source bootstrap/lib.sh
nn="$1"; p="/projects/$(urlenc "$GITLAB_GROUP/ekip-$nn/saha-ekipman-portal")"
if gl GET "$p"; then
  echo "pipelines-must-succeed $(jq -r .only_allow_merge_if_pipeline_succeeds <<<"$HTTP_BODY")"
  gl GET "$p/hooks?per_page=100" && jq -r ".[] | \"webhook \(.id) \(.url) push=\(.push_events) mr=\(.merge_requests_events)\"" <<<"$HTTP_BODY"
  gl GET "$p/access_tokens?per_page=100" && jq -r ".[] | select(.revoked == false) | \"access-token \(.id) \(.name) \(.scopes | join(\",\"))\"" <<<"$HTTP_BODY"
fi
jk GET "/job/ekip-$nn/credentials/store/folder/domain/_/api/json?tree=credentials%5Bid,typeName%5D" && jq -r ".credentials[] | \"jenkins-credential \(.id) (\(.typeName))\"" <<<"$HTTP_BODY" | sort
jk GET "/job/ekip-$nn/api/json?tree=jobs%5Bname,jobs%5Bname,builds%5Bnumber,result%5D%5D%5D" && jq -r ".jobs[] | .name as \$j | .jobs[]? | \"jenkins-build \(\$j)/\(.name) \([.builds[] | \"#\(.number)=\(.result)\"] | join(\" \"))\"" <<<"$HTTP_BODY" | sort
sq() { [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"; local m="$1" y="$2"; shift 2; _istek "$_SQ_CFG" "$m" "${SONAR_URL}${y}" "$@"; }
sq GET "/api/project_analyses/search?project=saha-portal-ekip$nn&ps=100" && jq -r ".analyses[] | \"sonar-analiz \(.date) \(.revision[0:8])\"" <<<"$HTTP_BODY"
sq GET "/api/user_tokens/search?login=ekip$nn" && jq -r ".userTokens[] | \"sonar-token \(.name) \(.type) \(.createdAt)\"" <<<"$HTTP_BODY"
true
' _ "$nn" < /dev/null 2>&1
docker compose exec -T jenkins-agent sh -c "docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep '/ekip-$nn/' | sort | sed 's/^/agent-imaj /'" 2>&1
else
  echo "ci profili calismiyor"
fi
