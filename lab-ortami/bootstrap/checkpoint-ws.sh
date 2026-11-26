# checkpoint-uygula.sh'in katilimci makinesi tarafi. Ekip kullanicisiyla calisir.
# Ortam: LAB (lab-01a|gun1|lab-02a|lab-02b|lab-03a|lab-03b|lab-04a|lab-04b|lab-05a|final);
# lab-03b ve sonrasi icin DEPLOY_TOKEN, PULL_TOKEN; lab-05a ve final icin NEXUS_APIKEY
# (ekibin paketi Nexus'a ekibin kendi anahtariyla yayinlanir; LAB 05-A adim 3).
# Yalnizca bu kullanicinin ev dizinine ve bu ekibin imajlarina dokunur. Var olan repo silinmez,
# ~/yedek altina tasinir.
set -euo pipefail
REPO="$HOME/saha-ekipman-portal"
PROJE_SSH="git@$GITLAB_HOST:$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal.git"
tamam() { printf '    \033[32mtamam\033[0m  %s\n' "$*"; }

if [ -e "$REPO" ]; then
  mkdir -p "$HOME/yedek"
  yedek="$HOME/yedek/saha-ekipman-portal-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO" "$yedek"
  tamam "onceki calisma kopyasi tasindi: ${yedek/#$HOME/~}"
fi
git config --global user.name >/dev/null 2>&1 || git config --global user.name "Ekip $EKIP"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "ekip$EKIP@${GITLAB_HOST#gitlab.}"

case "$LAB" in
  lab-01a|gun1)
    git clone --quiet "$GITLAB_URL/$TEMPLATE_PROJECT.git" "$REPO"
    cd "$REPO"
    git branch --quiet lab/01a-conflict origin/checkpoint/lab-01a
    if [ "$LAB" = "gun1" ]; then
      git switch --quiet -c feature/katalog-sarj-unitesi origin/checkpoint/gun1
      git branch --quiet --unset-upstream
    fi
    tamam "repo: ${REPO/#$HOME/~} ($(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD)); lab/01a-conflict cozulmus halde"
    ;;
  *)
    rol dev >/dev/null
    git clone --quiet --origin origin "$PROJE_SSH" "$REPO"
    cd "$REPO"
    git remote add sablon "$GITLAB_URL/$TEMPLATE_PROJECT.git"
    git fetch --quiet sablon
    git fetch --quiet --tags origin
    git switch --quiet develop
    git branch --quiet --track main origin/main 2>/dev/null || true
    if [ "$LAB" = "lab-03a" ]; then git switch --quiet feature/9-docker; fi
    tamam "repo: ${REPO/#$HOME/~} ($(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD)), origin = ekip projesi, sablon = starter"
    ;;
esac

# Jenkins'in test VM anahtari (LAB 05-B adim 1): yorumu jenkins-ekipNN. Once eskisi kaldirilir;
# final checkpoint'inde yeniden uretilip yetkilendirilir (ozel anahtar ~/.ssh/jenkins-test-vm).
ssh -n -o BatchMode=yes "$TEST_VM_USER@$TEST_VM" "sed -i '/ jenkins-ekip${EKIP}\$/d' ~/.ssh/authorized_keys"
rm -f "$HOME/.ssh/jenkins-test-vm" "$HOME/.ssh/jenkins-test-vm.pub"
if [ "$LAB" = "final" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "jenkins-ekip${EKIP}" -f "$HOME/.ssh/jenkins-test-vm"
  ssh-copy-id -i "$HOME/.ssh/jenkins-test-vm.pub" "$TEST_VM_USER@$TEST_VM" >/dev/null 2>&1
  ssh -n -o BatchMode=yes -o IdentitiesOnly=yes -i "$HOME/.ssh/jenkins-test-vm" "$TEST_VM_USER@$TEST_VM" true
  tamam "Jenkins'in deploy anahtari: ~/.ssh/jenkins-test-vm (test VM'de yetkili, yorum jenkins-ekip${EKIP})"
fi

# LAB 05-A: servisler sozlesmeleri Nexus'taki paketten alir. Paket restore'dan once yayinlanir.
case "$LAB" in lab-05a|final)
  : "${NEXUS_APIKEY:?}"
  paket_dizini="$(mktemp -d)"
  dotnet pack src/common-contracts -c Release -o "$paket_dizini" >/dev/null
  dotnet nuget push "$paket_dizini"/*.nupkg --source "$NEXUS_URL/repository/nuget-hosted/" --api-key "$NEXUS_APIKEY" >/dev/null
  tamam "Nexus: $(basename "$paket_dizini"/*.nupkg .nupkg) nuget-hosted'a yayinlandi"
  rm -rf "$paket_dizini"
  ;;
esac

# Paketler: ekip hemen build ve test calistirabilsin.
dotnet restore SahaPortal.sln >/dev/null
( cd src/web-ui && npm ci --silent >/dev/null 2>&1 )
tamam "paketler kuruldu: dotnet restore, npm ci"

case "$LAB" in lab-03b|lab-04a|lab-04b|lab-05a|final) imajli=1 ;; *) imajli=0 ;; esac
if [ "$imajli" -eq 1 ]; then
  : "${DEPLOY_TOKEN:?}" "${PULL_TOKEN:?}"
  # Docker daemon'ina kurum CA'si (LAB 03-B adimi). Sandbox'ta daemon ekipler arasinda ortaktir.
  if [ ! -f "/etc/docker/certs.d/$REGISTRY/ca.crt" ]; then
    sudo mkdir -p "/etc/docker/certs.d/$REGISTRY"
    sudo cp "$CA_CERT" "/etc/docker/certs.d/$REGISTRY/ca.crt"
    tamam "Docker daemon'ina kurum CA'si tanitildi: /etc/docker/certs.d/$REGISTRY/ca.crt"
  fi
  printf '%s' "$DEPLOY_TOKEN" | docker login "$REGISTRY" -u "ekip$EKIP-deploy" --password-stdin >/dev/null 2>&1
  # 1.0.1 imajlari LAB 03-B sonundaki commit'ten derlenir. Sonraki checkpoint'lerde o commit,
  # develop'un ilk-ebeveyn zincirinde sablondaki kadar geridedir.
  geri="$(git rev-list --first-parent --count "sablon/checkpoint/lab-03b..sablon/checkpoint/$LAB")"
  [ "$geri" -eq 0 ] || git checkout --quiet --detach "HEAD~$geri"
  SHA="$(git rev-parse --short HEAD)"
  docker build --quiet -f src/order-service/Dockerfile --build-arg "MCR=$MCR" -t "$IMG/order-service:1.0.1" -t "$IMG/order-service:$SHA" . >/dev/null
  docker build --quiet -f src/product-service/Dockerfile --build-arg "MCR=$MCR" -t "$IMG/product-service:1.0.1" -t "$IMG/product-service:$SHA" . >/dev/null
  docker build --quiet -f src/web-ui/Dockerfile --build-arg "HUB=$HUB" -t "$IMG/web-ui:1.0.1" -t "$IMG/web-ui:$SHA" . >/dev/null
  for s in order-service product-service web-ui; do
    docker push --quiet --all-tags "$IMG/$s" >/dev/null
  done
  [ "$geri" -eq 0 ] || git switch --quiet develop
  tamam "imajlar registry'de: order-service, product-service, web-ui (1.0.1 ve $SHA)"
  # Token'lar ekibin sonraki lablari icin ev dizininde saklanir (yalnizca bu kullanici okur).
  mkdir -p "$HOME/.lab" && chmod 700 "$HOME/.lab"
  ( umask 077; printf 'ekip%s-deploy %s\nekip%s-pull %s\n' "$EKIP" "$DEPLOY_TOKEN" "$EKIP" "$PULL_TOKEN" > "$HOME/.lab/deploy-tokens" )
  tamam "deploy token'lar: ~/.lab/deploy-tokens (yalnizca bu kullanici okuyabilir)"
  printf 'COMPOSE_BASLANGIC\n'
  cat deploy/compose.yaml
fi
