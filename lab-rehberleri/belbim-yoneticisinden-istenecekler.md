# BELBİM yöneticisi için eğitim hazırlığı

25 Kasım 2026 yüz yüze eğitim öncesinde bu listeyi kurum ortamında tamamlayın. Sandbox sonuçları BELBİM ortamının doğrulandığı anlamına gelmez. Kurum adreslerini ve CA yolunu [lab.env.example](../lab-ortami/lab.env.example) üzerinden tek `lab.env` dosyasına yazın; sırları bu dosyaya koymayın.

| Alan | Eğitimden önce hazır olması gereken |
|---|---|
| Katılımcı makinesi | Bash, Git, .NET SDK 10.0, Node 24, npm, Docker Engine + Compose + buildx (`docker` sürücüsü), curl, jq, SSH/scp, unzip, tree, editör. Kullanıcı Docker'a erişebilmeli. |
| DNS / TLS | GitLab, registry, Jenkins, SonarQube, Nexus, test VM adları katılımcı, agent ve test VM'den çözülsün. CA işletim sistemi, Git, Java ve Node güven depolarında olsun. TLS doğrulaması kapatılmasın. |
| Temel imajlar | `MCR` / `HUB` iç aynaları, [sabit kaynaklar](../lab-ortami/bootstrap/temel-imajlar.tablo) ile hazır olsun. SDK/Node imajları kurum CA'sına güvensin. Dört temel imaj katılımcı Docker'ına önceden `docker load` ile yüklensin; LAB 03-A'nın ilk build'i CA adımından öncedir. |
| GitLab | `egitim`, ekip alt grupları, starter ve base projeleri; ekip başına ayrı Maintainer ve Developer. Starter'ın tüm `lab/*` ve `checkpoint/*` branch'leri yayınlanmış olsun. Ekip uygulama projesini öğrenci LAB 02-A'da oluşturur. |
| GitLab giden istekler | Jenkins'in tam host adı izin listesinde; yerel ağa genel izin açılmasın. Project Access Token üretimi eğitim projesinde kullanılabilsin. |
| Jenkins controller | Executor 0; `gitlab` connection ve `sonarqube` sunucu tanımı. Ekip başına klasör ve yalnızca kendi klasörüne yetkili hesap. Ekip token'ları global credential olmasın. |
| Jenkins pluginleri | [plugins.txt](../lab-ortami/images/jenkins/plugins.txt): özellikle GitLab, Pipeline/Multibranch, Git, SonarQube Scanner, JUnit, Credentials, SSH Agent, Config File Provider ve Basic Branch Build Strategies. Kurumda sürüm uyumluluğu ayrıca denetlensin. |
| Jenkins agent | `dotnet-docker` label; SDK/Node/Docker/Git ve scanner araçları, kurum CA'sı, registry erişimi. `MCR` ve `HUB` global ortam değişkenleri. `MSBUILDDISABLENODEREUSE=1`. Test VM sunucu anahtarı doğrulanarak `known_hosts` içine alınsın; SSH doğrulaması kapatılmasın. |
| Jenkins managed file | `nuget-config`: `nexus` group kaynak, `nexus-hosted` yayın kaynağı; `<clear />`. API anahtarı dosyaya gömülmesin. |
| SonarQube | Community akışı: analiz yalnızca develop. Ekip kullanıcısı proje ve analiz token'ı oluşturabilsin. Global webhook `$JENKINS_URL/sonarqube-webhook/` (sondaki `/` dahil); yerel ağ engeli varsa yöneticinin ağ politikasıyla uyumlu çözüm. Sandbox `sonar.validateWebhooks=false` kullanır; TLS açık kalır. |
| Nexus | `nuget.org-proxy`, `nuget-hosted`, `nuget-group`, `npm-proxy`, `npm-hosted`, `npm-group`; hosted redeploy kapalı. NuGet API Key realm; ekip başına yayıncı hesap, group/proxy okuma erişimi. Community EULA/telemetri onayları yöneticinin kararıdır. |
| Test VM | Docker/Compose; `deploy` hesabı; `/opt/saha/ekipNN` yazılabilir dizinleri. Ekip portları 8081…8090 (prova 8099). Ekip registry girişi kendi `.docker` dizininde. Ekip SSH açık anahtarları yetkili; Jenkins için ayrı anahtar LAB 05-B'de eklenir. |
| Ağ | GitLab webhook → Jenkins; SonarQube webhook → Jenkins; agent → GitLab/Nexus/SonarQube/registry/test VM; test VM → registry; workstation → tüm eğitim servisleri. |

Öğrenciye bırakılanları önceden tamamlamayın: branch/tag korumaları, MR şablonu, ekip proje token'ları, Jenkins job/credential'ları, SonarQube proje/token, Docker daemon CA adımı, ekip deploy'u. Bunlar labın kendisidir.

## Ders kararları

- GitLab Free akışı: protected branch push kapalı, merge Maintainer; ücretli approval/Code Owners zorunluluğu gösterilmez.
- SonarQube Community: feature testleri yeşil olsa da develop Quality Gate kalabilir. Kapı geçmeden imaj yayınlanmaz.
- Tek test VM ortamında release'i önce develop'a geri merge edip deploy'unu bekleyin, sonra `v1.1.0` tag'ini atın.
- `deploy/deploy.sh` tam dosya olarak verilir; amacı shell yazdırmak değil deploy kaydı ve rollback zinciridir.
- Bonus Pack & Publish final pipeline'dan ayrıdır; aynı paket sürümünün ikinci yayını bu Nexus'ta **409** döner.

Kurum ortamında çalıştırılan denetimlerin çıktılarını ayrıca saklayın; eksik yetki nedeniyle incelenemeyen ayarları “geçti” olarak işaretlemeyin.

## Ortak agent’ta Docker girişi

Her job `DOCKER_CONFIG = "${WORKSPACE}@tmp/docker-config"` kullanmalı; bu dizin Docker build context’inin dışında olmalı. En dış `post/always`, yalnızca o job’ın `config.json` dosyasını temizler. Ortak `$HOME/.docker/config.json` içine ekip token’ı bırakılmamalı. Token iptali veya ekip sıfırlaması diğer ekiplerin registry girişini etkilememeli.
