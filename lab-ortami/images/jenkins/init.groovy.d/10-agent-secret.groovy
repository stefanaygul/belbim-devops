// Agent'in baglanti sirrini yalnizca controller ve agent container'larinin gordugu
// ortak volume'a yazar. Sir .env'e, komut satirina ya da loga girmez.
import jenkins.model.Jenkins

def dizin = new File('/var/jenkins_agent')
Jenkins.get().computers.each { c ->
  if (c.metaClass.respondsTo(c, 'getJnlpMac')) {
    def dosya = new File(dizin, "${c.name}.secret")
    dosya.text = c.jnlpMac
    dosya.setReadable(false, false)
    dosya.setReadable(true, true)
    println "lab: agent sirri yazildi: ${dosya}"
  }
}
