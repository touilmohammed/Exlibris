import smtplib
from email.message import EmailMessage

from core.config import (
    SMTP_HOST,
    SMTP_PORT,
    SMTP_USERNAME,
    SMTP_PASSWORD,
    SMTP_USE_TLS,
    MAIL_FROM,
    MAIL_ENABLED,
)


def send_confirmation_email(to_email: str, username: str, code: str) -> None:
    """
    Envoie un email de confirmation avec un code à 6 chiffres.
    Si MAIL_ENABLED est false, le code est simplement affiché en console.
    """
    if not MAIL_ENABLED:
        print("===================================================")
        print("[EMAIL DEV] Confirmation de compte ExLibris")
        print(f"To: {to_email}")
        print(f"Bonjour {username},")
        print(f"Votre code de confirmation est : {code}")
        print("===================================================")
        return

    msg = EmailMessage()
    msg["Subject"] = "Code de confirmation ExLibris"
    msg["From"] = MAIL_FROM
    msg["To"] = to_email

    msg.set_content(
        f"""Bonjour {username},

Votre code de confirmation ExLibris est : {code}

Ce code expire bientôt.

Si vous n'êtes pas à l'origine de cette inscription, ignorez ce message.

ExLibris
"""
    )

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        if SMTP_USE_TLS:
            server.starttls()

        if SMTP_USERNAME:
            server.login(SMTP_USERNAME, SMTP_PASSWORD)

        server.send_message(msg)