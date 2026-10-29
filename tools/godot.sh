#!/usr/bin/env bash
# Run Godot 4.7.2 (headless) inside the same Docker image CI uses.
# Usage: tools/godot.sh --headless --import
set -euo pipefail
IMAGE="barichello/godot-ci:4.7.2@sha256:cdcca31e9194fd59a68a63f4b1b9c3981716819c520cd6f7966c5d72ca7246bd"  # pinned by digest; keep in sync with .github/workflows/build.yml
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER="$(command -v docker || true)"
MOUNT="$ROOT"
# WSL without Docker Desktop integration: use the Windows CLI and a Windows path.
if [[ -z "$DOCKER" ]] || ! "$DOCKER" info >/dev/null 2>&1; then
  DOCKER="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
  MOUNT="$(wslpath -w "$ROOT")"
fi
# Godot runs as root in the image; hand created files back to the host user afterwards.
exec "$DOCKER" run --rm -v "$MOUNT:/project" -w /project "$IMAGE" \
  sh -c 'godot "$@"; s=$?; chown -R '"$(id -u):$(id -g)"' /project; exit $s' godot "$@"
