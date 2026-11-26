#!/usr/bin/env bash
# Jenkins: ekip kullanicilari ve ekip klasorleri. araclar container'inda calisir;
# tekrar calistirmak guvenlidir. Global yapilandirma imajdaki Configuration as Code
# dosyasindan gelir (images/jenkins/casc/jenkins.yaml).
#
# Katilimciya birakilanlar burada YAPILMAZ: klasor credential'lari (gitlab-api, gitlab-repo,
# sonar-token, gitlab-registry ...), Multibranch job, webhook.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

adim "Jenkins"
zorunlu "Jenkins erisimi" jk GET /api/json
bilgi "surum: $(curl -sS -K "$_JK_CFG" -o /dev/null -D - "${JENKINS_URL}/login" | tr -d '\r' | sed -n 's/^[Xx]-[Jj]enkins: //p')"

# Global durum: executor 0, agent bagli, baglanti ve sunucu adlari.
cat > "$_CURL_DIR/durum.groovy" <<'GROOVY'
import jenkins.model.Jenkins
def j = Jenkins.get()
def agent = j.getComputer('agent-1')
def gl = j.getDescriptorByType(com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig)
def sq = j.getDescriptorByType(hudson.plugins.sonar.SonarGlobalConfiguration)
// gitlab-plugin ilk kurulumda CasC baglantisinin yanina bos bir varsayilan
// baglanti ekleyebiliyor. Yalnizca tamamen bos kaydi kaldir; adli/URLli kayitlari
// sessizce silme. setConnections pluginin istemci eslemesini de yeniler.
def baglantilar = gl.connections.findAll { it.name?.trim() || it.url?.trim() || it.apiTokenId?.trim() }
if (baglantilar.size() != gl.connections.size()) {
  gl.setConnections(baglantilar)
  gl.save()
  println 'lab: bos GitLab connection temizlendi'
}
println "controller-executor=${j.numExecutors}"
println "agent-online=${agent?.online} label=${agent?.node?.labelString} executor=${agent?.numExecutors}"
println "gitlab-connection=${gl.connections*.name.join(',')}"
println "sonarqube-server=${sq.installations*.name.join(',')}"
GROOVY
zorunlu "Jenkins durum sorgusu" jk_groovy "$_CURL_DIR/durum.groovy"
durum="$HTTP_BODY"
grep -q '^controller-executor=0$' <<<"$durum" || olum "controller'da executor var: $durum"
grep -q '^gitlab-connection=gitlab$' <<<"$durum" || olum "GitLab connection 'gitlab' yok: $durum"
grep -q '^sonarqube-server=sonarqube$' <<<"$durum" || olum "SonarQube sunucu tanimi 'sonarqube' yok: $durum"
grep -q 'agent-online=true label=dotnet-docker' <<<"$durum" || uyari "agent henuz bagli degil: $(grep agent-online <<<"$durum")"
tamam "controller executor 0; agent $(sed -n 's/^agent-online=//p' <<<"$durum")"
tamam "GitLab connection: gitlab; SonarQube sunucusu: sonarqube"

# Ekip kullanicilari ve klasorleri. Parolalar istegin govdesinde gider.
{
  printf 'def ekipler = [\n'
  for nn in $(ekipler); do
    printf '  "%s": "%s",\n' "$nn" "$(ekip_parola "jenkins:ekip${nn}")"
  done
  printf ']\n'
  cat <<'GROOVY'
import jenkins.model.Jenkins
import hudson.model.Item
import hudson.model.Run
import hudson.model.View
import hudson.scm.SCM
import com.cloudbees.hudson.plugins.folder.Folder
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.hudson.plugins.folder.properties.AuthorizationMatrixProperty
import org.jenkinsci.plugins.matrixauth.PermissionEntry
import org.jenkinsci.plugins.matrixauth.AuthorizationType

def j = Jenkins.get()
def realm = j.securityRealm
// Ekip kullanicisinin kendi klasorundeki yetkileri: job ve credential yonetimi.
def yetkiler = [
  Item.READ, Item.DISCOVER, Item.CREATE, Item.CONFIGURE, Item.DELETE, Item.BUILD, Item.CANCEL, Item.WORKSPACE,
  Run.UPDATE, Run.DELETE, View.READ, SCM.TAG,
  CredentialsProvider.VIEW, CredentialsProvider.CREATE, CredentialsProvider.UPDATE, CredentialsProvider.DELETE,
]
ekipler.each { nn, parola ->
  def kullanici = "ekip${nn}"
  def hesap = realm.getUser(kullanici)
  if (hesap == null) {
    realm.createAccount(kullanici, parola)
    println "kullanici ${kullanici} (olusturuldu)"
  } else {
    // Parola her calistirmada turetilen degerle esitlenir (deger yazdirilmaz).
    def ayrinti = hesap.getProperty(hudson.security.HudsonPrivateSecurityRealm.Details)
    if (ayrinti == null || !ayrinti.isPasswordCorrect(parola)) {
      hesap.addProperty(hudson.security.HudsonPrivateSecurityRealm.Details.fromPlainPassword(parola))
      println "kullanici ${kullanici} (var, parola esitlendi)"
    } else {
      println "kullanici ${kullanici} (var)"
    }
  }
  def ad = "ekip-${nn}"
  def klasor = j.getItem(ad)
  if (klasor == null) {
    klasor = j.createProject(Folder, ad)
    klasor.description = "Ekip ${nn}"
    println "klasor ${ad} (olusturuldu)"
  } else {
    println "klasor ${ad} (var)"
  }
  def yeni = new AuthorizationMatrixProperty()
  yetkiler.each { yeni.add(it, new PermissionEntry(AuthorizationType.USER, kullanici)) }
  def eski = klasor.properties.get(AuthorizationMatrixProperty)
  if (eski == null || eski.grantedPermissionEntries != yeni.grantedPermissionEntries) {
    if (eski != null) klasor.properties.remove(eski)
    klasor.addProperty(yeni)
    klasor.save()
  }
}
// Betigin donus degeri ciktiya yazilir; parola haritasi donmesin.
return null
GROOVY
} > "$_CURL_DIR/ekipler.groovy"
zorunlu "ekip kullanicilari ve klasorleri" jk_groovy "$_CURL_DIR/ekipler.groovy"
if grep -q -E 'Exception|groovy\.lang|startup failed' <<<"$HTTP_BODY"; then
  olum "Jenkins betigi hata verdi: $(head -c 600 <<<"$HTTP_BODY")"
fi
while read -r satir; do
  case "$satir" in ""|Result:*) ;; *) tamam "$satir" ;; esac
done <<<"$HTTP_BODY"
