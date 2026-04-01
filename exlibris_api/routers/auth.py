from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException

from core.database import get_db_connection
from core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_email_verification_code,
)
from core.config import EMAIL_CONFIRMATION_EXPIRE_MINUTES
from services.email_service import send_confirmation_email
from schemas.auth import SignUpBody, LoginBody, ConfirmBody, ResendConfirmationBody


router = APIRouter(prefix="/auth", tags=["auth"])


def utc_now_naive() -> datetime:
    """
    Retourne un datetime UTC naïf.
    Compatible avec les DATETIME MariaDB renvoyés par pymysql.
    """
    return datetime.now(UTC).replace(tzinfo=None)


@router.post("/signup")
def signup(body: SignUpBody):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute("SELECT 1 FROM Utilisateur WHERE email = %s", (body.email,))
        if cur.fetchone():
            raise HTTPException(status_code=409, detail="Email déjà utilisé")

        hashed_password = hash_password(body.mot_de_passe)

        cur.execute(
            """
            INSERT INTO Utilisateur (
                nom_utilisateur,
                email,
                mot_de_passe,
                mot_de_passe_hash,
                email_verifie
            )
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                body.nom_utilisateur,
                body.email,
                "",
                hashed_password,
                0,
            ),
        )
        user_id = cur.lastrowid

        code = create_email_verification_code()
        expires_at = utc_now_naive() + timedelta(minutes=EMAIL_CONFIRMATION_EXPIRE_MINUTES)

        cur.execute(
            """
            UPDATE email_verification
            SET used_at = %s
            WHERE user_id = %s AND used_at IS NULL
            """,
            (utc_now_naive(), user_id),
        )

        cur.execute(
            """
            INSERT INTO email_verification (user_id, code, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user_id, code, expires_at),
        )

        conn.commit()

        send_confirmation_email(
            to_email=body.email,
            username=body.nom_utilisateur,
            code=code,
        )

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return {
        "ok": True,
        "user_id": user_id,
        "message": "Compte créé. Veuillez confirmer votre email.",
    }


@router.post("/login")
def login(body: LoginBody):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT id_utilisateur, mot_de_passe_hash, email_verifie
            FROM Utilisateur
            WHERE email = %s
            """,
            (body.email,),
        )
        row = cur.fetchone()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    user_id, stored_hash, email_verifie = row

    if not stored_hash or not verify_password(body.mot_de_passe, stored_hash):
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    if int(email_verifie) != 1:
        raise HTTPException(status_code=403, detail="Email non confirmé")

    token = create_access_token({"sub": str(user_id)})
    return {"token": token, "user_id": user_id}


@router.post("/confirm")
def confirm(body: ConfirmBody):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT id_utilisateur, email_verifie
            FROM Utilisateur
            WHERE email = %s
            """,
            (body.email,),
        )
        user_row = cur.fetchone()

        if not user_row:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        user_id, email_verifie = user_row

        if int(email_verifie) == 1:
            return {"ok": True, "message": "Email déjà confirmé"}

        cur.execute(
            """
            SELECT id, expires_at, used_at
            FROM email_verification
            WHERE user_id = %s AND code = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (user_id, body.code),
        )
        code_row = cur.fetchone()

        if not code_row:
            raise HTTPException(status_code=400, detail="Code invalide")

        verification_id, expires_at, used_at = code_row

        if used_at is not None:
            raise HTTPException(status_code=400, detail="Code déjà utilisé")

        if expires_at < utc_now_naive():
            raise HTTPException(status_code=400, detail="Code expiré")

        cur.execute(
            """
            UPDATE Utilisateur
            SET email_verifie = 1
            WHERE id_utilisateur = %s
            """,
            (user_id,),
        )

        cur.execute(
            """
            UPDATE email_verification
            SET used_at = %s
            WHERE id = %s
            """,
            (utc_now_naive(), verification_id),
        )

        conn.commit()

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return {"ok": True, "message": "Email confirmé"}


@router.post("/resend-confirmation")
def resend_confirmation(body: ResendConfirmationBody):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT id_utilisateur, nom_utilisateur, email_verifie
            FROM Utilisateur
            WHERE email = %s
            """,
            (body.email,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        user_id, nom_utilisateur, email_verifie = row

        if int(email_verifie) == 1:
            return {"ok": True, "message": "Email déjà confirmé"}

        code = create_email_verification_code()
        expires_at = utc_now_naive() + timedelta(minutes=EMAIL_CONFIRMATION_EXPIRE_MINUTES)

        cur.execute(
            """
            UPDATE email_verification
            SET used_at = %s
            WHERE user_id = %s AND used_at IS NULL
            """,
            (utc_now_naive(), user_id),
        )

        cur.execute(
            """
            INSERT INTO email_verification (user_id, code, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user_id, code, expires_at),
        )

        conn.commit()

        send_confirmation_email(
            to_email=body.email,
            username=nom_utilisateur,
            code=code,
        )

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return {"ok": True, "message": "Code renvoyé"}