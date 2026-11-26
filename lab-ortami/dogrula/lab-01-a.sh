# LAB 01-A dogrulamasi: starter proje, build ve dependency.
# Basari kriteri: build ve testler yesil; surum cakismasi giderildi; katalog listeleniyor
# ve talep olusturulabiliyor. Katilimci makinesinde calisir; calisma agacini degistirmez.
baslik "LAB 01-A (ekip-$EKIP)"
[ -d "$REPO/.git" ] || { kaldi "repo yok: $REPO"; ozet; return 1; }
cd "$REPO"
gecti "repo var: $REPO ($(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD))"

baslik "Build ve testler"
cikti="$(dotnet build SahaPortal.sln -c Release 2>&1)"; kod=$?
esit "dotnet build (cikis kodu)" "0" "$kod"
[ "$kod" -eq 0 ] || printf '%s\n' "$cikti" | grep -E 'error' | head -n 5
cikti="$(dotnet test SahaPortal.sln -c Release --no-build 2>&1)"; kod=$?
esit "dotnet test (cikis kodu)" "0" "$kod"
printf '%s\n' "$cikti" | grep -E '^(Passed|Failed)!' | sed 's/^/         /'
if [ -d src/web-ui/node_modules ]; then
  cikti="$(cd src/web-ui && npm test 2>&1)"; kod=$?
  esit "npm test (cikis kodu)" "0" "$kod"
  printf '%s\n' "$cikti" | grep -E '^Tests:' | sed 's/^/         /'
else
  kaldi "src/web-ui/node_modules yok: npm ci calistirilmamis"
fi

baslik "Surum cakismasi (NU1605)"
sablon="$(sablon_sha lab/01a-conflict)"
if d="$(agac "$sablon")"; then
  cikti="$(cd "$d" && dotnet restore src/order-service 2>&1)"; kod=$?
  if [ "$kod" -ne 0 ] && printf '%s' "$cikti" | grep -q 'NU1605'; then
    gecti "hazir branch'te hata uretiliyor: origin lab/01a-conflict -> NU1605"
  else
    kaldi "hazir branch'te NU1605 bekleniyordu (cikis kodu $kod)"
  fi
else
  kaldi "lab/01a-conflict commit'i yerelde yok ($sablon)"
fi
if git show-ref --verify --quiet refs/heads/lab/01a-conflict; then
  if [ "$(git rev-parse lab/01a-conflict)" = "$sablon" ]; then
    kaldi "yerel lab/01a-conflict hazir branch ile ayni: cozum commit'i yok"
  elif d="$(agac lab/01a-conflict)"; then
    cikti="$(cd "$d" && dotnet restore src/order-service 2>&1)"; kod=$?
    esit "cozulmus branch'te dotnet restore (cikis kodu)" "0" "$kod"
    [ "$kod" -eq 0 ] || printf '%s\n' "$cikti" | grep -E 'error' | head -n 3
  fi
else
  kaldi "yerel lab/01a-conflict branch'i yok (cakisma cozulmemis ya da checkpoint uygulanmamis)"
fi

baslik "Calisan uygulama (gecici portlarda, gecici veritabaniyla)"
p1=$((15100 + 10#$EKIP * 2)); p2=$((p1 + 1))
veri="$(mktemp -d)"; _GECICI+=("$veri")
( cd src/product-service/bin/Release/net10.0 && ASPNETCORE_URLS="http://127.0.0.1:$p1" exec dotnet product-service.dll ) >"$veri/product.log" 2>&1 &
_SURECLER+=("$!")
( cd src/order-service/bin/Release/net10.0 && ASPNETCORE_URLS="http://127.0.0.1:$p2" ConnectionStrings__Orders="Data Source=$veri/orders.db" exec dotnet order-service.dll ) >"$veri/order.log" 2>&1 &
_SURECLER+=("$!")
if http_bekle "http://127.0.0.1:$p1/health" && http_bekle "http://127.0.0.1:$p2/health"; then
  esit "product-service /health" "Healthy" "$(curl -s "http://127.0.0.1:$p1/health")"
  esit "order-service /health" "Healthy" "$(curl -s "http://127.0.0.1:$p2/health")"
  urunler="$(curl -s "http://127.0.0.1:$p1/api/products")"
  icerir "katalog listeleniyor (ADP-01 Terminal adaptörü)" '"code":"ADP-01","name":"Terminal adaptörü"' "$urunler"
  esit "katalogdaki urun sayisi en az 3" "evet" "$([ "$(jq 'length' <<<"$urunler")" -ge 3 ] && echo evet || echo hayir)"
  esit "/swagger" "200" "$(http_kodu "http://127.0.0.1:$p1/swagger/index.html")"
  esit "talep olusturma: POST /api/orders" "201" \
    "$(http_kodu -X POST "http://127.0.0.1:$p2/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 2 }')"
  icerir "talep listede: GET /api/orders" '"productId":"ADP-01","quantity":2' "$(curl -s "http://127.0.0.1:$p2/api/orders")"
else
  kaldi "API'ler baslamadi"; tail -n 5 "$veri/product.log" "$veri/order.log"
fi
bilgi "tarayicidaki arayuz bu betikle denetlenmez; kaniti lab-rehberleri/img/lab-01-a-arayuz.png"

ozet
