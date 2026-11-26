# Faz 6 kanıtları — 24 Kasım 2026

Ana sonuç ve sınırlar: [RAPOR §19](../../RAPOR.md#19-faz-6-temiz-kurulum-uçtan-uca-prova-ve-eğitim-teslimi).

- **Son temiz kurulum:** [temiz-prova-son/sonuclar.tsv](temiz-prova-son/sonuclar.tsv) — on lab kesintisiz, 285/285. Aynı dizinde her labın akış ve denetim logu; boş volume, açılış ve bootstrap kayıtları. [182 arayüz görüntüsü](img/).
- **Checkpoint ve sıfırlama:** [final 41/41](checkpoint-final-ekip02-dogrula.log), [yerel kaynakların önceki durumu](sifirla-ekip02-yerel-oncesi.log), [sıfırlama](sifirla-ekip02.log), [sonuç 8/8](sifirla-ekip02-dogrula.log), [ekip-99 değişmedi](ekip99-yalitim.diff). Boş diff başarıdır; karşılaştırılan dökümler `ekip99-kurtarma-oncesi/sonrasi.txt`.
- **Ek hatalar:** [13/13](ek-hatalar.log), [Nexus yeni sürüm](nexus-yeni-surum.log), [webhook reddi ve düzeltme](ci-hata-demolari-son.log), [QG timeout](qg-timeout.log) → [QG başarı](qg-duzeltildi.log), [scanner yanlış sıra](scanner-yanlis-sira.log). Bu kayıtlar ilk tamamlanan akıştan sonradır; son temiz kurulumdan sonra tekrar koşuldukları iddia edilmez.
- **Doğrulayıcı:** [webhook geçmişi için üç regresyon](webhook-denetimi-regresyon.log), [sözdizimi, bağlantı ve sır taraması](statik-kontroller.log).
- **Kurum ön kontrolü:** [sandbox 28/28](onkontrol-sandbox.log); kurum erişimi doğrulanmış sayılmaz.
- **Önceki denemeler:** `temiz-prova-ilk-deneme/` Jenkins ilk açılış hatası; `temiz-prova/` Nexus adımında durup devam eden ilk tam akış; `kurtarma-ilk/` ortak Docker girişi hatasını bulan ilk checkpoint/sıfırlama koşusu. `sifirla-ekip02-yerel-ilk-beklenti.log`, doğrulayıcının hatalı beklentisini gösterir; düzeltilmiş beklentinin gerçek çıktısı ayrı tutulur.

Komutlar/süreler otomasyon içindir; katılımcıyla süre ölçümü değildir. Bilinen sırlar metin çıktılarında taranır; hassas arayüz formlarında maskeleme kullanılır. Servis volume'ları silindi; CA, `.env` ve host imaj cache'i korundu.

Son ortam: [çekirdek 107/107](cekirdek-son.log), [CI 64/64](ci-son.log), [ekip-01 37/37](katilimci01-onkontrol.log), [ekip-02 37/37](katilimci02-onkontrol.log). Ekip sıfırlamasından sonra [ekip-99 tag job’ı başarılı](docker-giris-yalitimi.log), [final 49/49](lab-05-b-son.log). [Servisler](container-son-durum.log), [Jenkins kuyruğu](jenkins-son-durum.log), [ders başlangıç ayarı](ders-baslangici.log).
