# LAB 02-A · Çözüm ve eğitmen notları

Proje, koruma ve Merge Request · 80 dk · Gün 2, Modül 2 · öğrenci rehberi: [`../ogrenci/LAB-02-A.md`](../ogrenci/LAB-02-A.md)

**Durum:** `SANDBOX_VERIFIED`: ekip-01 ile, arayüz adımları gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-3/lab-02-a-ekip01.txt`, 23 denetim); ekip-02 ile tek seferde yeniden koşuldu (`30-tek-seferde-ekip02.txt`).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula (arayüz adımları tarayıcıda) | `bash dogrula/cozum.sh 02-a NN` |
| Denetle | `make dogrula-lab LAB=02-a EKIP=NN` |
| Ekibin rollerini değiştir / geri al | `make rol-degistir EKIP=NN` / `make rol-degistir EKIP=NN ASIL=1` |
| Ekibi bu labın sonuna getir | `make checkpoint EKIP=NN LAB=lab-02a` |
| Hesap parolaları | `make parolalar` |

## Lab öncesi

- Eşleri ve rolleri belirleyin: kim `ekipNN-lead` (Maintainer), kim `ekipNN-dev` (Developer).
- Herkesin GitLab'e girebildiğini ve SSH anahtarının profilinde olduğunu görün (`ssh -T git@$GITLAB_HOST`).
- Dünü bitiremeyen ekip: `make checkpoint EKIP=NN LAB=gun1`.
- Demoda yalnızca projenin oluşturulmasını ve ilk push'u gösterin; koruma ayarlarını katılımcılar yapsın.

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Kim | Ara kontrol |
|---|---|---|---|
| 0–15 | 1 · `main`'e al, şablon, proje, push | lider | **15. dk:** her ekibin projesi GitLab'de |
| 15–30 | 2 · `develop`, varsayılan branch, koruma | lider | Doğrudan push reddedildi mi? |
| 30–35 | 3 · Issue, branch | yazar | |
| 35–50 | 4 · Kod ve test | yazar | `dotnet test` yeşil |
| 50–55 | 5 · MR | yazar | Şablon kendiliğinden geldi mi? |
| 55–65 | 6 · Review, düzeltme, thread | ikisi | Açık thread merge'ü engelledi mi? |
| 65–70 | 7 · Merge | lider | Branch silindi, issue kapandı |
| 70–80 | Toparlama (ya da rol değişimi) | | |

Rol değişimi 80 dakikaya çoğu ekipte sığmaz; hızlı ekiplere verin.

## Çözüm

### Adım 1

```bash
git switch main
git merge --no-ff feature/katalog-sarj-unitesi -m "Merge branch 'feature/katalog-sarj-unitesi'"
```

`.gitlab/merge_request_templates/Default.md`:

```markdown
## Ne değişti, neden?

## Nasıl test edildi?

- [ ] Unit testler eklendi ya da güncellendi

Closes #
```

`.gitlab/CODEOWNERS` (ekip-01 için):

```
[Backend]
/src/product-service/   @egitim/ekip-01
/src/order-service/     @egitim/ekip-01

[Frontend]
/src/web-ui/            @egitim/ekip-01

[Pipeline]
Jenkinsfile             @ekip01-lead
```

```bash
git add .gitlab && git commit -m "chore: add merge request template and CODEOWNERS"
# GitLab: ekip grubu > Create project > Create blank project; README işaretsiz
git remote rename origin sablon
git remote add origin "git@$GITLAB_HOST:$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal.git"
git push -u origin main
```

### Adım 2

```bash
git switch -c develop && git push -u origin develop
```

Settings > Repository > Branch defaults: `develop`. Protected branches: `main` ve `develop` için *Allowed to merge* **Maintainers**, *Allowed to push and merge* **No one**. Settings > Merge requests: **All threads must be resolved**.

API ile aynı durum (denetim ve otomasyon için):

```
default_branch=develop
protected_branches: main, develop -> push_access_level=0, merge_access_level=40, allow_force_push=false
only_allow_merge_if_all_discussions_are_resolved=true, merge_method=merge, squash_option=default_off
```

### Adım 4

`src/common-contracts/ProductDto.cs`:

```csharp
public sealed record ProductDto(string Code, string Name, bool InStock);
```

`src/product-service/Data/catalog.json`:

```json
[
  { "code": "ADP-01", "name": "Terminal adaptörü", "inStock": true },
  { "code": "KBL-02", "name": "Bağlantı kablosu", "inStock": true },
  { "code": "STD-03", "name": "Cihaz standı", "inStock": false },
  { "code": "SRJ-04", "name": "Şarj ünitesi", "inStock": true }
]
```

`tests/product-service.tests/CatalogStoreTests.cs` içine iki test (dosyanın başına `using System.Text.Json;`):

```csharp
[Fact]
public void Catalog_file_states_the_stock_status_of_every_product()
{
    using var document = JsonDocument.Parse(File.ReadAllText(CatalogStore.DefaultPath));

    // A missing field would silently be read as "not in stock".
    Assert.All(document.RootElement.EnumerateArray().ToArray(), item =>
    {
        var kind = item.GetProperty("inStock").ValueKind;
        Assert.True(kind is JsonValueKind.True or JsonValueKind.False);
    });
}

[Fact]
public void Catalog_reads_the_stock_status()
{
    var catalog = CatalogStore.FromFile(CatalogStore.DefaultPath);

    Assert.True(catalog.GetAll().Single(p => p.Code == "ADP-01").InStock);
}
```

Commit: `feat(catalog): add stock status`.

### Adım 6 · Review ve düzeltme

Örnek reviewer yorumu (`ProductDto.cs` satırında): *"API testi bu alanı doğrulamıyor. `ProductsApiTests` içinde `inStock` değerini ve stokta olmayan bir ekipmanı da denetleyelim mi?"*

Düzeltme, `tests/product-service.tests/ProductsApiTests.cs`:

```csharp
Assert.Contains(products, p => p is { Code: "ADP-01", Name: "Terminal adaptörü", InStock: true });
```

```csharp
[Fact]
public async Task Get_products_reports_items_that_are_out_of_stock()
{
    var json = await _client.GetStringAsync("/api/products");
    var products = await _client.GetFromJsonAsync<List<ProductDto>>("/api/products");

    Assert.Contains("\"inStock\":false", json);
    Assert.NotNull(products);
    Assert.Contains(products, p => p is { Code: "STD-03", InStock: false });
}
```

Commit: `test(catalog): cover stock status in the products API`. Yazar thread'i çözer, lider merge eder (squash açık, kaynak branch silinir).

### Rol değişimi (ikinci MR)

`make rol-degistir EKIP=NN` çalıştırın: `ekipNN-lead` Developer, `ekipNN-dev` Maintainer olur. Betik yalnızca `egitim/ekip-NN` grubundaki iki üyeliği değiştirir.

`src/web-ui/src/components/CatalogList.jsx`: başlığa `<th>Stok</th>`, satıra `<td>{product.inStock ? 'Stokta' : 'Stokta yok'}</td>`. `CatalogList.test.jsx`: `inStock` alanlı iki ürünle "Stokta" / "Stokta yok" metinlerini denetleyen bir test. Commit ve MR başlığı: `feat(web-ui): show stock status`.

İş bitince **mutlaka** geri alın: `make rol-degistir EKIP=NN ASIL=1`. Sonraki lablar asıl rollere göre yazılmıştır.

Tam dosyalar: şablon projede `checkpoint/lab-02a` (bu labın sonundaki `develop`) ve `checkpoint/lab-02a-main` (`main`).

## Doğrulanan olumsuz durumlar

| Deneme | Sonuç |
|---|---|
| Developer ve Maintainer, `main` ve `develop`'a doğrudan push | `remote: GitLab: You are not allowed to push code to protected branches on this project.` (dört denemenin dördü) |
| Açık thread varken Maintainer'ın MR ekranı | `Merge blocked: 1 check failed` — `Open threads must be resolved.`; "Merge" yerine "Set to auto-merge" |
| Developer'ın MR ekranı | `Ready to merge by members who can write to the target branch.`; Merge düğmesi yok |
| Developer'ın API ile merge denemesi | `HTTP 401 Unauthorized`, `user.can_merge=false` |
| Rol değişiminden sonra `ekipNN-lead` (artık Developer) | Merge düğmesi yok |

## Sık takılınan yerler

- **Issue numarası.** Slaytlar `#3`, `!5` der; GitLab'de issue ve MR sayaçları ayrıdır ve 1'den başlar. İlk issue `#1`, ilk MR `!1` olur. Branch adı slayttaki gibi `feature/3-stok-durumu` kalır; MR'da gerçek numara yazılır. (`slayt-guncellemeleri.md`)
- **Varsayılan branch `develop` yapılmazsa** iki şey sessizce çalışmaz: MR şablonu varsayılan branch'ten okunur ve `Closes #N` yalnızca varsayılan branch'e merge'de issue'yu kapatır. Slayttaki LAB adımlarında bu ayar geçmez; rehbere eklenmiştir.
- **`main` zaten korumalı görünür.** GitLab ilk push'ta varsayılan branch'i "Maintainers / Maintainers" olarak korur. Katılımcı yalnızca push iznini "No one" yapar.
- **Proje README ile oluşturulursa** ilk push'un reddedilmesi beklenir (geçmişler farklı); sandbox'ta denenmedi. Projeyi silip README'siz yeniden oluşturmak en hızlısıdır.
- **Squash sonrası `git branch -d`** "not fully merged" der. `-D` gerekir; nedenini anlatın (commit'ler `develop`'ta yeni bir kimlikle duruyor).
- **"Approve" düğmesi vardır** ama eksik onay merge'ü engellemez ("Approval is optional").
- **Yeni diff arayüzü:** satıra yorum düğmesi satırın üzerine gelince, satır numarasının solunda belirir.
- **Sandbox'ta iki rol tek makinede:** `rol lead` / `rol dev`. Unutulursa push yanlış hesapla gider; `ssh -T git@$GITLAB_HOST` hangi hesabın kullanıldığını söyler.

## Onay kuralları ve Code Owners

Slayt G2/11 ve G2/12, zorunlu onay ve Code Owners özelliklerini lisans karşılaştırmasıyla anlatır. Bu özellikler GitLab'in ücretli katmanlarındadır; lab onları **kullanmaz ve göstermez** (karar: 2026-11-24). Anlatımda slayt yeterlidir. Labdaki karşılığı: push kapalı ve merge yalnızca Maintainer'da olduğu için her değişiklik ikinci bir kişiden geçer; kanıtı MR'daki yazar ve "merged by" kaydıdır. `.gitlab/CODEOWNERS` dosyası repoya eklenir (slayttaki gibi) ama bu katmanda GitLab onu değerlendirmez.

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| Lab başında dünkü iş yok | `make checkpoint EKIP=NN LAB=gun1` |
| 20. dk: proje hâlâ yok ya da push olmadı | Birlikte yapın (demo ekranında). 30. dakikayı geçerse `make checkpoint EKIP=NN LAB=lab-02a` ve ekip Adım 3'ten **ikinci** bir küçük değişiklikle (rol değişimi görevi) devam etsin |
| 45. dk: koruma tamam, kod bitmedi | Kodu `checkpoint/lab-02a`'dan alsınlar: `git checkout sablon/checkpoint/lab-02a -- src tests`; MR ve review adımlarını kendileri yapsın |
| 65. dk: MR açık, review bitmedi | Eğitmen reviewer olur: tek yorum, tek düzeltme, merge |
| 75. dk: hâlâ MR yok | `make checkpoint EKIP=NN LAB=lab-02a`. MR deneyimini LAB 02-B'de dört kez yaşayacaklar |

`checkpoint/lab-02a` uygulanınca: proje, `develop` varsayılan, korumalar, MR ayarı ve kapalı `#1` issue'su hazır gelir; MR ve yorum geçmişi gelmez; ekibin eski çalışma kopyası `~/yedek/` altına taşınır.
