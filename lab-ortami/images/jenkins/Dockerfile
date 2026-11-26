# Jenkins controller: pluginler ve Configuration as Code ile. Build controller'da calismaz
# (executor 0); isler jenkins-agent'a gider.
# Build context: lab-ortami/images; ek context `certs` = lab-ortami/certs (lab CA'si).
ARG JENKINS_TAG=2.580.2-lts-jdk21
FROM jenkins/jenkins:${JENKINS_TAG}

# Pluginler: surumler plugins.txt icinde sabittir.
COPY jenkins/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Lab CA'si: controller GitLab ve SonarQube'a HTTPS ile baglanir (JVM guven deposu).
USER root
COPY --from=certs ca.crt /usr/local/share/ca-certificates/kurum-ca.crt
RUN update-ca-certificates >/dev/null \
 && keytool -importcert -noprompt -trustcacerts -alias kurum-ca \
      -file /usr/local/share/ca-certificates/kurum-ca.crt \
      -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit >/dev/null \
 && install -d -o jenkins -g jenkins /var/jenkins_agent
USER jenkins

COPY jenkins/casc/ /usr/share/jenkins/casc/
COPY jenkins/init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xms512m -Xmx1g"
