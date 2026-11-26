# SonarQube Community Build + lab CA'si: sunucu Quality Gate sonucunu Jenkins'e
# https://jenkins.<D>/sonarqube-webhook/ adresinden bildirir (JVM guven deposu).
# Build context: lab-ortami/images; ek context `certs` = lab-ortami/certs.
ARG SONARQUBE_TAG=26.11.0.134175-community
FROM sonarqube:${SONARQUBE_TAG}
USER root
COPY --from=certs ca.crt /tmp/kurum-ca.crt
RUN keytool -importcert -noprompt -trustcacerts -alias kurum-ca -file /tmp/kurum-ca.crt \
      -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit >/dev/null \
 && rm /tmp/kurum-ca.crt
USER sonarqube
