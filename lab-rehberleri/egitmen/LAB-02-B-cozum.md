# LAB 02-B · Çözüm ve eğitmen notları

Release ve hotfix döngüsü · 80 dk · Gün 2, Modül 4 · öğrenci rehberi: [`../ogrenci/LAB-02-B.md`](../ogrenci/LAB-02-B.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 ile, altı MR ve tag koruması gerçek tarayıcıda yapılarak tek seferde koşuldu (`kanit/faz-3/lab-02-b-ekip01.txt`, 17 denetim).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 02-b NN` |
| Denetle | `make dogrula-lab LAB=02-b EKIP=NN` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-02a` / `LAB=lab-02b` |

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–5 | 1 · `release/1.0.0` | |
| 5–20 | 2 · CHANGELOG, MR → `main` | MR'ın hedefi `main` mi? Squash kapalı mı? |
| 20–30 | 3 · Korumalı tag, `v1.0.0` | Developer'ın push'u reddedildi mi? |
| 30–35 | 4 · Release → `develop` | **40. dk: herkesin `v1.0.0` tag'ini görün** |
| 40–60 | 5 · `hotfix/1.0.1` | Test önce kırmızı mı? |
| 60–65 | 6 · MR → `main`, `v1.0.1` | |
| 65–70 | 7 · Hotfix → `develop`, grafik | Grafiği şemayla yan yana okuyun |
| 70–80 | Toparlama | Tags ve Merged MR sayfaları |

Lab öncesi GitFlow şemasını ("Hotfix akışı" slaytı) adım adım birlikte okuyun.

## Çözüm

### Adım 1–2

```bash
git switch develop && git pull
git switch -c release/1.0.0
```

`CHANGELOG.md` (tarih: eğitim günü):

```markdown
## [Unreleased]

## [1.0.0] - 2026-11-03

### Added

- catalog: stok durumu alanı (#1)
- catalog: SRJ-04 şarj ünitesi
```

```bash
git add CHANGELOG.md && git commit -m "chore(release): 1.0.0"
git push -u origin release/1.0.0
```

MR 1: `release/1.0.0` → `main`, başlık `chore(release): 1.0.0`, squash kapalı, kaynak branch silinmez. Lider merge eder.

### Adım 3

Settings > Repository > Protected tags: `v*`, *Allowed to create* Maintainers (API: `protected_tags name=v* create_access_level=40`).

```bash
# lider
git switch main && git pull
git tag -a v1.0.0 -m "release: v1.0.0"
git push origin v1.0.0
```

### Adım 4

MR 2: `release/1.0.0` → `develop`, squash kapalı, kaynak branch silinir.

### Adım 5

```bash
git fetch --tags origin
git switch -c hotfix/1.0.1 v1.0.0
```

Önce test, `tests/order-service.tests/OrdersApiTests.cs`:

```csharp
[Theory]
[InlineData("")]
[InlineData("   ")]
public async Task Post_order_without_a_product_id_returns_400(string productId)
{
    var response = await _client.PostAsJsonAsync(
        "/api/orders", new CreateOrderRequest { ProductId = productId, Quantity = 1 });

    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    Assert.Contains("Ekipman kodu", await response.Content.ReadAsStringAsync());
}
```

Bu haliyle `dotnet test tests/order-service.tests` → `Failed: 2, Passed: 4` (`Expected: BadRequest`, `Actual: Created`).

Düzeltme, `src/order-service/Endpoints/OrderEndpoints.cs`, `CreateAsync`'in başı:

```csharp
if (string.IsNullOrWhiteSpace(request.ProductId))
{
    return Results.BadRequest(new { error = "Ekipman kodu boş olamaz." });
}
```

Arayüz yanıttaki `error` alanını gösterir (`src/web-ui/src/api.js`).

```bash
dotnet test SahaPortal.sln
git add src tests && git commit -m "fix(order): reject empty product id"
```

`CHANGELOG.md` içine, `1.0.0` bölümünün üstüne:

```markdown
## [1.0.1] - 2026-11-03

### Fixed

- order: boş ekipman koduyla talep açılamaz (#2)
```

```bash
git add CHANGELOG.md && git commit -m "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
```

### Adım 6–7

MR 3: `hotfix/1.0.1` → `main`, başlık `fix(order): reject empty product id`, `Closes #2`, squash kapalı, kaynak branch silinmez. Lider merge eder ve `v1.0.1` tag'ini atar.

MR 4: `hotfix/1.0.1` → `develop`, `Closes #2`, squash kapalı, kaynak branch silinir.

```bash
git fetch --prune --tags origin
git log --oneline --graph origin/main origin/develop
git branch -r --contains "$(git log --no-merges --format=%H --grep='^fix(order)' -n 1 origin/main)"
#   origin/develop
#   origin/main
```

Tam dosyalar: `checkpoint/lab-02b` (`develop`) ve `checkpoint/lab-02b-main` (`main`; `v1.0.1` bu commit, `v1.0.0` onun ilk ebeveyni).

## Doğrulanan olumsuz durumlar

| Deneme | Sonuç |
|---|---|
| Developer `v1.0.0` tag'ini push ediyor | `remote: GitLab: You are not allowed to create this tag as it is protected.` |
| Hotfix testi, düzeltmeden önce | 2 test kırmızı (`Expected: BadRequest`, `Actual: Created`) |
| `v1.0.0` kodunda `POST /api/orders` `{"productId":""}` | `201` (hata sürümde duruyor) |
| `v1.0.1` kodunda aynı istek | `400`; geçerli talep `201` |
| Hotfix `main`'e merge edildikten sonra issue `#2` | Açık kalır; `develop`'a merge edilince kapanır (ölçülen: iki merge arasında 10 sn) |

## Sık takılınan yerler

- **MR'ın hedefi.** Yeni MR formu hedef olarak varsayılan branch'i (`develop`) getirir. Release ve hotfix MR'larında `main`'e çevirmeyi unutan çok olur. MR açıldıktan sonra **Edit** ile değiştirilebilir.
- **"Delete source branch" varsayılan olarak işaretlidir.** MR 1 ve 3'te kaldırılmazsa branch silinir; yerel kopyadan yeniden push edilir.
- **Issue hotfix `main`'e girince kapanmaz.** GitLab issue'yu yalnızca varsayılan branch'e merge'de kapatır. Bunu Adım 7'nin tartışma sorusu olarak kullanın: "hotfix `develop`'a ulaşmadan iş bitmiş sayılmaz".
- **`git branch -r --contains` komutunda `--no-merges` şart:** GitLab merge commit'inin mesajına MR başlığını da yazar; `--grep` merge commit'ini bulursa yalnızca `origin/main` görünür.
- **CHANGELOG'daki issue numaraları** ekipten ekibe değişebilir (`#1`, `#2` yerine başka sayılar). Checkpoint `#1` ve `#2` kullanır.
- **Squash soran olursa:** proje ayarı "Allow"; kutu MR başına işaretlenir. Release ve hotfix'te işaretlenmez.
- **Tag yanlış commit'te.** Eğitimde tag silinip yeniden atılır (**Code > Tags**); korumalı tag'i kimin silebildiği sandbox'ta denenmedi, gerekirse `make checkpoint` kullanın. Gerçek hayatta tag taşınmaz, yeni PATCH sürümü çıkarılır.

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| Lab başında `develop`'ta stok durumu yok | `make checkpoint EKIP=NN LAB=lab-02a` |
| 30. dk: release MR'ı hâlâ merge edilmedi | Eğitmen lider olarak merge eder; ekip tag adımına geçer |
| 45. dk: `v1.0.0` yok | Birlikte atın. Hotfix yarısı için süre kalmayacaksa: `make checkpoint EKIP=NN LAB=lab-02b`, ekip grafiği ve `git branch -r --contains` komutunu çalıştırıp okur |
| 65. dk: hotfix kodu bitmedi | `git checkout sablon/checkpoint/lab-02b -- src/order-service tests/order-service.tests CHANGELOG.md`; MR'ları kendileri açsın |
| 75. dk: `v1.0.1` yok | `make checkpoint EKIP=NN LAB=lab-02b` (= `checkpoint/gun2`). Yarının ön koşulu `main` üzerindeki `v1.0.1` |

`checkpoint/lab-02b` uygulanınca `main`, `develop`, iki annotated tag, `v*` koruması ve kapalı `#1`, `#2` issue'ları hazır gelir; release ve hotfix branch'leri ile MR geçmişi gelmez.
