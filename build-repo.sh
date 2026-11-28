#!/usr/bin/env bash
# Build an apt repository with one suite per channel.
#   build-repo.sh <debs-dir> <out-dir>
# <debs-dir>/<channel>/*.deb  ->  suite <channel> (pool/<channel>/, dists/<channel>/)
# Environment: GPG_KEY_ID (sign if set; the secret key must be in the keyring)
set -euo pipefail
DEBS=${1:?usage: build-repo.sh <debs-dir> <out-dir>}
OUT=${2:?usage: build-repo.sh <debs-dir> <out-dir>}
COMP=main

rm -rf "$OUT"; mkdir -p "$OUT"
shopt -s nullglob
suites=()
for d in "$DEBS"/*/; do
  suite=$(basename "$d")
  files=("$d"*.deb)
  files=($(printf '%s\n' "${files[@]}" | grep -v dbgsym || true))
  [ ${#files[@]} -gt 0 ] || { echo "skip empty channel: $suite" >&2; continue; }
  mkdir -p "$OUT/pool/$suite"
  cp -t "$OUT/pool/$suite" "${files[@]}"
  suites+=("$suite")
done
[ ${#suites[@]} -gt 0 ] || { echo "ERROR: no channels with .deb files" >&2; exit 1; }

cd "$OUT"
for suite in "${suites[@]}"; do
  BIN=dists/$suite/$COMP/binary-amd64
  mkdir -p "$BIN"
  # Architecture: all packages are listed in the amd64 index.
  apt-ftparchive --arch amd64 packages "pool/$suite" > "$BIN/Packages"
  gzip -9kf "$BIN/Packages"; xz -9kf "$BIN/Packages"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Menta Linux" \
    -o APT::FTPArchive::Release::Label="Menta Linux" \
    -o APT::FTPArchive::Release::Suite="$suite" \
    -o APT::FTPArchive::Release::Codename="$suite" \
    -o APT::FTPArchive::Release::Architectures="amd64" \
    -o APT::FTPArchive::Release::Components="$COMP" \
    -o APT::FTPArchive::Release::Description="Menta Linux MATE/Wayland packages ($suite channel)" \
    release "dists/$suite" > "dists/$suite/Release.tmp"
  mv "dists/$suite/Release.tmp" "dists/$suite/Release"
  if [ -n "${GPG_KEY_ID:-}" ]; then
    gpg --batch --yes --default-key "$GPG_KEY_ID" --clearsign -o "dists/$suite/InRelease"   "dists/$suite/Release"
    gpg --batch --yes --default-key "$GPG_KEY_ID" -abs        -o "dists/$suite/Release.gpg" "dists/$suite/Release"
  fi
  echo "suite $suite: $(grep -c '^Package:' "$BIN/Packages") packages"
done
printf '%s\n' "${suites[@]}" > channels.txt
if [ -n "${GPG_KEY_ID:-}" ]; then
  gpg --export "$GPG_KEY_ID" > menta.gpg
  gpg --armor --export "$GPG_KEY_ID" > menta.asc
  echo "signed with $GPG_KEY_ID"
else
  echo "WARNING: not signed (no GPG_KEY_ID); clients must use [trusted=yes]" >&2
fi
