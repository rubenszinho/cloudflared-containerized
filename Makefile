# cloudflared connector — one command per box: `make up`
# Network name comes from SHARED_NET in .env (default: shared).
NET := $(shell grep -E '^SHARED_NET=' .env 2>/dev/null | cut -d= -f2- | tr -d '"')
NET := $(if $(NET),$(NET),shared)

.PHONY: up down restart logs net ps

up:        ## create the shared network if missing, then start the connector
	@[ -f .env ] || { echo "no .env — run: cp env.example .env  (or cp .env.<host> .env)"; exit 1; }
	@docker network create $(NET) 2>/dev/null && echo "created network $(NET)" || true
	docker compose up -d

down:      ## stop the connector (the shared network is left intact)
	docker compose down

restart: up   ## recreate the connector

logs:      ## follow connector logs
	docker compose logs -f --tail=20

net:       ## TUI to attach/detach app containers to the shared network
	./shared-net.sh

ps:        ## connector status
	docker compose ps
