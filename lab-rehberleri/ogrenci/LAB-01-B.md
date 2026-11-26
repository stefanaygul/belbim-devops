# LAB 01-B · Feature branch, conflict ve commit

| | |
|---|---|
| **Gün / modül** | Gün 1 · Modül 4 |
| **Süre** | 80 dk (son 10 dk toparlama ve kontrol) |
| **Başlangıç durumu** | LAB 01-A tamamlandı: `~/saha-ekipman-portal` klonlu, `main` üzerinde build ve testler yeşil |
| **Takılırsan** | `git status` bir sonraki adımı söyler; `git merge --abort` ile başa dönülür. Çözülmüş hal: `checkpoint/gun1` (bkz. bölüm 9) |

**Öğrenme kazanımı:** Küçük bir değişikliği feature branch'inde yapıp Conventional Commits biçiminde commit edebilir, bir merge conflict'i okuyup çözebilir ve sonucu `git log` ile gösterebilirsiniz.

İkili çalışın: biri klavyede, diğeri yönlendirsin. Yarı sürede (Adım 4'ten sonra) yer değiştirin.

## 1. Amaç

Kataloğa yeni bir ekipman eklemek ve bu değişikliği baştan sona Git ile yönetmek: branch, commit, başka birinin değişikliğiyle çakışma, çözüm, okunur bir geçmiş.

## 2. Ön koşullar

- LAB 01-A tamam: `cd ~/saha-ekipman-portal && git status` temiz, `main` üzerindesiniz.
- Git kimliğiniz tanımlı: `git config user.name` bir ad yazmalı.
- Çalışan uygulamaları durdurdunuz (`Ctrl+C`).

## 3. Kullanılacak sistemler

| Sistem | Ne için |
|---|---|
| Eğitim makinesi (terminal, editör) | Bütün iş lokalde |
| İç GitLab | Yalnızca hazır `lab/01b-rename` branch'inin kaynağı; bugün push yok |

## 4. Adımlar

### Adım 1 · `feature/katalog-sarj-unitesi` branch'ini aç (5 dk)

```bash
cd ~/saha-ekipman-portal
git switch main
git switch -c feature/katalog-sarj-unitesi
git status
```

### Adım 2 · Kataloğa `SRJ-04` "Şarj ünitesi" kaydını ekle (10 dk)

`src/product-service/Data/catalog.json` dosyasını açın ve listenin sonuna yeni kaydı ekleyin:

| Alan | Değer |
|---|---|
| `code` | `SRJ-04` |
| `name` | `Şarj ünitesi` |

Dosya geçerli JSON kalmalı: bir önceki satırın sonuna virgül gerekir. Adı tam olarak tablodaki gibi yazın; Adım 5 buna bağlı.

```bash
git status
git diff
```

### Adım 3 · İlgili testi güncelle, `dotnet test` ile doğrula (15 dk)

Önce testleri değiştirmeden çalıştırın:

```bash
dotnet test SahaPortal.sln
```

Bir test kırmızıya döner. Hangisi ve neden? `tests/product-service.tests/CatalogStoreTests.cs` dosyasında beklenen ekipman kodları listesini yeni kayda göre güncelleyin, sonra testleri yeniden çalıştırın. Hepsi yeşil olmalı.

> Test "kırıldı" diye yanlış değildi; katalog değişti ve test bu değişikliği yakaladı. Testi, davranışın yeni halini tarif edecek şekilde bilinçli olarak güncelliyorsunuz.

### Adım 4 · Conventional Commits biçiminde commit at (10 dk)

Biçim: `tür(kapsam): emir kipinde kısa özet`. Bu değişiklik yeni bir özellik ve kataloğu ilgilendiriyor.

```bash
git add src/product-service tests/product-service.tests
git status
git commit -m "feat(catalog): add charging unit"
git log --oneline -n 3
```

`git add .` yerine klasör verdik: yanlışlıkla eklenen dosyaları önler.

**Yer değiştirin:** klavyeye diğer eş geçsin.

### Adım 5 · `lab/01b-rename` branch'ini merge et, conflict'i çöz (20 dk)

Bir ekip arkadaşınız aynı ekipmanı başka bir adla eklemiş. Değişikliği kendi branch'inize alın:

```bash
git merge origin/lab/01b-rename
```

Git birleştiremeyecek ve duracak. Panik yok:

```bash
git status
cat src/product-service/Data/catalog.json
```

Dosyadaki işaretleri okuyun:

- `<<<<<<< HEAD` ile `=======` arası: **sizin** branch'inizdeki hal.
- `=======` ile `>>>>>>> origin/lab/01b-rename` arası: **gelen** değişiklik.

Karar: ekipmanın adı "Şarj ünitesi" kalacak. Dosyayı düzenleyin: doğru satırı bırakın, üç işaret satırını ve diğer satırı silin. Dosyada işaret kalmadığını denetleyin:

```bash
grep -n '<<<<<<<\|=======\|>>>>>>>' src/product-service/Data/catalog.json    # çıktı vermemeli
```

### Adım 6 · Testleri yeniden çalıştır, merge'ü tamamla (10 dk)

```bash
git add src/product-service/Data/catalog.json
dotnet test SahaPortal.sln
git commit --no-edit
```

Önce test, sonra commit: metin çakışması çözülmüş olsa bile iki doğru değişiklik birlikte yanlış olabilir.

### Adım 7 · `git log --oneline --graph` ile geçmişi göster

```bash
git log --oneline --graph
git log --oneline --graph main feature/katalog-sarj-unitesi origin/lab/01b-rename
```

Grafikte üç şeyi gösterin: sizin commit'iniz, gelen commit, ikisini birleştiren merge commit'i.

> `--all` da kullanabilirsiniz; ama klonladığınız repoda `checkpoint/*` branch'leri de bulunduğu için grafik kalabalıklaşır.

### Toparlama (10 dk)

İsterseniz uygulamayı yeniden başlatıp (LAB 01-A, Adım 7) yeni ekipmanı tarayıcıda görün. Bölüm 6'yı işaretleyin, bölüm 8'i yanıtlayın.

## 5. Beklenen çıktı

Adım 3, testi güncellemeden önce (kısaltılmış):

```
Failed SahaPortal.ProductService.Tests.CatalogStoreTests.Catalog_contains_the_expected_product_codes
Failed!  - Failed:     1, Passed:     4, Skipped:     0, Total:     5 - product-service.tests.dll (net10.0)
```

Adım 5:

```
$ git merge origin/lab/01b-rename
Auto-merging src/product-service/Data/catalog.json
CONFLICT (content): Merge conflict in src/product-service/Data/catalog.json
Automatic merge failed; fix conflicts and then commit the result.
```

```
<<<<<<< HEAD
  { "code": "SRJ-04", "name": "Şarj ünitesi" }
=======
  { "code": "SRJ-04", "name": "Hızlı şarj" }
>>>>>>> origin/lab/01b-rename
```

Adım 7 (commit kimlikleri sizde farklıdır):

```
*   8e9c753 Merge remote-tracking branch 'origin/lab/01b-rename' into feature/katalog-sarj-unitesi
|\
| * 756affb feat(catalog): add fast charger
* | 754b0e1 feat(catalog): add charging unit
|/
* 174fe06 chore: starter project
```

## 6. Başarı kriterleri

- [ ] `feature/katalog-sarj-unitesi` branch'indesiniz; `git status` temiz.
- [ ] Katalogda `SRJ-04` "Şarj ünitesi" kaydı var, bir kez.
- [ ] Dosyalarda conflict işareti kalmadı.
- [ ] `dotnet test` yeşil.
- [ ] `git log --oneline --graph` çıktısında anlamlı mesajlı commit'iniz ve merge commit'i görünüyor.

## 7. Yaygın hatalar ve ipuçları

| Belirti | Olası neden | Ne yapmalı |
|---|---|---|
| Merge'de conflict çıkmadı | Kaydı listenin sonuna değil başka bir yere eklediniz ya da commit etmediniz | `git merge --abort` gerekmez; `git log` ile durumu görün. Kaydı görevdeki yere ve adla ekleyip commit edin, sonra yeniden merge edin |
| Çözümden sonra testler `JsonException` ile kırılıyor | İşaret satırlarından biri ya da fazladan virgül dosyada kaldı | Adım 5'teki `grep`; dosyayı bir JSON olarak gözle kontrol edin |
| `error: Committing is not possible because you have unmerged files` | Dosyayı düzelttiniz ama `git add` yapmadınız | `git add <dosya>` çözümü "tamam" diye işaretler |
| İşler karıştı, baştan başlamak istiyorum | — | `git merge --abort` merge'ün başladığı ana döner |
| Merge commit mesajı için editör açıldı | `--no-edit` yazılmadı | Mesajı olduğu gibi kaydedip çıkın (`nano`: `Ctrl+O`, `Enter`, `Ctrl+X`) |
| Commit'i yanlış mesajla attım | — | Henüz paylaşmadınız: `git commit --amend -m "doğru mesaj"` |

## 8. Kendini kontrol soruları

1. Conflict çözüldükten sonra testleri neden yeniden çalıştırdık? Metin düzgünken neyin bozuk olabileceğine bir örnek verin.
2. Conflict işaretlerinde `HEAD` hangi tarafı gösterir? `git merge` yerine `git rebase` yapsaydınız taraflar nasıl değişirdi?
3. `feat(catalog): add charging unit` mesajındaki `feat` yarın sürüm numarasını nasıl etkileyecek?

## 9. Başlangıç durumuna dönme

**Laba baştan başlamak** (LAB 01-A'nın sonuna dönüş):

```bash
cd ~/saha-ekipman-portal
git merge --abort 2>/dev/null
git switch main
git branch -D feature/katalog-sarj-unitesi
```

**Takıldıysanız (`checkpoint/gun1`):** bu branch labın tamamlanmış halidir; yarın bu durumdan devam edilir.

```bash
git merge --abort 2>/dev/null
git switch -C feature/katalog-sarj-unitesi origin/checkpoint/gun1
dotnet test SahaPortal.sln
git log --oneline --graph -n 5
```
