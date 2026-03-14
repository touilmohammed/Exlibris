import os
import json
from pathlib import Path

import pymysql
import pandas as pd
from dotenv import load_dotenv

from sklearn.feature_extraction.text import TfidfVectorizer
from scipy.sparse import save_npz
import joblib

load_dotenv(".env.local")

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "exlibris")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "exlibris")

BASE_DIR = Path(__file__).parent
ML_DIR = BASE_DIR / "ml"
ML_DIR.mkdir(exist_ok=True)

VECT_PATH = ML_DIR / "tfidf_vectorizer.pkl"
MATRIX_PATH = ML_DIR / "tfidf_matrix.npz"
META_PATH = ML_DIR / "tfidf_meta.json"


def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4",
    )


def load_books():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT
            l.isbn,
            COALESCE(l.titre, '') AS titre,
            COALESCE(l.auteur, '') AS auteur,
            COALESCE(l.editeur, '') AS editeur,
            COALESCE(l.resume, '') AS resume,
            COALESCE(l.langue, '') AS langue,
            COALESCE(c.nomcat, '') AS categorie,
            COALESCE(l.image_moyenne, l.image_petite, '') AS image
        FROM Livre l
        LEFT JOIN Categorie c ON c.id = l.categorie_id
    """)
    rows = cur.fetchall()
    conn.close()

    df = pd.DataFrame(rows)
    if df.empty:
        return df

    # nettoyage minimal
    for col in ["titre", "auteur", "editeur", "resume", "langue", "categorie"]:
        df[col] = df[col].fillna("").astype(str).str.strip()

    # colonnes combinées comme ton collègue
    df["combined"] = (
        df["titre"] + " " +
        df["auteur"] + " " +
        df["editeur"] + " " +
        df["resume"] + " " +
        df["categorie"]
    )

    # éviter doublons ISBN (normalement unique) et titres
    df = df.drop_duplicates(subset=["isbn"], keep="first").reset_index(drop=True)
    return df


def build_and_save():
    df = load_books()
    if df.empty:
        print("Aucun livre trouvé en base (table Livre vide).")
        return

    tfidf = TfidfVectorizer(
        stop_words="english",
        max_features=10000,
        min_df=2,
        max_df=0.8,
    )

    tfidf_matrix = tfidf.fit_transform(df["combined"])

    # save vectorizer
    joblib.dump(tfidf, VECT_PATH)

    # save sparse matrix
    save_npz(MATRIX_PATH, tfidf_matrix)

    # save metadata index -> book info
    meta = df[["isbn", "titre", "auteur", "editeur", "image"]].to_dict(orient="records")
    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    print(f"✅ Sauvegardé : {VECT_PATH}")
    print(f"✅ Sauvegardé : {MATRIX_PATH}")
    print(f"✅ Sauvegardé : {META_PATH}")
    print(f"Livres indexés: {len(df)}")


if __name__ == "__main__":
    build_and_save()
