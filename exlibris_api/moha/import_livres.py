import sqlite3
from pathlib import Path

import pandas as pd

DB_PATH = Path("exlibris.db")
CSV_PATH = Path(r"C:\dev\exlibris_api\data\Preprocessed_data.csv")

# Mapping colonnes CSV -> colonnes SQL
CSV_TO_SQL = {
    "isbn": "isbn",
    "book_title": "titre",
    "book_author": "auteur",
    "year_of_publication": "annee_publication",
    "publisher": "editeur",
    "Summary": "resume",
    "Language": "langue",
    "Category": "categorie",
    "img_s": "image_petite",
    "img_m": "image_moyenne",
    "img_l": "image_grande",
}

def import_livres_from_csv(chunksize: int = 50000):
    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV introuvable : {CSV_PATH}")

    # Colonnes à lire du CSV (on ignore user_id, rating, etc.)
    usecols = list(CSV_TO_SQL.keys())

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    total_rows = 0
    total_isbns = set()  # pour compter grossièrement les livres uniques 

    # Lecture du CSV par chunks
    for i, chunk in enumerate(
        pd.read_csv(
            CSV_PATH,
            usecols=usecols,
            chunksize=chunksize,
            encoding="utf-8",
        )
    ):
        print(f"Chunk {i+1} lu, lignes : {len(chunk)}")

        # Renommer colonnes vers le schéma SQL
        chunk = chunk.rename(columns=CSV_TO_SQL)

        # Supprimer les lignes sans isbn
        chunk = chunk[chunk["isbn"].notna()]

        # Convertir isbn en string propre
        chunk["isbn"] = chunk["isbn"].astype(str).str.strip()

        # Supprimer les doublons dans ce chunk sur isbn
        chunk = chunk.drop_duplicates(subset=["isbn"])

        # Optionnel : garder trace des isbns vus (juste pour info)
        total_rows += len(chunk)
        total_isbns.update(chunk["isbn"].tolist())

        # Préparer les tuples pour insertion
        rows_to_insert = [
            (
                row["isbn"],
                row["titre"],
                row["auteur"] if not pd.isna(row["auteur"]) else None,
                int(row["annee_publication"])
                if not pd.isna(row["annee_publication"])
                else None,
                row["editeur"] if not pd.isna(row["editeur"]) else None,
                row["resume"] if not pd.isna(row["resume"]) else None,
                row["langue"] if not pd.isna(row["langue"]) else None,
                row["categorie"] if not pd.isna(row["categorie"]) else None,
                row["image_petite"] if not pd.isna(row["image_petite"]) else None,
                row["image_moyenne"] if not pd.isna(row["image_moyenne"]) else None,
                row["image_grande"] if not pd.isna(row["image_grande"]) else None,
            )
            for _, row in chunk.iterrows()
        ]

        # Insertion (ISBN est PRIMARY KEY → on utilise INSERT OR IGNORE
        cur.executemany(
            """
            INSERT OR IGNORE INTO Livre (
                isbn, titre, auteur, annee_publication, editeur, resume,
                langue, categorie, image_petite, image_moyenne, image_grande
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows_to_insert,
        )

        conn.commit()
        print(
            f"Chunk {i+1} inséré : {len(rows_to_insert)} lignes (total lignes traitées ≈ {total_rows})"
        )

    conn.close()
    print(f"Import terminé. Nombre approximatif de livres uniques : {len(total_isbns)}")

if __name__ == "__main__":
    import_livres_from_csv(chunksize=50000)
