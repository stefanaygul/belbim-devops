# Eğitim öncesi kontrol listesi

Eğitim: **25 Kasım 2026**, Europe/Istanbul. Sandbox kanıtları [Faz 6](../kanit/faz-6/) altında; kurum doğrulaması ayrı yapılır.

## Ders başlamadan

- [ ] [Yönetici listesi](belbim-yoneticisinden-istenecekler.md) tamamlandı; katılımcılara doldurulmuş `lab.env`, CA, hesaplar ve SSH erişimi verildi.
- [ ] Eğitmen ve katılımcı ağından GitLab, Jenkins, SonarQube, Nexus arayüzleri güvenilir HTTPS ile açılıyor. Sandbox host tarayıcısı için [hosts ve CA adımları](../lab-ortami/README.md) uygulandı; `--resolve` ile curl başarısı tek başına tarayıcı DNS'i kanıtlamaz.
- [ ] Starter repo klonlanıyor; SDK/Node sürümleri ve NuGet/npm kaynakları doğru. Temel Docker imajları katılımcı makinesinde yüklü.
- [ ] Her ekibin numarası, lider/yazar hesabı, test portu ve proje yolu [ortam kartında](ortam-karti.md) belli; token'lar ortak ekrana yansıtılmıyor.
- [ ] Ekiplerin başlangıç durumu LAB 01-A'ya uygun: kişisel çalışma kopyası/ekip projesi önceden çözülmüş değil. Prova ekibi 99 katılımcılara verilmez.
- [ ] Jenkins agent online; `dotnet-docker`; test VM sunucu anahtarı tanıtılmış. SonarQube webhook'u doğru ve son `/` mevcut.
- [ ] Rehberler, `komutlar.md`, çözüm dosyaları ve checkpoint erişimi internet kesilse de elde.
- [ ] Ekran paylaşımıyla bir katalog/talep işlemi denenmiş; projeksiyon ve katılımcı bilgisayarları hazır.

Sandbox host'ta `lab-ortami/` içinden:

```bash
/usr/bin/make durum
/usr/bin/make dogrula
/usr/bin/make dogrula-ci
/usr/bin/make onkontrol EKIP=01
/usr/bin/make onkontrol EKIP=02
```

Kurumda servis kuran `make up/bootstrap/checkpoint` komutlarını kullanmayın. Ortam dosyası ile [salt okunur ön kontrol](../lab-ortami/dogrula/onkontrol.sh) ve yönetici listesi uygulanır.

## Günlük ara kontroller

| Gün | Gün sonunda aranacak sonuç | Kurtarma checkpoint'i |
|---|---|---|
| 1 | Build/test yeşil, NU1605 çözülmüş, katalog conflict'i çözülmüş | `gun1` |
| 2 | Korunan main/develop, MR incelemesi, v1.0.0/v1.0.1, hotfix iki branch'te | `lab-02b` |
| 3 | Registry imajları, test VM, root olmayan kullanıcı ve kalıcı talep verisi | `lab-03b` |
| 4 | Kırmızı pipeline merge'ü engelliyor; Quality Gate kırmızı→yeşil, SHA imajları | `lab-04b` |
| 5 | Nexus paketi, 409 reddi, quantity 0→400 / 2→201, SemVer digest eşitliği, rollback kaydı | `final` |

Checkpoint uygulamak öğrenci adımlarının yerine kanıt sayılmaz. Bir lab takılırsa ilgili eğitmen çözümündeki süre/kurtarma tablosunu kullanın; tek sorunun bütün günü tüketmesine izin vermeyin. Katılımcıyla süre ölçümü ve x86-64 doğrulaması sandbox arm64 provasından çıkarılamaz.
