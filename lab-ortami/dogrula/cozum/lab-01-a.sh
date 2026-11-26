# LAB 01-A cozumu: starter proje, build ve dependency. Adimlar ogrenci rehberiyle aynidir.
adim="${ADIM:?ADIM gerekli}"

case "$adim" in
kur)
  baslik "Adim 1: starter projeyi klonla, klasorleri incele"
  cd "$HOME"
  [ ! -e "$REPO" ] || { echo "HATA: $REPO zaten var" >&2; exit 1; }
  kos git clone "$GITLAB_URL/$TEMPLATE_PROJECT.git" saha-ekipman-portal
  cd "$REPO"
  kos git config --global user.name "Ekip $EKIP"
  kos git config --global user.email "ekip$EKIP@${GITLAB_HOST#gitlab.}"
  kos git branch -a
  kos tree -L 2 -I 'node_modules|bin|obj' --dirsfirst

  baslik "Adim 2: dotnet restore, build, test"
  kos dotnet restore SahaPortal.sln
  kos dotnet build SahaPortal.sln -c Release --no-restore
  kos dotnet test SahaPortal.sln -c Release --no-build

  baslik "Adim 3: web-ui icinde npm ci ve npm test"
  cd "$REPO/src/web-ui"
  kos npm ci
  kos npm test

  baslik "Adim 4: NuGet bagimlilik agaci"
  cd "$REPO"
  kos dotnet list src/order-service package --include-transitive

  baslik "Adim 5: npm bagimlilik agaci"
  cd "$REPO/src/web-ui"
  kos npm ls --depth=0
  kos npm ls react
  ;;

catisma)
  baslik "Adim 6: lab/01a-conflict uzerindeki NU1605"
  cd "$REPO"
  kos git switch lab/01a-conflict
  kabuk "grep -n 'EntityFrameworkCore' src/order-service/order-service.csproj"
  beklenen_hata "NU1605" dotnet restore SahaPortal.sln
  not_ "Cozum: dogrudan referansi gecisli surumle hizala"
  kos dotnet add src/order-service package Microsoft.EntityFrameworkCore -v 10.0.15
  kos dotnet restore SahaPortal.sln
  kos dotnet build SahaPortal.sln -c Release --no-restore
  kos dotnet test SahaPortal.sln -c Release --no-build
  kos git add src/order-service/order-service.csproj
  kos git commit -m "fix(order): align EntityFrameworkCore version"
  kos git switch main
  ;;

baslat)
  baslik "Adim 7: API'leri ve web-ui'yi baslat"
  cd "$REPO"
  mkdir -p "$HOME/.lab-log"
  not_ "Uc ayri terminal yerine arka planda baslatilir; loglar ~/.lab-log altinda"
  printf '$ dotnet run --project src/product-service\n'
  setsid nohup dotnet run --project src/product-service > "$HOME/.lab-log/product-service.log" 2>&1 < /dev/null &
  printf '$ dotnet run --project src/order-service\n'
  setsid nohup dotnet run --project src/order-service > "$HOME/.lab-log/order-service.log" 2>&1 < /dev/null &
  printf '$ (cd src/web-ui && npm run dev)\n'
  ( cd src/web-ui && setsid nohup npm run dev > "$HOME/.lab-log/web-ui.log" 2>&1 < /dev/null & )
  http_bekle http://localhost:5101/health 120 || { tail -n 20 "$HOME/.lab-log/product-service.log"; exit 1; }
  http_bekle http://localhost:5102/health 120 || { tail -n 20 "$HOME/.lab-log/order-service.log"; exit 1; }
  http_bekle http://localhost:5173/ 60 || { tail -n 20 "$HOME/.lab-log/web-ui.log"; exit 1; }
  kabuk "curl -s http://localhost:5101/health; echo"
  kabuk "curl -s http://localhost:5102/health; echo"
  kabuk "curl -s http://localhost:5101/api/products; echo"
  kabuk "curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5101/swagger/index.html"
  kabuk "curl -s http://localhost:5173/api/products | head -c 80; echo"
  ;;

durdur)
  baslik "Calisan uygulamalari durdur (her terminalde Ctrl+C)"
  pkill -u "$(id -un)" -f 'src/product-service' || true
  pkill -u "$(id -un)" -f 'src/order-service' || true
  pkill -u "$(id -un)" -f 'vite' || true
  pkill -u "$(id -un)" -f 'product-service$' || true
  pkill -u "$(id -un)" -f 'order-service$' || true
  sleep 2
  kabuk "curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 http://localhost:5173/ || true"
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
