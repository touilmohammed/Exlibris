from core.database import get_db_connection
from core.security import hash_password


def migrate_password_hashes() -> None:
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute("""
            SELECT id_utilisateur, mot_de_passe
            FROM Utilisateur
            WHERE mot_de_passe_hash IS NULL
              AND mot_de_passe IS NOT NULL
        """)
        rows = cur.fetchall()

        migrated_count = 0

        for user_id, plain_password in rows:
            hashed = hash_password(plain_password)

            cur.execute("""
                UPDATE Utilisateur
                SET mot_de_passe_hash = %s
                WHERE id_utilisateur = %s
            """, (hashed, user_id))

            migrated_count += 1

        conn.commit()
        print(f"[OK] {migrated_count} mot(s) de passe migré(s).")

    except Exception as exc:
        conn.rollback()
        print(f"[ERREUR] Migration annulée: {exc}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    migrate_password_hashes()