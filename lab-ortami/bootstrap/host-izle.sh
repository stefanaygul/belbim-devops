#!/usr/bin/env bash
# Host ve container bellek izlemesi (macOS + Docker Desktop). Hicbir seyi degistirmez.
# Dakikada bir satir yazar: host bos bellek yuzdesi, sikistirici, swap, yuk ortalamasi,
# Docker VM'inin toplami ve belbim-lab container'larinin bellek kullanimi.
# Beklenmeyen bir takilma ya da yeniden baslama olursa geriye veri kalsin diye vardir.
# Kullanim: bootstrap/host-izle.sh <cikti-dosyasi> [saat]     (varsayilan 12 saat)
set -u
cikti="${1:?cikti dosyasi}"
saat="${2:-12}"
bitis=$(( $(date +%s) + saat * 3600 ))
printf '# zaman | host bos%% | sikistirici GB | swap kullanilan | yuk(1dk) | docker VM GiB | lab toplam GiB | en buyuk uc container\n' >> "$cikti"
while [ "$(date +%s)" -lt "$bitis" ]; do
  bos="$(memory_pressure 2>/dev/null | sed -n 's/.*free percentage: //p')"
  sik="$(vm_stat 2>/dev/null | awk '/occupied by compressor/ {gsub("\\.","",$NF); printf "%.1f", $NF*16384/1073741824}')"
  swap="$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6}')"
  yuk="$(uptime | sed 's/.*load averages: //' | awk '{print $1}')"
  vm="$(docker info --format '{{.MemTotal}}' 2>/dev/null | awk '{printf "%.1f", $1/1073741824}')"
  lab="$(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' 2>/dev/null | awk '/^belbim-lab/ {
      v=$2; b=1; if (v ~ /GiB/) b=1; else if (v ~ /MiB/) b=1/1024; else if (v ~ /KiB/) b=1/1048576; sub(/[A-Za-z]+$/,"",v); g=v*b; t+=g;
      n=$1; sub(/^belbim-lab-/,"",n); sub(/-1$/,"",n); printf "%s %.2f\n", n, g > "/dev/stderr" } END {printf "%.2f", t}' 2>/tmp/.host-izle.$$ )"
  enb="$(sort -k2 -nr /tmp/.host-izle.$$ 2>/dev/null | head -n 3 | awk '{printf "%s=%s ", $1, $2}')"
  rm -f /tmp/.host-izle.$$
  printf '%s | %s | %s | %s | %s | %s | %s | %s\n' "$(date '+%m-%d %H:%M')" "${bos:-?}" "${sik:-?}" "${swap:-?}" "${yuk:-?}" "${vm:-?}" "${lab:-?}" "$enb" >> "$cikti"
  sleep 60
done
