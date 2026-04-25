#!/bin/sh
set -eu

mkdir -p /data/secrets /vol/static /app/logs /app/private

if [ "$(id -u)" = "0" ]; then
	chown -R interlock:interlock /data /vol /app/logs /app/private /app/interlock_backend
	exec gosu interlock "$0" "$@"
fi

python - <<'PY'
import os
from pathlib import Path

from cryptography.fernet import Fernet
from django.core.management.utils import get_random_secret_key

secret_dir = Path("/data/secrets")
secret_dir.mkdir(parents=True, exist_ok=True)

django_key_file = secret_dir / "django_key.py"
if not django_key_file.exists():
    secret_key = os.environ.get("INTERLOCK_DJANGO_SECRET_KEY") or get_random_secret_key()
    django_key_file.write_text(f"SECRET_KEY = {secret_key!r}\n")

fernet_key_file = secret_dir / "fernet_key.py"
if not fernet_key_file.exists():
    fernet_key = os.environ.get("INTERLOCK_FERNET_KEY")
    if fernet_key:
        fernet_key_bytes = fernet_key.encode("utf-8")
    else:
        fernet_key_bytes = Fernet.generate_key()
    fernet_key_file.write_text(f"FERNET_KEY = {fernet_key_bytes!r}\n")
PY

cp /data/secrets/django_key.py /app/interlock_backend/django_key.py
cp /data/secrets/fernet_key.py /app/interlock_backend/fernet_key.py

python - <<'PY'
import os
import socket
import time

host = os.environ.get("POSTGRES_HOST", "db")
port = int(os.environ.get("POSTGRES_PORT", "5432"))
deadline = time.time() + 120

while True:
    try:
        with socket.create_connection((host, port), timeout=5):
            break
    except OSError:
        if time.time() > deadline:
            raise
        print(f"Waiting for PostgreSQL at {host}:{port}...")
        time.sleep(2)
PY

python manage.py migrate --noinput
python manage.py shell < install/create_rsa_key.py
python manage.py collectstatic --noinput --clear

exec "$@"
