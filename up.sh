#!/usr/bin/env bash
# Set up the Cloudflare Tunnel connector as a single container. Run: ./up.sh
# Idempotent — re-run anytime to converge this host to the standard.
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "ERROR: no .env here. Run: cp .env.example .env  then fill it in."; exit 1; }
set -a; . ./.env; set +a
: "${TUNNEL_TOKEN:?set TUNNEL_TOKEN in .env}"
name="${CONNECTOR_NAME:-cloudflared}"

echo "==> ensure shared network"
docker network create shared 2>/dev/null || true

echo "==> (re)create connector: $name"
docker rm -f "$name" >/dev/null 2>&1 || true
docker run -d --name "$name" --restart unless-stopped \
  --network shared \
  --add-host host.docker.internal:host-gateway \
  --env TUNNEL_TOKEN \
  cloudflare/cloudflared:latest tunnel --no-autoupdate run

# APPS="auto" -> attach every running container; "a b c" -> just those; "" -> apps join `shared` themselves
if [ "${APPS:-}" = "auto" ]; then APPS="$(docker ps --format '{{.Names}}' | grep -vx "$name" || true)"; fi
echo "==> attach apps to shared: ${APPS:-<none — apps must join shared themselves>}"
for c in ${APPS:-}; do
  docker network connect shared "$c" 2>/dev/null && echo "   + $c" || echo "   . $c (already attached or not found)"
done

echo "==> verify"
docker inspect "$name" --format 'image={{.Config.Image}} | nets={{range $k,$v:=.NetworkSettings.Networks}}{{$k}} {{end}}| hosts={{json .HostConfig.ExtraHosts}}'
first="$(echo "${APPS:-}" | awk '{print $1}')"
[ -n "$first" ] && { echo -n "resolve $first -> "; docker exec "$name" getent hosts "$first" || echo "FAILED — is $first on the shared network?"; }
echo "==> logs (expect 4x 'Registered tunnel connection'):"
docker logs --tail 6 "$name" 2>&1 | sed 's/^/   /'
