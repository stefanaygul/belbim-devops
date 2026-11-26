# LAB 05-B sonrasi ek hata/duzeltme denetimleri. dogrula/lab.sh ek-hatalar 99
# Ana repoyu, ortak ayarlari veya veri volume'larini degistirmez.
set -uo pipefail
[ "$EKIP" = 99 ] || { echo 'Yalnizca prova ekibi 99.' >&2; return 2; }
d="$(mktemp -d)"
_GECICI+=("$d")
a="ekip99-port-demo-a"
b="ekip99-port-demo-b"
trap 'docker rm -f "$a" "$b" >/dev/null 2>&1 || true; _temizle' EXIT

baslik 'Git TLS: yanlis CA -> dogru CA'
mkdir -p "$d/bos-ca"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=egitim-yanlis-ca \
  -keyout "$d/key.pem" -out "$d/ca.pem" >/dev/null 2>&1
cikti="$(git -c http.sslVerify=true -c "http.sslCAInfo=$d/ca.pem" -c "http.sslCAPath=$d/bos-ca" \
  ls-remote "$GITLAB_URL/$TEMPLATE_PROJECT.git" refs/heads/main 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -qi 'certificate' && gecti 'yanlis CA ile Git reddedildi' || kaldi 'Git sertifika hatasi bekleniyordu'
git -c "http.sslCAInfo=$CA_CERT" ls-remote "$GITLAB_URL/$TEMPLATE_PROJECT.git" refs/heads/main >/dev/null && gecti 'dogru CA ile Git basarili' || kaldi 'dogru CA ile Git basarisiz'

baslik 'Docker soket izni: yetkisiz -> ekip kullanicisi'
cikti="$(sudo -u nobody docker -H unix:///var/run/docker.sock info 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -qi 'permission denied' && gecti 'yetkisiz kullanici Docker soketine erisemedi' || kaldi 'Docker permission denied bekleniyordu'
docker info >/dev/null 2>&1 && gecti 'ekip kullanicisi Docker kullanabiliyor' || kaldi 'ekip kullanicisi Docker kullanamiyor'

baslik 'Port cakismasi -> bos port'
docker run -d --name "$a" -p 127.0.0.1::8080 "$HUB/nginxinc/nginx-unprivileged:stable-alpine" >/dev/null || return 1
port="$(docker inspect --format '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' "$a")"
cikti="$(docker run -d --name "$b" -p "127.0.0.1:$port:8080" "$HUB/nginxinc/nginx-unprivileged:stable-alpine" 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -qiE 'address already in use|port is already allocated|Bind for' && gecti 'ikinci container ayni porta baglanamadi' || kaldi 'port cakismasi bekleniyordu'
docker rm "$b" >/dev/null
docker run -d --name "$b" -p 127.0.0.1::8080 "$HUB/nginxinc/nginx-unprivileged:stable-alpine" >/dev/null && gecti 'ikinci container bos portta basladi' || kaldi 'bos portta baslamadi'
docker rm -f "$a" "$b" >/dev/null

baslik 'NU1101: bos feed -> Nexus group'
mkdir -p "$d/proje" "$d/feed" "$d/paketler"
cat > "$d/proje/demo.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Saha.Common.Contracts.Ekip99" Version="1.0.0" /></ItemGroup></Project>
EOF
cikti="$(dotnet restore "$d/proje/demo.csproj" --packages "$d/paketler" --source "$d/feed" 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -q NU1101 && gecti 'bos feed NU1101 uretti' || kaldi 'NU1101 bekleniyordu'
dotnet restore "$d/proje/demo.csproj" --packages "$d/paketler" --source "$NUGET_GROUP_URL" > "$d/restore.log" 2>&1 && gecti 'Nexus group ile ayni proje restore edildi' || kaldi 'Nexus restore basarisiz'

baslik 'Registry: olmayan etiket -> 1.1.0'
cikti="$(docker pull "$IMG/order-service:egitimde-olmayan-etiket" 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -qiE 'manifest unknown|not found' && gecti 'olmayan etiket reddedildi' || kaldi 'manifest not found bekleniyordu'
docker pull "$IMG/order-service:1.1.0" >/dev/null 2>&1 && gecti 'var olan 1.1.0 cekildi' || kaldi '1.1.0 cekilemedi'

baslik 'Olmayan etiketle deploy calisan surume dokunmaz'
vm() { ssh -n "$TEST_VM_USER@$TEST_VM" "cd /opt/saha/ekip99 && $*"; }
once="$(vm 'sha256sum .env deploy-kayit.log; docker ps --filter label=com.docker.compose.project=ekip99 --format "{{.ID}} {{.Image}}"' | sort)"
cikti="$(vm "sh deploy.sh $IMG egitimde-olmayan-etiket $WEB_PORT - demo" 2>&1)"; kod=$?
[ "$kod" -ne 0 ] && gecti 'deploy pull asamasinda durdu' || kaldi 'olmayan etiketle deploy basarili olmamali'
sonra="$(vm 'sha256sum .env deploy-kayit.log; docker ps --filter label=com.docker.compose.project=ekip99 --format "{{.ID}} {{.Image}}"' | sort)"
esit 'env, deploy kaydi, container kimlikleri ve imajlari ayni' "$once" "$sonra"
esit 'mevcut uygulama cevap veriyor' 200 "$(http_kodu "$TEST_URL/api/orders/summary")"
ozet
