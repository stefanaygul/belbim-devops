#!/usr/bin/env bash
# Bir kullanicinin acik bir MR'i merge edip edemedigini API ile dener (olumsuz deneme).
# araclar container'inda calisir. Istek, yonetici token'i ve Sudo basligiyla o kullanici
# adina yapilir. Merge BASARISIZ olmali; basarili olursa 1 doner.
# Kullanim: api-merge-dene.sh <NN> <lead|dev> <kaynak-branch>
set -euo pipefail
source "$(dirname "$0")/../bootstrap/lib.sh"
nn="$1" kullanici="ekip$1-$2" kaynak="$3"
proje="/projects/$(urlenc "$GITLAB_GROUP/ekip-$nn/saha-ekipman-portal")"
zorunlu "MR sorgusu" gl GET "$proje/merge_requests?state=opened&source_branch=$(urlenc "$kaynak")"
iid="$(jq -r '.[0].iid // empty' <<<"$HTTP_BODY")"
[ -n "$iid" ] || olum "acik MR yok: $kaynak"
zorunlu "MR !$iid" gl GET "$proje/merge_requests/$iid" -H "Sudo: $kullanici"
printf '    MR !%s (%s): user.can_merge=%s, detailed_merge_status=%s\n' "$iid" "$kullanici" \
  "$(jq -r '.user.can_merge' <<<"$HTTP_BODY")" "$(jq -r '.detailed_merge_status' <<<"$HTTP_BODY")"
if gl PUT "$proje/merge_requests/$iid/merge" -H "Sudo: $kullanici"; then
  olum "$kullanici MR !$iid'i merge edebildi; reddedilmesi bekleniyordu"
fi
printf '    PUT .../merge_requests/%s/merge (%s) -> HTTP %s %s\n' "$iid" "$kullanici" "$HTTP_CODE" "$(jq -r '.message // empty' <<<"$HTTP_BODY" 2>/dev/null)"
tamam "$kullanici merge edemiyor (beklenen)"
