#!/usr/bin/env bash
set -euo pipefail

app=''
version=''
output=''

while (($#)); do
  case "$1" in
    --app) app="$2"; shift 2 ;;
    --version) version="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
done

[[ -d "$app" && "$app" == *.app ]] || {
  echo '--app must point to a macOS .app bundle.' >&2
  exit 64
}
[[ -n "$version" && -n "$output" ]] || {
  echo '--version and --output are required.' >&2
  exit 64
}

mkdir -p "$output"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/image"
ditto "$app" "$stage/image/sendreq.app"
hdiutil create \
  -volname sendreq \
  -srcfolder "$stage/image" \
  -ov \
  -format UDZO \
  "$output/sendreq-$version-macos-x64.dmg"
