# LAB 05-A cozumu: ortak paket Nexus'ta. Adimlar ogrenci rehberiyle aynidir.
# NEXUS_APIKEY ortamdan gelir (arayuzde alinir); komut satirina yazilmaz.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"
PAKET="Saha.Common.Contracts.Ekip$EKIP"
HOSTED="$NEXUS_URL/repository/nuget-hosted/"

case "$adim" in
kimlik)
  baslik "Adim 1: PackageId (ekip sonekiyle) ve Version"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/ortak-paket
  cozumden lab-05a src/common-contracts/common-contracts.csproj
  ci_kisisellestir src/common-contracts/common-contracts.csproj
  kabuk "grep -n -E 'PackageId|<Version>|Description' src/common-contracts/common-contracts.csproj"
  ;;

pack)
  baslik "Adim 2: dotnet pack; paketin icini incele"
  kos dotnet pack src/common-contracts -c Release -o out
  kabuk "ls out/"
  kabuk "unzip -l out/$PAKET.1.0.0.nupkg"
  kabuk "unzip -p out/$PAKET.1.0.0.nupkg $PAKET.nuspec | grep -E '<id>|<version>|<dependencies|<group'"
  ;;

push)
  baslik "Adim 3: 1.0.0'i Nexus hosted depoya push et"
  : "${NEXUS_APIKEY:?NEXUS_APIKEY gerekli}"
  printf '$ dotnet nuget push out/%s.1.0.0.nupkg --source %s --api-key "$NEXUS_APIKEY"\n' "$PAKET" "$HOSTED"
  dotnet nuget push "out/$PAKET.1.0.0.nupkg" --source "$HOSTED" --api-key "$NEXUS_APIKEY" \
    || { echo "HATA: push basarisiz" >&2; exit 1; }
  ;;

push-tekrar)
  baslik "Adim 4: ayni surumu yeniden push et (reddedilmeli)"
  : "${NEXUS_APIKEY:?NEXUS_APIKEY gerekli}"
  printf '$ dotnet nuget push out/%s.1.0.0.nupkg --source %s --api-key "$NEXUS_APIKEY"\n' "$PAKET" "$HOSTED"
  cikti="$(dotnet nuget push "out/$PAKET.1.0.0.nupkg" --source "$HOSTED" --api-key "$NEXUS_APIKEY" 2>&1)"; kod=$?
  printf '%s\n' "$cikti"
  [ "$kod" -ne 0 ] || { echo "HATA: ikinci push basarili oldu; reddedilmesi bekleniyordu" >&2; exit 1; }
  case "$cikti" in
    *"409"*"redeploy is not allowed"*) not_ "beklenen hata olustu: 409, yayinlanmis surum degistirilemez" ;;
    *) echo "HATA: 409 / redeploy is not allowed bekleniyordu" >&2; exit 1 ;;
  esac
  ;;

referans)
  baslik "Adim 5: ProjectReference yerine PackageReference; Dockerfile'lar paketi Nexus'tan alir"
  kabuk "grep -n 'common-contracts' src/order-service/order-service.csproj src/product-service/product-service.csproj src/*/Dockerfile"
  cozumden lab-05a src/order-service/order-service.csproj src/product-service/product-service.csproj \
    src/order-service/Dockerfile src/product-service/Dockerfile
  ci_kisisellestir src/order-service/order-service.csproj src/product-service/product-service.csproj
  kabuk "git diff --stat"
  kabuk "grep -n 'Saha.Common.Contracts' src/order-service/order-service.csproj src/product-service/product-service.csproj"
  kabuk "grep -c 'common-contracts' src/order-service/Dockerfile src/product-service/Dockerfile || true"
  ;;

restore)
  baslik "Adim 6: onbellegi temizle; restore'un Nexus'tan geldigini gor"
  kos dotnet nuget locals all --clear
  kabuk "dotnet restore SahaPortal.sln -v n | grep -i -E 'saha\\.common\\.contracts|Installed|error' | head -n 8"
  kabuk "dotnet build SahaPortal.sln -c Release --no-restore 2>&1 | tail -n 3"
  kabuk "dotnet test SahaPortal.sln -c Release --no-build 2>&1 | grep -E 'Passed!|Failed!'"
  not_ "Paket artik kaynaktan degil Nexus'tan: imaj da ayni yoldan"
  kabuk "docker build -q -f src/order-service/Dockerfile --build-arg MCR=\$MCR -t ekip$EKIP-yerel/order-service:paket . && docker rmi -f ekip$EKIP-yerel/order-service:paket > /dev/null && echo 'order-service imaji paketle derlendi'"
  ;;

gonder)
  baslik "Adim 7: commit, push (MR arayuzde)"
  rol dev
  kos git add src/common-contracts/common-contracts.csproj src/order-service src/product-service
  kabuk "git status --short"
  kos git commit -q -m "build(contracts): consume common contracts as a NuGet package"
  kos git push -q -u origin feature/ortak-paket
  kabuk "git log --oneline -n 1"
  ;;

sonuc)
  baslik "Merge sonrasi"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/ortak-paket
  kabuk "git log --oneline --graph -n 4 origin/develop"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-05a .gitlab/CODEOWNERS Jenkinsfile ci/analyze.sh \
    src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj
  kisisel_ayni origin/develop lab-05a Jenkinsfile ci/analyze.sh \
    src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
