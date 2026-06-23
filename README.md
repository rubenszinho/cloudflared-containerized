# cloudflared — Cloudflare Tunnel connector

Runs the official `cloudflared` as a single container that exposes your services through a Cloudflare Tunnel — no open/published ports needed. Drop this folder on any host with Docker.

## How it works
- One container (`cloudflare/cloudflared:latest`) per host, started by `up.sh`.
- It joins a Docker network named `shared`. Put your app containers on `shared` too, and the tunnel routes to them **by container name** (`http://<container>:<port>`).
- To reach a service on the host itself (e.g. SSH), use `ssh://host.docker.internal:22`.

## Setup
1. Create the tunnel in Cloudflare and add your public hostname routes (Dashboard → Networks → Tunnels).
2. Configure this host:
   ```bash
   cp .env.example .env      # set TUNNEL_TOKEN, CONNECTOR_NAME, APPS
   ./up.sh                    # idempotent — re-run anytime to converge
   ```
   - `TUNNEL_TOKEN` — connector token (dashboard → configure, or `cloudflared tunnel token <id>`).
   - `CONNECTOR_NAME` — name for this connector. Convention: `cloudflared-<host-id>`.
   - `APPS` — optional, app container names to attach to `shared`.

## Connecting your apps
The connector only resolves containers that share its `shared` network. Docker has no "which containers are public?" signal, so you pick how they join:

- **Apps join `shared` in their own compose (recommended — truly automatic).** No list to maintain; new containers/replicas appear on their own. Keep `default` so intra-stack DNS still works:
  ```yaml
  services:
    <svc>:
      networks: [default, shared]
  networks:
    shared:
      external: true
  ```
- **`APPS="name1 name2"`** — `up.sh` attaches exactly those (no compose edits; re-run after a container is recreated).
- **`APPS="auto"`** — `up.sh` attaches every running container (zero list; harmless, since a container is only reachable if a tunnel route points at it).

## Verify
`up.sh` prints the connector's image/networks and recent logs (expect 4× "Registered tunnel connection"); the tunnel shows healthy in the dashboard.

## High availability
Run this folder on a second host with the **same** `TUNNEL_TOKEN`. Cloudflare routes to the nearest replica (failover; no load-balancing).
# cloudflared-containerized
