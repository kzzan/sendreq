#!/usr/bin/env bash
set -euo pipefail

dmg=''
while (($#)); do
  case "$1" in
    --dmg) dmg="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
done

[[ -f "$dmg" ]] || {
  echo '--dmg must point to a disk image.' >&2
  exit 64
}

workspace="$(mktemp -d)"
mount="$workspace/mount"
attached=false
cleanup() {
  if [[ "$attached" == true ]]; then
    hdiutil detach "$mount" -quiet || true
  fi
  rm -rf "$workspace"
}
trap cleanup EXIT

mkdir -p "$mount"
hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount"
attached=true
app="$mount/sendreq.app"
[[ -d "$app" ]] || {
  echo 'DMG does not contain sendreq.app at its root.' >&2
  exit 1
}
[[ -x "$app/Contents/MacOS/sendreq" ]] || {
  echo 'DMG application bundle does not contain an executable sendreq binary.' >&2
  exit 1
}
plutil -lint "$app/Contents/Info.plist"
