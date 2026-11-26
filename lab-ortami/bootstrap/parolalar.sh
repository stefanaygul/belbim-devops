#!/usr/bin/env bash
# Ekip hesaplarini ve parolalarini listeler. araclar container'inda calisir.
# Parolalar hicbir dosyaya yazilmaz; LAB_SECRET'ten turetilir ve yalnizca ekrana basilir.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

printf '%-8s %-10s %-14s %s\n' "Ekip" "Sistem" "Kullanici" "Parola"
for nn in $(ekipler); do
  printf '%-8s %-10s %-14s %s\n' "ekip-$nn" "GitLab" "ekip${nn}-lead" "$(ekip_parola "ekip${nn}-lead")"
  printf '%-8s %-10s %-14s %s\n' "ekip-$nn" "GitLab" "ekip${nn}-dev"  "$(ekip_parola "ekip${nn}-dev")"
  printf '%-8s %-10s %-14s %s\n' "ekip-$nn" "Nexus"  "ekip${nn}"      "$(ekip_parola "nexus-ekip${nn}")"
  printf '%-8s %-10s %-14s %s\n' "ekip-$nn" "Jenkins" "ekip${nn}"     "$(ekip_parola "jenkins:ekip${nn}")"
  printf '%-8s %-10s %-14s %s\n' "ekip-$nn" "SonarQube" "ekip${nn}"   "$(sonar_parola "$nn")"
done
printf '\nYonetici hesaplari (root / admin) icin parolalar .env dosyasindadir.\n'
