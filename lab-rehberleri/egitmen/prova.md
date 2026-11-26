# Uçtan uca prova

On lab, `dogrula/cozum.sh` üzerinden gerçek terminal komutları ve Playwright arayüz işlemleriyle yürür; her labdan hemen sonra `dogrula/lab.sh` başarı ölçütlerini denetler. Checkpoint uygulanarak lab geçmişi taklit edilmez. Prova ekibi **99**, test portu **8099**'dur.

## Hazır ortamda yeni ekip

Host'ta `lab-ortami/` içinde:

```bash
# LAB 03-B'nin yalnızca ekip99 yerel deneme volume'unu silmesine açık izin alındıktan sonra:
PROVA_VOLUME_SILME_ONAYI=ekip-99 bash dogrula/prova.sh
```

Proje veya çalışma kopyası zaten varsa betik durur; otomatik sıfırlama yapmaz. Mevcut ortak workstation daemon'ı CA'ya güveniyorsa `PROVA_PAYLASILAN=1` verilebilir; x509 olumsuz adımı **ATLANDI** yazılır. Bu seçenek temiz kurulum kanıtı değildir.

## Tam temiz kurulum

**Mevcut bütün ekiplerin uygulama/veri/CI geçmişi silinir. Kullanıcı açıkça onaylamadan çalıştırmayın.** Yalnızca `belbim-lab` Compose projesi etkilenir. `.env`, CA dosyaları, kaynak kod ve host imaj cache'i korunur; bu, servislerin boş volume'larla kurulmasıdır, internetsiz kurulum veya boş host imaj cache'i denemesi değildir.

```bash
TEMIZ_KURULUM_ONAYI=belbim-lab bash dogrula/temiz-prova.sh
```

Sıra: silinecek volume listesi → `down --volumes` → hiç lab volume'u kalmadığı denetimi → `make up-ci` → `make bootstrap` → çekirdek/CI kontrolleri → on lab. Kanıtlar `kanit/faz-6/temiz-prova/`, tarayıcı görüntüleri `lab-ortami/.cache/ui/prova-<UTC-damga>/` altında. Her lab için `*-akis.log`, `*-dogrula.log`; toplam `sonuclar.tsv`. Ekran görüntülerini paylaşmadan önce sır denetimi yapılmalıdır.

## Hata ve devam

İlk başarısız adımda durur; aynı hatayı otomatik üç kez denemez. Logun sonunu okuyun, nedeni düzeltin. Arayüzde kısmen tamamlanmış labı körlemesine tekrar başlatmayın; `cozum.sh <lab> 99 ws <adım>` veya mevcut arayüz adımıyla kontrollü sürdürün. Sonra o labın doğrulamasını çalıştırın; sonraki labdan devam edin:

```bash
bash dogrula/lab.sh lab-03-b 99
BASLANGIC=04-a KANIT_DIZINI=../kanit/faz-6/devam bash dogrula/prova.sh
```

LAB 05-A’da yayın tamamlanıp paket arayüzünde durulduysa `bash dogrula/cozum.sh 05-a 99 lab_05_a_yayindan_sonra` ile devam edilebilir; mevcut `.cache/ui/token-ekip99-nexus` dosyası gereklidir.

`BASLANGIC` ve `SON` ile aralık seçilebilir. Tamamlanmamış labı atlayıp bütün provayı geçmiş saymayın. Devam koşularının loglarını aynı raporda açıkça ilişkilendirin.

## Sınırlar

Kurum ağı, lisanslı GitLab/SonarQube akışları, katılımcı sunumu ve insanla süre ölçümü bu otomatik koşuyla doğrulanmaz. Son durum ve gerçek sayılar [RAPOR.md](../../RAPOR.md) Faz 6 bölümüne işlenir. Önceki Faz 3–5 kanıtları ayrı tutulur.
