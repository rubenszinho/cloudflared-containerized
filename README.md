# cloudflared-containerized

Run the official `cloudflared` as a single container that exposes your services through a Cloudflare Tunnel — no open/published ports. One declarative compose file. Drop on any host with Docker.

## How it works
- One container (`cloudflare/cloudflared:latest`) per host.
- It joins a Docker network named `shared`. Put your app containers on `shared` too → the tunnel routes to them by container name (`http://<container>:<port>`).
- Reach a service on the host itself (e.g. SSH) via `ssh://host.docker.internal:22`.

## Setup
```bash
docker network create shared      # once per host
cp .env.example .env               # set TUNNEL_TOKEN + CONNECTOR_NAME
docker compose up -d
```
- `TUNNEL_TOKEN` — connector token (dashboard → configure, or `cloudflared tunnel token <id>`).
- `CONNECTOR_NAME` — `cloudflared-<host-id>`.

## Connecting your apps
Add the `shared` network to each app's compose (keep `default` so intra-stack DNS still works):
```yaml
services:
  <svc>:
    networks: [default, shared]
networks:
  shared:
    external: true
```
New containers/replicas then resolve automatically — nothing to list.

Or attach/detach interactively without editing composes:
```bash
./shared-net.sh
```
A TUI that lists every running container with its current `shared` state; mark any to flip (off→attach, on→detach). Uses `fzf` if installed (TAB to multi-select), else a numbered menu. Connector containers are hidden so you can't detach your own tunnel.
One-off without the TUI: `docker network connect shared <container>`.

## Verify
`docker logs <CONNECTOR_NAME>` → expect 4× "Registered tunnel connection"; the tunnel shows healthy in the dashboard.

## High availability
Run this folder on a second host with the same `TUNNEL_TOKEN`. Cloudflare routes to the nearest replica (failover; no load-balancing).
