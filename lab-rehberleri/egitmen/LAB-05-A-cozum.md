# LAB 05-A · Çözüm ve eğitmen notları

Ortak paket Nexus'ta · 75 dk · Gün 5, Modül 1 · öğrenci rehberi: [`../ogrenci/LAB-05-A.md`](../ogrenci/LAB-05-A.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 ile; issue, Nexus API anahtarı, Nexus paket sayfası, MR ve merge gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-5/lab-05-a-ekip01.txt`, 19 denetim). ekip-02'de `checkpoint/lab-04b` durumundan tek seferde koşuldu (93 sn, 19 denetim). `checkpoint/lab-05a` ekip-02'ye uygulandı (18 denetim). Doğrulamanın olumsuz yönü: LAB 04-B durumundaki ekipte 11 denetim kalıyor. Bonus `Pack & Publish` ekip-02'de iki yönde denendi (aşağıda).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 05-a NN` |
| Denetle | `make dogrula-lab LAB=05-a EKIP=NN` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-04b` / `LAB=lab-05a` |
| Ekibin paketini Nexus'tan silmek (yeniden yayın için) | `docker compose run --rm -T araclar bash bootstrap/ekip-nexus.sh sil NN` |
| Ekibin Nexus API anahtarını yenilemek (sızıntıda) | `docker compose run --rm -T araclar bash bootstrap/ekip-nexus.sh anahtar-yenile NN` |

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–5 | 1 · PackageId, Version | Ekip soneki var mı? |
| 5–10 | 2 · `dotnet pack` | `.nupkg` içinde `lib/net10.0/common-contracts.dll` |
| 10–20 | 3 · API anahtarı, push | Herkesin paketi Nexus'ta |
| 20–25 | 4 · İkinci push | **Herkes 409'u gördü mü?** Mesajı birlikte okuyun |
| 25–40 | 5 · `PackageReference`, Dockerfile | `dotnet build` yeşil |
| 40–55 | 6 · Önbellek, restore, imaj | Restore çıktısında `nuget-group` adresi |
| 55–65 | 7 · MR, pipeline | `develop` yeşil |
| 65–75 | Toparlama | |

## Çözüm

`src/common-contracts/common-contracts.csproj`:

```xml
  <PropertyGroup>
    <PackageId>Saha.Common.Contracts.EkipNN</PackageId>
    <Version>1.0.0</Version>
    <Description>Saha Ekipman Talep Portalı: servisler arası sözleşmeler (DTO'lar).</Description>
  </PropertyGroup>
```

Servislerin `.csproj` dosyalarında `ProjectReference` yerine `<PackageReference Include="Saha.Common.Contracts.EkipNN" Version="1.0.0" />`; iki Dockerfile'dan `COPY src/common-contracts/ src/common-contracts/` satırı silinir. Tam hali: `checkpoint/lab-05a` (kaynak: `lab-ortami/checkpoint/adimlar/05a-paket/`).

```bash
dotnet pack src/common-contracts -c Release -o out
read -rs NEXUS_APIKEY
dotnet nuget push out/Saha.Common.Contracts.Ekip$EKIP.1.0.0.nupkg --source $NEXUS_URL/repository/nuget-hosted/ --api-key "$NEXUS_APIKEY"
dotnet nuget push ...    # 409
dotnet nuget locals all --clear && dotnet restore SahaPortal.sln -v n | grep -i saha.common
```

## Bu ortamda gözlenenler (slayttan farklı olanlar `slayt-guncellemeleri.md` içinde)

- **Aynı sürümün ikinci yayını `409 Conflict` döner**, slayttaki `400 (Bad Request)` değil: `409 (nuget-hosted/Saha.Common.Contracts.Ekip01/1.0.0 - cannot be updated as asset already exists and redeploy is not allowed)` (Nexus CE 3.98.3).
- **API anahtarı:** Nexus 3.98'in yeni arayüzünde menü adı "Account settings, tokens and keys" > "NuGet API Key"; "Access API Key" parolayı yeniden sorar. Anahtar penceresinin yanı sıra sayfadaki kullanım komutlarına da açıkça yazılır: ekran paylaşırken dikkat.
- **Restore yolu:** restore paketi `nuget-group`'tan alır (`v3/content/saha.common.contracts.ekip01/1.0.0/...`); `nuget.org`'a gitmez (doğrulama boş bir NuGet önbelleğiyle bunu denetler).
- Agent'ta ve `develop`'un imaj derlemesinde paket Nexus'tan alındı; ek ayar gerekmedi (repo kökündeki `NuGet.config` imaja kopyalanıyor).
- Paket kimliğinde ekip soneki olmadan ekipler çakışır: ilk yayınlayan kazanır, ötekiler 409 alır ya da başkasının paketini kullanır. Doğrulama soneksiz bir paket yayınlandığında kalır.

## Sandbox notları

- Hosted depoda sürüm silmek yönetici işidir. `sifirla-ekip` ve her checkpoint ekibin paketini siler; `lab-05a` ve `final` checkpoint'leri onu ekibin kendi API anahtarıyla yeniden yayınlar.
- Checkpoint'te anahtar, Nexus arayüzünün kullandığı iç uç noktalardan alınır (`/service/rest/internal/nuget-api-key`); bu uç nokta herkese açık REST API'nin parçası değildir, Nexus sürümü değişirse bozulabilir.

## Bonus · `Pack & Publish`

Çözüm (tam metin `lab-ortami/checkpoint/adimlar/05a-bonus/pack-publish.groovy`; `environment` bloğuna `NEXUS = 'https://nexus.kurum.test'` eklenir):

```groovy
stage('Pack & Publish') {
  when { allOf { branch 'main'; changeset 'src/common-contracts/**' } }
  steps {
    configFileProvider([configFile(fileId: 'nuget-config', variable: 'NUGET_CFG')]) {
      withCredentials([string(credentialsId: 'nexus-nuget-key', variable: 'KEY')]) {
        sh '''rm -rf out && dotnet pack src/common-contracts -c Release -o out
              PAKET=$(dotnet msbuild src/common-contracts -getProperty:PackageId)
              SURUM=$(dotnet msbuild src/common-contracts -getProperty:Version)
              ADRES="$NEXUS/repository/nuget-group/v3/content/$(echo $PAKET | tr 'A-Z' 'a-z')/index.json"
              if curl -fsS "$ADRES" 2>/dev/null | grep -q "\\"$SURUM\\""; then
                echo "HATA: $PAKET $SURUM Nexus'ta zaten var. src/common-contracts değişti ama Version artırılmadı."
                exit 1
              fi
              dotnet nuget push out/$PAKET.$SURUM.nupkg --configfile "$NUGET_CFG" --source nexus-hosted --api-key "$KEY"'''
      }
    }
  }
}
```

**Denendi (ekip-02, `kanit/faz-5/50-bonus-pack-publish-ekip02.txt`):** stage ve `Version 1.0.1` `main`'e girince `main #3` paketi yayınladı (`Created … Your package was pushed.`; Nexus'ta `1.0.0`, `1.0.1`). Ardından `Description` değişti, sürüm aynı kaldı: `main #4` push denemeden durdu (`HATA: Saha.Common.Contracts.Ekip02 1.0.1 Nexus'ta zaten var …`), `main` kırmızı. Feature branch'lerde stage `skipped due to when conditional`. `dotnet nuget push --configfile` .NET SDK 10.0.404'te çalıştı.

**Eğitmen demosu (GitLab Package Registry):** `bash dogrula/demo-gitlab-paket.sh NN`. Kısa ömürlü bir deploy token üretir, kaynağı geçici bir `NuGet.Config`'te tanımlar, paketi proje düzeyindeki NuGet deposuna yayınlar ve token'ı iptal eder. Denendi (ekip-02): `Created … Your package was pushed.`; bir `warn : No API Key was provided` satırı beklenir. Yalnızca bir ekiple gösterin (slayt notu).

Final checkpoint'inin `Jenkinsfile`'ında bu stage **yoktur**: LAB 05-A'da paket elle yayınlandığı için, release'den sonraki ilk `main` build'i `1.0.0`'ı yeniden yayınlamaya çalışıp kırılırdı. Bonus yapan ekip bunu bilmeli: `Version`'u artırmadan `main`'e girerse `main` kırmızı olur (istenen davranış; slayt notu).
