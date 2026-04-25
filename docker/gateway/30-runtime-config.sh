#!/bin/sh
set -eu

mkdir -p /usr/share/nginx/html/config

python_bool() {
	case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes|on) printf "true" ;;
		*) printf "false" ;;
	esac
}

BACKEND_PUBLIC_HOST="${INTERLOCK_BACKEND_PUBLIC_HOST:-localhost:8080}"
FRONTEND_SSL="$(python_bool "${INTERLOCK_FRONTEND_SSL:-false}")"
REJECT_UNAUTHORIZED="$(python_bool "${INTERLOCK_REJECT_UNAUTHORIZED:-true}")"

cat > /usr/share/nginx/html/config/local.json <<EOF
{
  "backend_url": "${BACKEND_PUBLIC_HOST}",
  "ssl": ${FRONTEND_SSL},
  "reject_unauthorized": ${REJECT_UNAUTHORIZED},
  "version": "Docker Compose"
}
EOF
