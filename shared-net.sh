#!/usr/bin/env bash
# TUI to toggle running containers on/off the cloudflared `shared` network.
# Pick the containers whose membership you want to flip: off -> attach, on -> detach.
# Uses fzf if installed (TAB = mark multiple), otherwise a numbered menu.
#   override network name: SHARED_NET=othernet ./shared-net.sh
set -uo pipefail
cd "$(dirname "$0")"
NET="${SHARED_NET:-shared}"

command -v docker >/dev/null 2>&1 || { echo "docker not found"; exit 1; }
if ! docker network inspect "$NET" >/dev/null 2>&1; then
  read -rp "network '$NET' does not exist. create it? [y/N] " a
  case "$a" in [yY]*) docker network create "$NET" >/dev/null && echo "created $NET";; *) exit 1;; esac
fi

# never offer to detach the connector(s): any *cloudflared* container, or CONNECTOR_NAME from .env
conn=""; [ -f .env ] && conn="$(grep -E '^CONNECTOR_NAME=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
is_protected(){ case "$1" in *cloudflared*) return 0;; esac; [ -n "$conn" ] && [ "$1" = "$conn" ] && return 0; return 1; }

on_net=" $(docker network inspect "$NET" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null) "
state_of(){ case "$on_net" in *" $1 "*) echo on;; *) echo off;; esac; }

# build "state<TAB>name" rows for running, non-connector containers
rows=""
while read -r c; do
  [ -z "$c" ] && continue
  is_protected "$c" && continue
  rows="${rows}$(state_of "$c")\t${c}\n"
done < <(docker ps --format '{{.Names}}' | sort)
[ -z "$rows" ] && { echo "no togglable running containers."; exit 0; }

echo "shared network: $NET   (on = attached; connector containers hidden)"
picks=""
if command -v fzf >/dev/null 2>&1; then
  picks="$(printf "%b" "$rows" | column -t \
    | fzf --multi --prompt="toggle> " \
          --header=$'TAB mark one/many  -  ENTER apply  (off->attach, on->detach)' \
    | awk '{print $2}')"
else
  echo "current state:"
  i=1; names=""
  while IFS="$(printf '\t')" read -r st nm; do
    [ -z "$nm" ] && continue
    printf "  %2d) [%-3s] %s\n" "$i" "$st" "$nm"
    names="$names $nm"; i=$((i+1))
  done < <(printf "%b" "$rows")
  read -rp "numbers to toggle (space-separated, e.g. 1 3 4): " nums
  # shellcheck disable=SC2086
  set -- $names
  for n in $nums; do eval "picks=\"\$picks \${$n:-}\""; done
fi

[ -z "$(printf '%s' "$picks" | tr -d '[:space:]')" ] && { echo "nothing selected."; exit 0; }

for c in $picks; do
  if [ "$(state_of "$c")" = on ]; then
    docker network disconnect "$NET" "$c" 2>/dev/null && echo "detached  $c" || echo "skip      $c (in use? recreate-managed?)"
  else
    docker network connect "$NET" "$c" 2>/dev/null && echo "attached  $c" || echo "skip      $c"
  fi
done
echo "done — re-run to see the new state."
