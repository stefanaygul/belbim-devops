# LAB 01-A · Çözüm ve eğitmen notları

Starter proje, build ve dependency · 70 dk · Gün 1, Modül 3 · öğrenci rehberi: [`../ogrenci/LAB-01-A.md`](../ogrenci/LAB-01-A.md)

**Durum:** `SANDBOX_VERIFIED`. İki ekiple baştan sona koşuldu; kanıt: `kanit/faz-3/lab-01-a-ekip01.txt`, `lab-01-a-ekip02-sifirdan.txt`.

## Eğitmen komutları

`lab-ortami/` klasöründe çalıştırılır (sandbox). `NN` ekip numarasıdır.

| Ne | Komut |
|---|---|
| Labın çözümünü bir ekip için baştan uygula | `bash dogrula/cozum.sh 01-a NN` |
| Başarı kriterlerini denetle | `make dogrula-lab LAB=01-a EKIP=NN` |
| Ekibi bu labın sonuna getir | `make checkpoint EKIP=NN LAB=lab-01a` |
| Katılımcı makinesi ön kontrolü | `make onkontrol EKIP=NN` |
| Ekibi sıfırla | `make sifirla-ekip EKIP=NN` |

BELBİM ortamında `dogrula/lab-01-a.sh` katılımcı makinesinde doğrudan çalıştırılır: `source dogrula/lib.sh; source dogrula/ortak-ws.sh; source dogrula/lab-01-a.sh` (*bu kullanım biçimi sandbox dışında denenmedi*).

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–10 | 1 · Klonla, incele | **10. dk:** herkes klonlayabildi mi? Dolaşın; klonlayamayan için sertifika ve ağ |
| 10–20 | 2 · restore, build, test | 9 test yeşil |
| 20–30 | 3 · `npm ci`, `npm test` | 14 test yeşil |
| 30–35 | 4 · `dotnet list package` | "EF Core'u kim getiriyor?" sorusunu bir ekibe sorun |
| 35–40 | 5 · `npm ls` | |
| 40–55 | 6 · NU1605 | **50. dk:** hata mesajını okuyabilen var mı? |
| 55–60 | 7 · Çalıştır | Tarayıcıda katalog |
| 60–70 | Toparlama | Başarı kriterleri, sorular |

Lab öncesi demoda yalnızca ilk iki adımı gösterin; gerisini katılımcılara bırakın.

## Çözüm

### Adım 1–5

Komutlar öğrenci rehberindekilerle aynıdır; çözülecek bir şey yoktur. Tartışma sorularının yanıtları:

- `NuGet.config` `<clear />` ile bütün varsayılan kaynakları kaldırır ve yalnızca `$NUGET_GROUP_URL` adresini bırakır; `.npmrc` yalnızca `$NPM_GROUP_URL` adresini gösterir. Kapalı ağda paketlerin tek giriş kapısı Nexus'tur.
- `Microsoft.EntityFrameworkCore`'u `Microsoft.EntityFrameworkCore.Sqlite` → `…Sqlite.Core` → `…Relational` zinciri getirir.
- `deduped`: React'i üç paket ister, diskte tek kopya durur.

### Adım 6 · NU1605

`lab/01a-conflict` branch'i `order-service.csproj` dosyasına tek satır ekler:

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore" Version="9.0.23" />
```

`Microsoft.EntityFrameworkCore.Sqlite` 10.0.15 ise aynı paketin en az 10.0.15 sürümünü ister. Doğrudan referans daha düşük sürümü seçtiği için NuGet "downgrade" der; SDK bunu hata sayar.

**Çözüm A (hizala; checkpoint'teki çözüm):**

```bash
dotnet add src/order-service package Microsoft.EntityFrameworkCore -v 10.0.15
```

**Çözüm B (kaldır):** satırı `.csproj` dosyasından silin ya da `dotnet remove src/order-service package Microsoft.EntityFrameworkCore`. Sonuç `main` ile aynı olur.

İkisi de geçerlidir. Fark tartışma sorusu 3'ün yanıtıdır: A'da doğrudan referans kalır ve `Sqlite` paketi her güncellendiğinde elle hizalanması gerekir; B'de sürümü yalnızca `Sqlite` paketi belirler. Bu projede doğrudan referans gereksizdir, B daha az bakım ister. Slayt A'yı gösterdiği için checkpoint A'yı içerir.

```bash
dotnet restore SahaPortal.sln && dotnet build SahaPortal.sln -c Release --no-restore && dotnet test SahaPortal.sln -c Release --no-build
git add src/order-service/order-service.csproj
git commit -m "fix(order): align EntityFrameworkCore version"
git switch main
```

Çözüm bu branch'te kalır; `main`'e alınmaz. LAB 01-B `main`'den başlar.

### Adım 7

Portlar `launchSettings.json` dosyasından gelir: product-service `5101`, order-service `5102`, Vite `5173`. Arayüz `/api/...` isteklerini Vite proxy'si üzerinden iki API'ye yollar (`src/web-ui/vite.config.mjs`).

## Sık takılınan yerler

- **Slayttaki NU1605 örneği farklı bir paket gösterir** (`Microsoft.Extensions.Logging.Abstractions`, 10.0.0 → 9.0.0). Labdaki paket `Microsoft.EntityFrameworkCore`, sürümler 10.0.15 → 9.0.23. Hata kodu ve okuma biçimi aynıdır; katılımcıya "slayttaki mesajla sizinkini yan yana okuyun" deyin. (`slayt-guncellemeleri.md`)
- **Hata mesajı iki projede çıkar** (`order-service` ve `order-service.tests`): test projesi servise bağlı olduğu için. Tek bir düzeltme ikisini de çözer.
- **`dotnet add package` çıktısındaki `X.509 certificate chain validation will use the fallback certificate bundle` satırları** bilgi mesajıdır; hata değildir.
- **`npm ci` uyarıları** (`deprecated`, `install-scripts`) kurulumu engellemez.
- **Klonlanan repoda `origin/checkpoint/*` branch'leri görünür.** Soran olursa: "takılırsan" branch'leri.
- **Uzak tarayıcı:** Vite varsayılan olarak yalnızca `localhost`'u dinler. Katılımcının tarayıcısı başka makinedeyse `npm run dev -- --host`. Sandbox'ta host tarayıcısı için adresler `ortam-karti.md` içindedir.
- **Sandbox'ta iki ekip aynı makineyi paylaşır:** `5101`, `5102`, `5173` portlarını aynı anda yalnızca bir ekip kullanabilir.

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| 10. dk: klonlayamıyor | Ağ ve CA: `curl -I $GITLAB_URL`. Çözülmüyorsa eşinin makinesinde devam etsin |
| 30. dk: restore ya da `npm ci` hâlâ çalışmıyor | `make onkontrol EKIP=NN`; Nexus erişimi. Ekip beklerken Adım 4–5'i eşinin ekranından izlesin |
| 55. dk: NU1605 çözülmedi | `git switch -C lab/01a-conflict origin/checkpoint/lab-01a`, farkı birlikte okuyun, `git switch main`, Adım 7 |
| 65. dk: uygulama açılmadı | LAB 01-B için gerekmez. `main` üzerinde build ve test yeşilse devam |
| Her şey karıştı | `make checkpoint EKIP=NN LAB=lab-01a` (eski repo `~/yedek/` altına taşınır) |

`main` üzerinde build ve testleri geçen her ekip LAB 01-B'ye başlayabilir; çakışma adımı günün kalanını kilitlemez.
