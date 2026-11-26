# LAB 02-B dogrulamasi: release ve hotfix dongusu.
# Basari kriteri: v1.0.0 ve v1.0.1 tag'leri var; hotfix commit'i hem main'de hem develop'ta;
# adimlar MR gecmisinden izlenebiliyor.
baslik "LAB 02-B (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi

baslik "Tag'ler"
for t in v1.0.0 v1.0.1; do
  if api "$PROJE_API/repository/tags/$t"; then
    if [ "$(jq -r '(.message // "") != "" and .target != .commit.id' <<<"$API_GOVDE")" = "true" ]; then
      gecti "$t annotated tag: \"$(jq -r '.message' <<<"$API_GOVDE" | head -n 1)\""
    else
      kaldi "$t annotated degil (git tag -a ile atilmali)"
    fi
    sha="$(jq -r '.commit.id' <<<"$API_GOVDE")"
    api "$PROJE_API/repository/commits/$sha/refs?type=branch&per_page=100"
    esit "$t main uzerinde" "evet" "$(jq -r 'if any(.[]; .name == "main") then "evet" else "hayir" end' <<<"$API_GOVDE")"
  else
    kaldi "$t yok"
  fi
done
if api "$PROJE_API/protected_tags/$(urlenc 'v*')"; then
  esit "v* tag'ini olusturabilen" "Maintainers" "$(jq -r '[.create_access_levels[].access_level] | if . == [40] then "Maintainers" else tostring end' <<<"$API_GOVDE")"
else
  kaldi "v* korumali tag degil"
fi

baslik "CHANGELOG (main)"
if api "$PROJE_API/repository/files/CHANGELOG.md/raw?ref=main"; then
  icerir "1.0.0 bolumu" "## [1.0.0]" "$API_GOVDE"
  icerir "1.0.1 bolumu" "## [1.0.1]" "$API_GOVDE"
else
  kaldi "CHANGELOG.md okunamadi"
fi

baslik "Hotfix iki yerde"
if [ -d "$REPO/.git" ] && git -C "$REPO" fetch --quiet --tags origin 2>/dev/null; then
  cd "$REPO"
  duzeltmeler="$(git log --no-merges --format=%H v1.0.0..v1.0.1 -- src/order-service 2>/dev/null)"
  if [ -z "$duzeltmeler" ]; then
    kaldi "v1.0.0..v1.0.1 arasinda order-service'e dokunan commit yok"
  else
    for c in $duzeltmeler; do
      ozetc="$(git log -1 --format='%h %s' "$c")"
      git merge-base --is-ancestor "$c" origin/main && gecti "main'de: $ozetc" || kaldi "main'de degil: $ozetc"
      git merge-base --is-ancestor "$c" origin/develop && gecti "develop'ta: $ozetc" || kaldi "develop'ta degil: $ozetc"
    done
  fi
  esit "release geri merge edilmis (v1.0.0 develop gecmisinde)" "evet" "$(git merge-base --is-ancestor v1.0.0 origin/develop && echo evet || echo hayir)"

  baslik "Davranis: bos ekipman kodu"
  p=$((15200 + 10#$EKIP * 2))
  for t in v1.0.0 v1.0.1; do
    if d="$(agac "$t")"; then
      if (cd "$d" && dotnet build src/order-service -c Release >/dev/null 2>&1); then
        veri="$(mktemp -d)"; _GECICI+=("$veri")
        ( cd "$d/src/order-service/bin/Release/net10.0" && ASPNETCORE_URLS="http://127.0.0.1:$p" ConnectionStrings__Orders="Data Source=$veri/orders.db" exec dotnet order-service.dll ) >"$veri/log" 2>&1 &
        surec=$!; _SURECLER+=("$surec")
        if http_bekle "http://127.0.0.1:$p/health"; then
          bos="$(http_kodu -X POST "http://127.0.0.1:$p/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "", "quantity": 1 }')"
          dolu="$(http_kodu -X POST "http://127.0.0.1:$p/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 1 }')"
          if [ "$t" = "v1.0.0" ]; then
            esit "$t: bos ekipman kodu kabul ediliyor (hata surumde duruyor)" "201" "$bos"
          else
            esit "$t: bos ekipman kodu reddediliyor" "400" "$bos"
            esit "$t: gecerli talep" "201" "$dolu"
          fi
        else
          kaldi "$t: order-service baslamadi"
        fi
        kill "$surec" 2>/dev/null; wait "$surec" 2>/dev/null
      else
        kaldi "$t: order-service derlenemedi"
      fi
    fi
    p=$((p + 1))
  done
else
  kaldi "yerel repo origin'den tag'leri getiremedi ($REPO)"
fi

baslik "MR gecmisi"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  for cift in "release/1.0.0 main" "hotfix/1.0.1 main" "release/1.0.0 develop" "hotfix/1.0.1 develop"; do
    set -- $cift
    api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc "$1")&target_branch=$2&per_page=5"
    mr="$(jq -c '.[0] // empty' <<<"$API_GOVDE")"
    if [ -n "$mr" ]; then
      gecti "MR !$(jq -r '.iid' <<<"$mr"): $1 -> $2 merge edilmis"
      [ "$(jq -r '.squash' <<<"$mr")" = "false" ] || kaldi "$1 -> $2: squash kullanilmis (surum izi kaybolur)"
    else
      kaldi "$1 -> $2 icin merge edilmis MR yok"
    fi
  done
fi

ozet
