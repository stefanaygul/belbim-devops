#!/bin/bash
# Controller'in ortak volume'a yazdigi baglanti sirrini bekler, sonra agent'i baslatir.
set -euo pipefail
sir="/var/jenkins_agent/${JENKINS_AGENT_NAME:?}.secret"
for _ in $(seq 1 180); do
  [ -s "$sir" ] && break
  sleep 2
done
[ -s "$sir" ] || { echo "agent sirri bulunamadi: $sir (controller acildi mi?)" >&2; exit 1; }
JENKINS_SECRET="$(cat "$sir")"
export JENKINS_SECRET
exec /usr/local/bin/jenkins-agent
