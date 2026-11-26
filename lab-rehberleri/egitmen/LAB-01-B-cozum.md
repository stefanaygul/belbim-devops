# LAB 01-B · Çözüm ve eğitmen notları

Feature branch, conflict ve commit · 80 dk · Gün 1, Modül 4 · öğrenci rehberi: [`../ogrenci/LAB-01-B.md`](../ogrenci/LAB-01-B.md)

**Durum:** `SANDBOX_VERIFIED`. İki ekiple koşuldu; kanıt: `kanit/faz-3/lab-01-b-ekip01.txt`, `lab-01-b-ekip02.txt`.

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 01-b NN` |
| Denetle | `make dogrula-lab LAB=01-b EKIP=NN` |
| Ekibi bu labın sonuna getir | `make checkpoint EKIP=NN LAB=gun1` |

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–5 | 1 · Branch | |
| 5–15 | 2 · Katalog | JSON geçerli mi (virgül)? |
| 15–30 | 3 · Test | Önce kırmızı, sonra yeşil gördüler mi? |
| 30–40 | 4 · Commit | **40. dk:** herkesin bir commit'i var; eşler yer değiştirir |
| 40–60 | 5 · Merge, conflict | Conflict çıkmayan ekip var mı? |
| 60–70 | 6–7 · Test, commit, log | Grafikte merge commit'i |
| 70–80 | Toparlama | En sık yapılan hatayı ekranda çözün |

## Çözüm

### Adım 2 · `src/product-service/Data/catalog.json`

```json
[
  { "code": "ADP-01", "name": "Terminal adaptörü" },
  { "code": "KBL-02", "name": "Bağlantı kablosu" },
  { "code": "STD-03", "name": "Cihaz standı" },
  { "code": "SRJ-04", "name": "Şarj ünitesi" }
]
```

### Adım 3 · `tests/product-service.tests/CatalogStoreTests.cs`

Testi güncellemeden önce tam olarak bir test kırılır:

```
Failed SahaPortal.ProductService.Tests.CatalogStoreTests.Catalog_contains_the_expected_product_codes
   Assert.Equal() Failure: Collections differ
Expected: ["ADP-01", "KBL-02", "STD-03"]
Actual:   ["ADP-01", "KBL-02", "STD-03", "SRJ-04"]
```

Düzeltme tek satır:

```csharp
Assert.Equal(["ADP-01", "KBL-02", "STD-03", "SRJ-04"], codes);
```

### Adım 4

```bash
git add src/product-service tests/product-service.tests
git commit -m "feat(catalog): add charging unit"
```

### Adım 5–6 · Conflict

`lab/01b-rename` aynı yere `{ "code": "SRJ-04", "name": "Hızlı şarj" }` satırını ekler ve bir önceki satıra virgül koyar. Katılımcı da aynı iki satırı değiştirdiği için conflict kesindir. Çözülmüş dosya Adım 2'deki dosyanın aynısıdır.

```bash
git merge origin/lab/01b-rename          # CONFLICT (content)
# catalog.json: "Şarj ünitesi" satırı kalır, üç işaret satırı ve "Hızlı şarj" satırı silinir
git add src/product-service/Data/catalog.json
dotnet test SahaPortal.sln
git commit --no-edit
```

`lab/01b-rename` testi değiştirmez; bu yüzden "Hızlı şarj" seçilse bile testler geçer (test yalnızca kodları denetler). Tartışma fırsatı: testler adı denetlemiyor; hangisinin doğru olduğuna insan karar veriyor.

### Adım 7

```bash
git log --oneline --graph
```

## Sık takılınan yerler

- **Conflict çıkmadı.** Katılımcı kaydı listenin başına ya da ortasına eklemiştir, ya da commit etmeden merge etmiştir (o zaman git "local changes would be overwritten" der). Kaydı listenin sonuna, görevdeki adla ekletin.
- **İşaretlerden biri dosyada kaldı.** Test `JsonException` ile kırılır; bu iyi bir öğretme anıdır: "commit öncesi arat".
- **Editör açıldı (`git commit` mesajı).** `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`. `vim`: `:wq`.
- **`git log --graph --all` çok kalabalık.** Klonlanan repoda `checkpoint/*` branch'leri vardır. Rehber bu yüzden branch adlarını açıkça verir.
- **Merge commit mesajı** `Merge remote-tracking branch 'origin/lab/01b-rename' into feature/katalog-sarj-unitesi` olur; Conventional Commits biçiminde olması beklenmez.
- **Rebase soran olursa:** eğitimde merge; slayt "merge ile rebase farkı". İsteyen ekip lab sonunda ayrı bir branch'te `git rebase` deneyebilir.

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| 30. dk: test hâlâ kırmızı | Beklenen kodlar listesini birlikte güncelleyin |
| 60. dk: conflict çözülemedi | `git merge --abort`, birlikte yeniden merge edin; dosyayı ekranda çözün |
| 70. dk: hâlâ Adım 5'te | `git merge --abort; git switch -C feature/katalog-sarj-unitesi origin/checkpoint/gun1`; grafiği birlikte okuyun |
| Repo bozuldu | `make checkpoint EKIP=NN LAB=gun1` |

Gün sonunda her ekibin `feature/katalog-sarj-unitesi` branch'i `checkpoint/gun1` ile aynı içerikte olmalıdır; yarın LAB 02-A bu branch'i `main`'e alarak başlar.
