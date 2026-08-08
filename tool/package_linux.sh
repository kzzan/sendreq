#!/usr/bin/env bash
set -euo pipefail

bundle=''
version=''
output=''

while (($#)); do
  case "$1" in
    --bundle) bundle="$2"; shift 2 ;;
    --version) version="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
done

[[ -d "$bundle" ]] || { echo '--bundle must point to a Linux bundle.' >&2; exit 64; }
[[ -x "$bundle/sendreq" ]] || { echo 'Linux bundle is missing sendreq.' >&2; exit 1; }
[[ -n "$version" && -n "$output" ]] || {
  echo '--version and --output are required.' >&2
  exit 64
}
command -v dpkg-deb >/dev/null
command -v rpmbuild >/dev/null

mkdir -p "$output"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

payload="$workspace/sendreq-$version"
install -d "$payload/usr/lib/sendreq" \
  "$payload/usr/bin" \
  "$payload/usr/share/applications" \
  "$payload/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle/." "$payload/usr/lib/sendreq/"
install -m 0755 /dev/stdin "$payload/usr/bin/sendreq" <<'EOF'
#!/usr/bin/env sh
exec /usr/lib/sendreq/sendreq "$@"
EOF
install -m 0644 packaging/linux/io.sendreq.desktop \
  "$payload/usr/share/applications/io.sendreq.desktop"
install -m 0644 assets/branding/sendreq-app-icon.png \
  "$payload/usr/share/icons/hicolor/256x256/apps/sendreq.png"

deb="$workspace/deb"
cp -a "$payload" "$deb"
install -d "$deb/DEBIAN"
printf '%s\n' \
  'Package: sendreq' \
  "Version: $version" \
  'Section: devel' \
  'Priority: optional' \
  'Architecture: amd64' \
  'Maintainer: sendreq <mkst@duck.com>' \
  'Description: Desktop API workspace for REST, WebSocket, and gRPC' \
  > "$deb/DEBIAN/control"
dpkg-deb --root-owner-group --build "$deb" \
  "$output/sendreq-$version-linux-amd64.deb"

rpmTop="$workspace/rpmbuild"
install -d "$rpmTop/BUILD" "$rpmTop/BUILDROOT" "$rpmTop/RPMS" \
  "$rpmTop/SOURCES" "$rpmTop/SPECS" "$rpmTop/SRPMS"
tar -C "$workspace" -czf "$rpmTop/SOURCES/sendreq-$version.tar.gz" \
  "sendreq-$version"
cp packaging/linux/sendreq.spec "$rpmTop/SPECS/sendreq.spec"
rpmbuild --define "_topdir $rpmTop" --define "sendreq_version $version" \
  -bb "$rpmTop/SPECS/sendreq.spec"
rpmPackage="$(find "$rpmTop/RPMS" -type f -name '*.rpm' -print -quit)"
[[ -n "$rpmPackage" ]] || { echo 'rpmbuild did not create an RPM.' >&2; exit 1; }
cp "$rpmPackage" "$output/sendreq-$version-linux-x86_64.rpm"
