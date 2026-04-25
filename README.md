# Interlock Docker Compose

This stack deploys the upstream Interlock frontend and backend with PostgreSQL and a small Nginx gateway that is friendly to pfSense HAProxy.

The root `Dockerfile` contains two build targets:

```text
backend
gateway
```

`coolify.paas.compose.yaml` calls those targets directly, keeping the Compose file focused on runtime wiring instead of image build details.

`windows.noreverseproxy.docker-compose.yaml` is only for local Docker Desktop / pfSense deployments without a Docker-hosted reverse proxy. It publishes the gateway on the Windows host. Coolify should use `coolify.paas.compose.yaml` and expose the `gateway` service through a Coolify domain instead.

## Quick Start

```powershell
Copy-Item .env.example .env
notepad .env
docker compose -f windows.noreverseproxy.docker-compose.yaml up -d --build
```

Open `http://localhost:8080` locally, or `http://<windows-lan-ip>:8080` from another machine unless you changed `INTERLOCK_HTTP_BIND`.

## Coolify

Use the Docker Compose build pack with:

```text
Base Directory: /
Docker Compose Location: coolify.paas.compose.yaml
Service to expose: gateway
Container port: 8080
```

Coolify creates an isolated network for the stack and connects its proxy to that network, so the base Compose file intentionally uses `expose: 8080` instead of publishing a host port.

If your Coolify domain is HTTPS, set these variables in Coolify:

```dotenv
INTERLOCK_FRONTEND_SSL=true
INTERLOCK_COOKIE_SECURE=true
```

If you want the original no-SSL behavior in Coolify, use an HTTP-only Coolify domain and leave both values as `false`.

Important Git note: `frontend` and `backend` are cloned upstream repositories. Before deploying this from a parent Git repository, either remove their inner `.git` directories so the source is vendored into this repo, or configure them as real Git submodules and make sure Coolify checks out submodules.

## pfSense HAProxy

Point HAProxy at the Windows/Docker host LAN IP on the published port, normally `8080`, using plain HTTP to the Docker stack. This port publishing comes from `windows.noreverseproxy.docker-compose.yaml`. You do not need to connect HAProxy to a Docker network unless HAProxy itself is another Docker container on the same host. Configure HAProxy to preserve or add these headers:

```text
Host
X-Forwarded-For
X-Forwarded-Host
X-Forwarded-Port
X-Forwarded-Proto
```

If HAProxy terminates HTTPS for browsers, set these in `.env`:

```dotenv
INTERLOCK_FRONTEND_SSL=true
INTERLOCK_COOKIE_SECURE=true
```

For a completely non-SSL deployment, leave both values as `false` and expose HAProxy over HTTP. Mixing HTTPS in the browser with a frontend configured for HTTP backend calls will trigger browser mixed-content blocking.

## Windows / WSL2 Notes

The stack uses Linux containers, named Docker volumes, and no host networking so it works with Docker Desktop on Windows Home/WSL2. Named volumes keep PostgreSQL data and Django/Fernet keys off the slower Windows bind-mount path.

`INTERLOCK_HTTP_BIND=0.0.0.0:8080` publishes the gateway on all Windows host interfaces. If another machine cannot reach it, check Windows Defender Firewall and confirm Docker Desktop is using Linux containers.

## First LDAP Setup

The Home page only shows LDAP status. LDAP is configured from the `Settings` view.

1. Open `/settings` in the app.
2. In `Interlock Settings`, enable `Enable LDAP Back-End`.
3. Save once so the LDAP section becomes active.
4. Expand `LDAP Back-End Settings`, fill in the LDAP connection values, then use `Test LDAP Settings`.
5. Save again after the test succeeds.

Until `Enable LDAP Back-End` is turned on, the LDAP navigation group and LDAP health indicators will stay disabled by design.

## Services

`gateway` is the only service that should be exposed to pfSense. It serves the compiled Vue frontend and routes `/api`, `/admin`, `/openid`, `/.well-known`, and `/static` to the right backend/static targets.

`backend` runs Django through Gunicorn, applies migrations on startup, creates the default superuser if missing, creates the RSA key if missing, and collects static files into a shared volume.

`db` is PostgreSQL on an internal Docker network only.
