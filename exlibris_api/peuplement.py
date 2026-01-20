import csv
import pymysql
from pymysql import MySQLError
from datetime import datetime

# ----------------------------------------------------------
# Connexion DIRECTE à la base MariaDB de PARIS
# ----------------------------------------------------------
def get_connection():
    try:
        conn = pymysql.connect(
            host="87.106.141.247",
            port=3306,
            user="exlibris",       # <-- Mets ici ton vrai user
            password="exlibris2b",     # <-- Mets ici ton vrai password
            database="exlibris",        # <-- Mets ici ta vraie base
            charset="utf8mb4",
            cursorclass=pymysql.cursors.Cursor
        )
        return conn
    except MySQLError as e:
        print("❌ Erreur de connexion MariaDB Paris :", e)
        return None


# ----------------------------------------------------------
# Convertit une date CSV
# - accepte AAAA ou AAAA-MM-JJ
# ----------------------------------------------------------
def to_date(value):
    if not value or value.strip() == "":
        return None

    value = value.strip()

    # Format AAAA
    if len(value) == 4 and value.isdigit():
        return f"{value}-01-01"

    # Format AAAA-MM-JJ
    try:
        datetime.strptime(value, "%Y-%m-%d")
        return value
    except:
        return None


# ----------------------------------------------------------
# IMPORT CSV -> TABLE Livre
# ----------------------------------------------------------
def populate_from_csv(csv_file_path, delimiter=";"):
    conn = get_connection()
    if not conn:
        print("Connexion Paris KO.")
        return

    cursor = conn.cursor()
    inserted = 0

    print(f"📂 Chargement CSV : {csv_file_path}")

    with open(csv_file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=delimiter)

        for row in reader:
            try:
                cursor.execute(
                    """
                    INSERT INTO Livre (
                        isbn, titre, auteur, date_publication,
                        resume, editeur, langue, categorie_id,
                        statut, image_petite, image_moyenne, image_grande
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        row.get("isbn"),
                        row.get("titre"),
                        row.get("auteur"),
                        to_date(row.get("date_publication")),
                        row.get("resume"),
                        row.get("editeur"),
                        row.get("langue"),
                        row.get("categorie_id") or None,
                        row.get("statut") if row.get("statut") in ["disponible", "indisponible"] else "disponible",
                        row.get("image_petite"),
                        row.get("image_moyenne"),
                        row.get("image_grande"),
                    )
                )
                inserted += 1

            except MySQLError as e:
                print("⚠️ Erreur insertion :", e)
                print("   Ligne ignorée :", row)
                continue

    conn.commit()
    cursor.close()
    conn.close()

    print(f"✔ Import terminé sur Paris : {inserted} lignes insérées.")


# ----------------------------------------------------------
# Exécution CLI : python peuplement.py fichier.csv
# ----------------------------------------------------------
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage : python peuplement.py <fichier.csv> [delimiteur]")
        exit(1)

    csv_path = sys.argv[1]
    delimiter = sys.argv[2] if len(sys.argv) >= 3 else ";"

    populate_from_csv(csv_path, delimiter)