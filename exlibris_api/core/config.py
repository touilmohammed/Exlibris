import os
from dotenv import load_dotenv


load_dotenv(".env.local")


def _get_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Variable d'environnement manquante: {name}")
    return value


DB_HOST: str = _get_env("DB_HOST", "127.0.0.1")
DB_PORT: int = int(_get_env("DB_PORT", "3306"))
DB_USER: str = _get_env("DB_USER", "exlibris")
DB_PASSWORD: str = _get_env("DB_PASSWORD", "")
DB_NAME: str = _get_env("DB_NAME", "exlibris")

APP_ENV: str = _get_env("APP_ENV", "dev")

JWT_SECRET_KEY: str = _get_env("JWT_SECRET_KEY", "change_me_super_secret")
JWT_ALGORITHM: str = _get_env("JWT_ALGORITHM", "HS256")
JWT_EXPIRE_MINUTES: int = int(_get_env("JWT_EXPIRE_MINUTES", "1440"))

STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_PUBLISHABLE_KEY = os.getenv("STRIPE_PUBLISHABLE_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")
BACKEND_PUBLIC_URL = os.getenv("BACKEND_PUBLIC_URL", "http://127.0.0.1:8000")

EMAIL_CONFIRMATION_EXPIRE_MINUTES: int = int(
    _get_env("EMAIL_CONFIRMATION_EXPIRE_MINUTES", "30")
)

FRONTEND_BASE_URL: str = _get_env("FRONTEND_BASE_URL", "http://localhost:3000")

ALLOWED_ORIGINS: list[str] = [
    origin.strip()
    for origin in _get_env(
        "ALLOWED_ORIGINS",
        "http://localhost:3000,http://localhost:8080"
    ).split(",")
    if origin.strip()
]

SMTP_HOST: str = _get_env("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT: int = int(_get_env("SMTP_PORT", "587"))
SMTP_USERNAME: str = _get_env("SMTP_USERNAME", "")
SMTP_PASSWORD: str = _get_env("SMTP_PASSWORD", "")
SMTP_USE_TLS: bool = _get_env("SMTP_USE_TLS", "true").lower() == "true"

MAIL_FROM: str = _get_env("MAIL_FROM", "no-reply@exlibris.local")
MAIL_ENABLED: bool = _get_env("MAIL_ENABLED", "false").lower() == "true"