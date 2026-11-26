#!/bin/bash
set -euo pipefail

# 1. Lab CA'si: isletim sistemi ve Docker daemon. Test VM'i yonetici hazirlar;
#    registry'ye guven burada bastan kuruludur.
if [ -f /lab/certs/ca.crt ]; then
  install -D -m 0644 /lab/certs/ca.crt /usr/local/share/ca-certificates/kurum-ca.crt
  update-ca-certificates >/dev/null 2>&1
  install -D -m 0644 /lab/certs/ca.crt "/etc/docker/certs.d/gitlab.${LAB_DOMAIN}:5050/ca.crt"
fi

# 2. SSH host anahtarlari (ilk acilista uretilir, volume'da kalir).
mkdir -p /etc/ssh/hostkeys
[ -f /etc/ssh/hostkeys/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -N '' -f /etc/ssh/hostkeys/ssh_host_ed25519_key
[ -f /etc/ssh/hostkeys/ssh_host_rsa_key ]     || ssh-keygen -q -t rsa -b 3072 -N '' -f /etc/ssh/hostkeys/ssh_host_rsa_key

# 3. deploy kullanicisinin ev dizini ve uygulama koku (ikisi de volume).
mkdir -p /home/deploy/.ssh /opt/saha
touch /home/deploy/.ssh/authorized_keys
chmod 0700 /home/deploy/.ssh
chmod 0600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy
chown deploy:deploy /opt/saha

# 4. Docker daemon
lab-dockerd-start

# 5. SSH sunucusu (on planda)
echo "test-vm hazir"
exec /usr/sbin/sshd -D -e
