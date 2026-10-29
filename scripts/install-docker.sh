#!/usr/bin/env bash
# Replace snap Docker with Docker Engine from Docker's official apt repo (Ubuntu).
# See docs/TROUBLESHOOTING.md for why. Run as root.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)." >&2; exit 1; }

if snap list docker >/dev/null 2>&1; then
  echo "Removing snap docker (containers/images from the snap are discarded)..."
  snap remove --purge docker
fi

apt-get update
apt-get install -y ca-certificates curl gettext-base
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
[[ -n "${SUDO_USER:-}" ]] && usermod -aG docker "$SUDO_USER" && echo "Log out/in so $SUDO_USER picks up the docker group."
docker --version
docker compose version
