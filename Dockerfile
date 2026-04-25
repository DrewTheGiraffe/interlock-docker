FROM python:3.12-slim-bookworm AS backend-builder

ENV POETRY_VERSION=2.1.3 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libldap2-dev \
        libpq-dev \
        libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "poetry==${POETRY_VERSION}"

COPY backend/pyproject.toml backend/poetry.lock ./
RUN poetry install --only main --no-root --no-ansi

FROM python:3.12-slim-bookworm AS backend

ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POSTGRES_HOST=db \
    POSTGRES_PORT=5432 \
    INTERLOCK_PUBLIC_HOST=localhost:8080 \
    INTERLOCK_COOKIE_SECURE=false \
    INTERLOCK_DEFAULT_SUPERUSER_USERNAME=admin \
    INTERLOCK_DEFAULT_SUPERUSER_PASSWORD=interlock

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gosu \
        libldap-2.5-0 \
        libpq5 \
        libsasl2-2 \
    && rm -rf /var/lib/apt/lists/* \
    && addgroup --system interlock \
    && adduser --system --ingroup interlock interlock

COPY --from=backend-builder /app/.venv /app/.venv
COPY backend/ /app/
COPY docker/backend/local_django_settings.py /app/interlock_backend/local_django_settings.py
COPY docker/backend/interlock-entrypoint.sh /usr/local/bin/interlock-entrypoint.sh

RUN chmod +x /usr/local/bin/interlock-entrypoint.sh \
    && mkdir -p /data /vol/static /app/logs /app/private \
    && chown -R interlock:interlock /app /data /vol

EXPOSE 8000

ENTRYPOINT ["interlock-entrypoint.sh"]
CMD ["gunicorn", "interlock_backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "300", "--access-logfile", "-", "--error-logfile", "-"]

FROM node:18-alpine AS frontend-builder

WORKDIR /src

COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

FROM nginx:1.27-alpine AS gateway

ENV INTERLOCK_BACKEND_PUBLIC_HOST=localhost:8080 \
    INTERLOCK_FRONTEND_SSL=false \
    INTERLOCK_REJECT_UNAUTHORIZED=true

COPY --from=frontend-builder /src/dist /usr/share/nginx/html
COPY docker/gateway/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/gateway/30-runtime-config.sh /docker-entrypoint.d/30-runtime-config.sh

RUN chmod +x /docker-entrypoint.d/30-runtime-config.sh \
    && mkdir -p /usr/share/nginx/html/config /srv/interlock-static

EXPOSE 8080
