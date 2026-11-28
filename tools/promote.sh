#!/usr/bin/env bash
# Explicitly put package builds into a channel of the artifacts repository.
#   tools/promote.sh <channel> <pkg> [<pkg> ...]      e.g.  tools/promote.sh unstable mate-panel marco
# Takes the .debs (without -dbgsym) of menta-linux/pkg-<pkg>'s rolling release and uploads them to the
# <channel> release of menta-linux/artifacts (created if missing), replacing older versions of the same packages.
# Needs: gh (logged in, write access to menta-linux/artifacts).
set -euo pipefail
ART=${ARTIFACTS_REPO:-menta-linux/artifacts}
channel=${1:?usage: promote.sh <channel> <pkg> [<pkg> ...]}; shift
# Which rolling release of the pkg-* repos feeds which channel (same tags install-menta.sh uses):
#   stable (Debian 13 trixie builds, ~deb13)  <- latest-trixie        every other channel (sid builds) <- latest
# Override with SOURCE_TAG=...
if [ -n "${SOURCE_TAG:-}" ]; then TAG=$SOURCE_TAG
elif [ "$channel" = stable ]; then TAG=latest-trixie
else TAG=latest; fi
echo "channel '$channel' <- release tag '$TAG'"
[ $# -gt 0 ] || { echo "no packages given" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for p in "$@"; do
  gh release download "$TAG" -R "menta-linux/pkg-$p" -p '*.deb' -D "$tmp" --clobber
done
rm -f "$tmp"/*dbgsym*.deb
ls "$tmp"/*.deb >/dev/null

gh release view "$channel" -R "$ART" >/dev/null 2>&1 || \
  gh release create "$channel" -R "$ART" --title "$channel" --notes "Menta Linux $channel channel"

# drop older versions of the packages being replaced
existing=$(gh release view "$channel" -R "$ART" --json assets -q '.assets[].name')
for f in "$tmp"/*.deb; do
  name=${f##*/}; name=${name%%_*}
  for a in $existing; do
    [ "${a%%_*}" = "$name" ] && [ "$a" != "${f##*/}" ] && gh release delete-asset "$channel" "$a" -R "$ART" -y
  done
done
gh release upload "$channel" "$tmp"/*.deb -R "$ART" --clobber
echo "promoted to $ART release '$channel': $(ls "$tmp" | wc -l) files"
