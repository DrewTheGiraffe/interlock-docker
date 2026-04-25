import os


def csv_env(name: str) -> list[str]:
	return [v.strip() for v in os.environ.get(name, "").split(",") if v.strip()]


def env_bool(name: str, default: bool = False) -> bool:
	value = os.environ.get(name)
	if value is None:
		return default
	return value.strip().lower() in {"1", "true", "yes", "on"}


def host_without_port(value: str) -> str:
	if value.startswith("[") and "]" in value:
		return value[1 : value.index("]")]
	return value.split(":", 1)[0]


PUBLIC_HOST = os.environ.get("INTERLOCK_PUBLIC_HOST", "localhost:8080")
PUBLIC_HOST_ONLY = host_without_port(PUBLIC_HOST)

DEBUG = env_bool("INTERLOCK_DEBUG", False)
FRONT_URL = PUBLIC_HOST
DEV_URL = "127.0.0.1:3000"

DATABASES = {
	"default": {
		"ENGINE": "django.db.backends.postgresql",
		"NAME": os.environ.get("POSTGRES_DB", "interlockdb"),
		"USER": os.environ.get("POSTGRES_USER", "interlockadmin"),
		"PASSWORD": os.environ.get("POSTGRES_PASSWORD", "change-this-postgres-password"),
		"HOST": os.environ.get("POSTGRES_HOST", "db"),
		"PORT": os.environ.get("POSTGRES_PORT", "5432"),
	},
	"test": {
		"NAME": "test_interlockdb",
	},
}

ALLOWED_HOSTS = [
	"localhost",
	"127.0.0.1",
	"backend",
	"gateway",
	PUBLIC_HOST_ONLY,
	*csv_env("INTERLOCK_ALLOWED_HOSTS"),
]
ALLOWED_HOSTS = list(dict.fromkeys(v for v in ALLOWED_HOSTS if v))

DEFAULT_ORIGINS = [
	f"http://{PUBLIC_HOST}",
	f"https://{PUBLIC_HOST}",
	"http://localhost",
	"http://localhost:8080",
	"http://127.0.0.1",
	"http://127.0.0.1:8080",
]

CSRF_TRUSTED_ORIGINS = list(
	dict.fromkeys([*DEFAULT_ORIGINS, *csv_env("INTERLOCK_CSRF_TRUSTED_ORIGINS")])
)
CORS_ALLOWED_ORIGINS = list(
	dict.fromkeys([*DEFAULT_ORIGINS, *csv_env("INTERLOCK_CORS_ALLOWED_ORIGINS")])
)
CORS_ORIGIN_WHITELIST = CORS_ALLOWED_ORIGINS
CORS_ORIGIN_REGEX_WHITELIST = []
CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = False

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True

COOKIE_SECURE = env_bool("INTERLOCK_COOKIE_SECURE", False)
SESSION_COOKIE_SECURE = COOKIE_SECURE
CSRF_COOKIE_SECURE = COOKIE_SECURE
SESSION_COOKIE_SAMESITE = os.environ.get("INTERLOCK_SESSION_COOKIE_SAMESITE", "Lax")
CSRF_COOKIE_SAMESITE = os.environ.get("INTERLOCK_CSRF_COOKIE_SAMESITE", "Lax")

DEFAULT_SUPERUSER_USERNAME = os.environ.get(
	"INTERLOCK_DEFAULT_SUPERUSER_USERNAME",
	"admin",
)
DEFAULT_SUPERUSER_PASSWORD = os.environ.get(
	"INTERLOCK_DEFAULT_SUPERUSER_PASSWORD",
	"interlock",
)

STATIC_ROOT = "/vol/static"
LOG_FILE_FOLDER = "/app/logs"
LOG_FILE_PATH = "/app/logs/interlock.log"

OVERRIDES_JWT = {
	"AUTH_COOKIE_SECURE": COOKIE_SECURE,
	"AUTH_COOKIE_SAME_SITE": os.environ.get("INTERLOCK_AUTH_COOKIE_SAME_SITE", "Lax"),
}
