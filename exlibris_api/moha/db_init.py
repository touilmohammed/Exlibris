from pathlib import Path
import sqlite3

DB_PATH = Path("exlibris.db")


def main() -> None:
    # Connexion (créera le fichier s'il n'existe pas)
    conn = sqlite3.connect(DB_PATH)
    # Très important pour que les FOREIGN KEY fonctionnent
    conn.execute("PRAGMA foreign_keys = ON")

    schema_file = Path("schema.sql")
    if not schema_file.exists():
        raise FileNotFoundError(f"schema.sql introuvable à {schema_file.resolve()}")

    with schema_file.open("r", encoding="utf-8") as f:
        sql = f.read()

    # exec tout le schéma d'un coup
    conn.executescript(sql)
    conn.commit()
    conn.close()

    print("Schéma appliqué sur :", DB_PATH.resolve())


if __name__ == "__main__":
    main()
