#!/usr/bin/env bash
# On lab: gercek terminal + tarayici akisi; her labin ardindan basari denetimi.
# Host / bash 3.2. Yalnizca ekip-99; var olan ekibi otomatik sifirlamaz.
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

ilk="${BASLANGIC:-01-a}"
son="${SON:-05-b}"
lablar=(01-a 01-b 02-a 02-b 03-a 03-b 04-a 04-b 05-a 05-b)
case " ${lablar[*]} " in *" $ilk "*) ;; *) echo "BASLANGIC gecersiz: $ilk" >&2; exit 2 ;; esac
case " ${lablar[*]} " in *" $son "*) ;; *) echo "SON gecersiz: $son" >&2; exit 2 ;; esac
[[ "$ilk" > "$son" ]] && { echo 'BASLANGIC, SONdan sonra olamaz' >&2; exit 2; }
grep -qx 'LAB_MODE=sandbox' lab.env || { echo 'Yalnizca sandbox modunda calisir.' >&2; exit 2; }
docker info >/dev/null || { echo 'Docker erisimi yok; ortam kapali diye yorumlanmadi.' >&2; exit 2; }

if [[ "$ilk" < '04-a' && "$son" > '03-a' ]] && [ "${PROVA_VOLUME_SILME_ONAYI:-}" != 'ekip-99' ]; then
  echo 'LAB 03-B, yeni ekip99_orders-data deneme volumeunu silip yeniden olusturur.' >&2
  echo 'Yalnizca kullanicinin acik onayindan sonra PROVA_VOLUME_SILME_ONAYI=ekip-99 verin.' >&2
  exit 2
fi

damga="$(date -u +%Y%m%dT%H%M%SZ)"
kanit="${KANIT_DIZINI:-../kanit/faz-6/prova-$damga}"
mkdir -p "$kanit"
kanit="$(cd "$kanit" && pwd)"
export LAB_IMG_DIR="/lab/cikti/prova-$damga"
mkdir -p ".cache/ui/prova-$damga"
[ -f "$kanit/sonuclar.tsv" ] || printf 'lab\tdurum\tsaniye\n' > "$kanit/sonuclar.tsv"
printf '\nkosu=%s\nbaslangic=%s\nson=%s\npaylasilan=%s\ngorseller=%s\n' "$damga" "$ilk" "$son" "${PROVA_PAYLASILAN:-0}" "$LAB_IMG_DIR" >> "$kanit/kosul.txt"

if [ "$ilk" = '01-a' ]; then
  # Durumu belirsiz bir projeye ya da calisma kopyasina yazmayiz.
  docker compose run --rm -T araclar bash -c '
    source bootstrap/lib.sh
    if gl GET /projects/egitim%2Fekip-99%2Fsaha-ekipman-portal; then
      olum "ekip-99 projesi zaten var; otomatik silinmez"
    fi
    [ "$HTTP_CODE" = 404 ] || olum "proje sorgusu: HTTP $HTTP_CODE"
  ' < /dev/null
  if docker compose exec -T workstation test -e /home/ekip99/saha-ekipman-portal; then
    echo 'ekip99 calisma kopyasi var; BASLANGIC ile uygun labdan surdurun.' >&2; exit 2
  fi
  # Ek ekip kalici kayitli olmali: sonraki bootstrap/CI kontrolleri onu da tanisin.
  # .env sirlarini ciktiya yazmadan yalnizca EK_EKIPLER satirini guncelle.
  if ! env_degeri EK_EKIPLER | tr ' ' '\n' | grep -qx 99; then
    (umask 077; awk '
      /^EK_EKIPLER=/ { print $0 " 99"; bulundu=1; next }
      { print }
      END { if (!bulundu) print "EK_EKIPLER=99" }
    ' .env > .env.prova.tmp)
    mv .env.prova.tmp .env
  fi
  # Mevcut bootstrap kurallarini kullanir; ekip listesi yalnizca 99dur.
  # Paylasilan servis ayarlari idempotent olarak mevcut degerleriyle korunur.
  for betik in 10-gitlab 20-nexus 60-jenkins 70-sonarqube; do
    docker compose run --rm -T -e EKIP_SAYISI=0 -e EK_EKIPLER=99 araclar bash "bootstrap/$betik.sh" < /dev/null >> "$kanit/hazirlik.log" 2>&1
  done
  # Container yeniden build edilmeden guncel lab-users betigini kullan.
  docker compose exec -T workstation bash -s -- 99 < images/workstation/lab-users.sh >> "$kanit/hazirlik.log" 2>&1
  EKIP_SAYISI=0 EK_EKIPLER=99 bash bootstrap/50-workstation.sh >> "$kanit/hazirlik.log" 2>&1
  EKIP_SAYISI=0 EK_EKIPLER=99 bash bootstrap/40-test-vm.sh >> "$kanit/hazirlik.log" 2>&1
fi

for lab in "${lablar[@]}"; do
  [[ "$lab" < "$ilk" || "$lab" > "$son" ]] && continue
  echo "LAB $lab basliyor (ekip-99); kanit: $kanit/$lab-akis.log"
  bas="$(date +%s)"
  if bash dogrula/cozum.sh "$lab" 99 > "$kanit/$lab-akis.log" 2>&1 &&
     bash dogrula/lab.sh "lab-$lab" 99 > "$kanit/$lab-dogrula.log" 2>&1; then
    printf '%s\tGECTI\t%s\n' "$lab" "$(($(date +%s) - bas))" | tee -a "$kanit/sonuclar.tsv"
  else
    printf '%s\tKALDI\t%s\n' "$lab" "$(($(date +%s) - bas))" | tee -a "$kanit/sonuclar.tsv"
    echo "Ilk hatada duruldu. $kanit altindaki akis/dogrula loglarini inceleyin." >&2
    exit 1
  fi
done
echo "Secilen lablar gecti. Temiz kurulum iddiasi icin ayrica volume/kurulum kaniti gerekir: $kanit"
