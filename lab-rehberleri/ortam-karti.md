# Eğitim ortamı kartı

Lablardaki bütün adresler ve adlar bu karttan gelir. Rehberlerde adres yazmaz; değişken adı yazar (`$GITLAB_URL` gibi). Değişkenler eğitim makinenizde hazırdır: terminali açtığınızda `lab.env` dosyası yüklenir.

Aşağıdaki örnek değerler prova ortamına (sandbox) aittir. BELBİM ortamında değerler farklıdır; geçerli olan, eğitim makinenizdeki `lab.env` dosyasıdır.

```bash
cat /etc/lab/lab.env      # ortak adresler
echo $EKIP $IMG $WEB_PORT $TEST_URL   # ekibinize özel değerler
```

> Durum: Faz 5. Bütün satırlar Gün 1–5 lablarıyla sandbox'ta doğrulandı; `nexus-nuget-key` yalnızca LAB 05-A bonusunda kullanılır.

## Ortak adresler

| Değişken | Örnek değer | Ne için |
|---|---|---|
| `GITLAB_URL` | `https://gitlab.kurum.test` | GitLab arayüzü ve Git (HTTPS) |
| `REGISTRY` | `gitlab.kurum.test:5050` | Container Registry |
| `NEXUS_URL` | `https://nexus.kurum.test` | Nexus arayüzü |
| `NUGET_GROUP_URL` | `https://nexus.kurum.test/repository/nuget-group/index.json` | NuGet restore (okuma) |
| `NUGET_HOSTED_URL` | `https://nexus.kurum.test/repository/nuget-hosted/` | NuGet paket yayını (yazma) |
| `NPM_GROUP_URL` | `https://nexus.kurum.test/repository/npm-group/` | npm kurulum (okuma) |
| `JENKINS_URL` | `https://jenkins.kurum.test` | Jenkins (4. gün) |
| `SONAR_URL` | `https://sonar.kurum.test` | SonarQube (4. gün) |
| `TEST_VM` | `test-vm.kurum.test` | İkinci VM / test VM |
| `MCR`, `HUB` | `gitlab.kurum.test:5050/egitim/base` | Temel imajların iç aynası (`--build-arg`) |
| `CA_CERT` | `/etc/lab/kurum-ca.crt` | Kurum CA sertifikası |
| `TEMPLATE_PROJECT` | `egitim/sablonlar/portal-starter` | Starter proje |

## Ekibe özel değerler

`NN` iki haneli ekip numaranızdır (`01`, `02`, …).

| Ne | Değer | ekip-01 için örnek |
|---|---|---|
| GitLab alt grubu | `egitim/ekip-NN` | `egitim/ekip-01` |
| Ekip projesi | `egitim/ekip-NN/saha-ekipman-portal` | `egitim/ekip-01/saha-ekipman-portal` |
| GitLab hesabı, Maintainer | `ekipNN-lead` | `ekip01-lead` |
| GitLab hesabı, Developer | `ekipNN-dev` | `ekip01-dev` |
| Eğitim makinesi kullanıcısı | `ekipNN` | `ekip01` |
| İmaj adı öneki (`$IMG`) | `$REGISTRY/egitim/ekip-NN/saha-ekipman-portal` | `gitlab.kurum.test:5050/egitim/ekip-01/saha-ekipman-portal` |
| Deploy token (push; `read_registry` + `write_registry`) | `ekipNN-deploy` | `ekip01-deploy` |
| Deploy token (test VM; yalnızca `read_registry`) | `ekipNN-pull` | `ekip01-pull` |
| Nexus hesabı | `ekipNN` | `ekip01` |
| NuGet paket kimliği (LAB 05-A) | `Saha.Common.Contracts.EkipNN` | `Saha.Common.Contracts.Ekip01` |
| NuGet yayın adresi (hosted) | `$NEXUS_URL/repository/nuget-hosted/` | `https://nexus.kurum.test/repository/nuget-hosted/` |
| NuGet API anahtarı | Nexus > hesap menüsü > NuGet API Key (kendiniz alırsınız) | — |
| Jenkins'in test VM anahtarı (LAB 05-B) | `~/.ssh/jenkins-test-vm`, yorum `jenkins-ekipNN` | `jenkins-ekip01` |
| Deploy kaydı (test VM) | `/opt/saha/ekipNN/deploy-kayit.log` | `/opt/saha/ekip01/deploy-kayit.log` |
| Release ve tag (LAB 05-B) | `release/1.1.0`, `v1.1.0` | |
| Test VM kullanıcısı | `deploy` | `deploy` |
| Test VM dizini | `/opt/saha/ekipNN/` | `/opt/saha/ekip01/` |
| Test VM'de registry girişi (`DOCKER_CONFIG`) | `/opt/saha/ekipNN/.docker` | `/opt/saha/ekip01/.docker` |
| Compose proje adı | `ekipNN` | `ekip01` |
| `WEB_PORT` (test VM'de ve lokal Compose'da) | `8080 + N` | `8081` |
| `TEST_URL` | `http://$TEST_VM:$WEB_PORT` | `http://test-vm.kurum.test:8081` |
| Jenkins klasörü | `ekip-NN` | `ekip-01` |
| Jenkins Multibranch job | `saha-portal-ekipNN` | `saha-portal-ekip01` |
| Jenkins hesabı | `ekipNN` | `ekip01` |
| Webhook adresi (GitLab → Jenkins) | `$JENKINS_URL/project/ekip-NN/saha-portal-ekipNN` | `https://jenkins.kurum.test/project/ekip-01/saha-portal-ekip01` |
| Project Access Token (Jenkins için; `api`, Maintainer) | `jenkins` | `jenkins` |
| Deploy token (Jenkins; `read_registry` + `write_registry`) | `ekipNN-jenkins` | `ekip01-jenkins` |
| SonarQube hesabı | `ekipNN` | `ekip01` |
| SonarQube proje adı ve anahtarı (ana branch `develop`) | `saha-portal-ekipNN` | `saha-portal-ekip01` |

Parolaları eğitmen dağıtır; bu kartta ve rehberlerde parola yer almaz.

**Issue ve MR numaraları.** GitLab, issue ve MR'ları her projede 1'den numaralar. Slaytlardaki `#3`, `!5`, `#7` örnektir; lab sırasıyla sizde `#1` (stok durumu), `#2` (boş ekipman kodu), `#3` (Docker imajları) oluşur. Branch adları slaytlardaki gibi kalır: `feature/3-stok-durumu`, `feature/9-docker`, `feature/12-miktar-dogrulama`.

## Temel imajlar (eğitim makinesinde hazır)

| Dockerfile'da | Ne |
|---|---|
| `${MCR}/dotnet/sdk:10.0` | .NET SDK 10.0.404 + kurum CA'sı |
| `${MCR}/dotnet/aspnet:10.0` | ASP.NET Core runtime 10.0.15 |
| `${HUB}/library/node:24-alpine` | Node.js 24.22.3 + kurum CA'sı |
| `${HUB}/nginxinc/nginx-unprivileged:stable-alpine` | Nginx 1.31.7 (root olmayan) |

`docker images | grep /base/` dört satır göstermelidir.

## Jenkins'teki sabit adlar

| Ne | Ad |
|---|---|
| Agent label | `dotnet-docker` |
| GitLab connection | `gitlab` |
| SonarQube sunucusu | `sonarqube` |
| Credential ID'leri (ekip klasöründe; siz eklersiniz) | LAB 04-A: `gitlab-api` (GitLab API token), `gitlab-repo` (Username with password) · LAB 04-B: `sonar-token` (Secret text), `gitlab-registry` (Username with password) · LAB 05-B: `test-vm-ssh` (SSH Username with private key, kullanıcı `deploy`) · LAB 05-A bonusu: `nexus-nuget-key` (Secret text) |
| SonarQube webhook'u (yönetici kurar) | `$JENKINS_URL/sonarqube-webhook/` |
| Commit status adı | `jenkins` |
| Managed file (yönetici kurar) | `nuget-config` (kaynaklar: `nexus` = group, `nexus-hosted` = hosted) |
| Ortam değişkenleri | `Jenkinsfile` içinde: `REGISTRY`, `IMG`, `SONAR_PROJECT_KEY`, `TEST_VM`, `VM_DIZIN`, `WEB_PORT`, `TEST_URL` · Jenkins'te ortak tanımlı: `MCR`, `HUB` (temel imajların iç aynası) · tag build'inde Jenkins verir: `TAG_NAME` |

## Nexus depoları

| Depo | Tür | Kullanım |
|---|---|---|
| `nuget-group` | group | Restore buradan yapılır |
| `nuget-hosted` | hosted | Ekip paketleri buraya yayınlanır; aynı sürüm ikinci kez yayınlanamaz |
| `nuget.org-proxy` | proxy | nuget.org önbelleği |
| `npm-group` | group | `npm ci` buradan yapılır |
| `npm-hosted` | hosted | İç npm paketleri |
| `npm-proxy` | proxy | npmjs.org önbelleği |

## Sandbox'a özel: host tarayıcısındaki adresler

Prova ortamı tek makinede çalıştığı için bazı portlar tarayıcıda farklı numarayla açılır. Komut satırında (eğitim makinesi, test VM, Jenkins) her zaman yukarıdaki değerler geçerlidir.

| Ağ içindeki adres | Host tarayıcısındaki adres |
|---|---|
| `https://gitlab.kurum.test`, `https://nexus.kurum.test`, `https://jenkins.kurum.test`, `https://sonar.kurum.test` | aynı |
| `http://test-vm.kurum.test:8081` … `:8090` | `http://test-vm.kurum.test:18081` … `:18090` |
| `http://test-vm.kurum.test:8099` (prova ekibi) | `http://test-vm.kurum.test:18099` |
| eğitim makinesinde `http://localhost:5173` | `http://localhost:5173` |
| eğitim makinesinde `http://localhost:8080` | `http://localhost:18080` |
| eğitim makinesinde `http://localhost:808N` (lokal Compose, LAB 03-B) | host'ta yayınlanmaz; arayüze test VM adresinden bakın |

Vite'a host tarayıcısından ulaşmak için geliştirme sunucusunu `npm run dev -- --host` ile başlatın.

İki eş aynı eğitim makinesini paylaşıyorsa terminalde hangi GitLab hesabıyla çalışılacağı `rol lead` / `rol dev` komutuyla seçilir.

BELBİM ortamında bu bölüm geçerli değildir; adresler her yerde aynıdır ve herkesin kendi makinesi vardır.
