#!/usr/bin/env bash
# Add the Menta Linux apt repository.   sudo bash setup.sh      (channel: MENTA_CHANNEL=stable sudo -E bash setup.sh)
set -euo pipefail
URL=${MENTA_APT_URL:-https://menta-linux.github.io/apt}
. /etc/os-release 2>/dev/null || true
# default channel: Debian 13 (trixie) -> stable, anything newer (forky/sid) -> unstable
if [ "${VERSION_CODENAME:-}" = trixie ]; then DEFAULT_CHANNEL=stable; else DEFAULT_CHANNEL=unstable; fi
CHANNEL=${MENTA_CHANNEL:-$DEFAULT_CHANNEL}   # unstable | testing | stable | ...
need=()
command -v wget >/dev/null || need+=(wget)
[ -e /etc/ssl/certs/ca-certificates.crt ] || need+=(ca-certificates)
[ ${#need[@]} -eq 0 ] || { apt-get update; apt-get install -y "${need[@]}"; }

install -d -m 0755 /usr/share/keyrings
if wget -q -O /usr/share/keyrings/menta.gpg "$URL/menta.gpg"; then
  echo "deb [signed-by=/usr/share/keyrings/menta.gpg] $URL $CHANNEL main" > /etc/apt/sources.list.d/menta.list
else
  echo "No signing key published yet: adding the repository as [trusted=yes]" >&2
  echo "deb [trusted=yes] $URL $CHANNEL main" > /etc/apt/sources.list.d/menta.list
fi
# Debian 13 (trixie): newer wayland-protocols etc. come from trixie-backports (NotAutomatic: only used when a package needs it)
if [ "${VERSION_CODENAME:-}" = trixie ] && ! grep -rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
  echo "deb http://deb.debian.org/debian trixie-backports main" > /etc/apt/sources.list.d/menta-trixie-backports.list
  echo "Added trixie-backports"
fi
apt-get update
echo "Channel: $CHANNEL"
echo "Done. Install with:  sudo apt install mate-desktop-common marco mate-panel caja ..."
