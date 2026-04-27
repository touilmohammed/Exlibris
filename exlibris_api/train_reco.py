import os
from pathlib import Path

import joblib
import pandas as pd
import pymysql
from dotenv import load_dotenv

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import classification_report, accuracy_score

load_dotenv(".env.local")

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "exlibris")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "exlibris")

BASE_DIR = Path(__file__).parent
ML_DIR = BASE_DIR / "ml"
ML_DIR.mkdir(exist_ok=True)

MODEL_PATH = ML_DIR / "reco_pipeline.pkl"


def get_conn():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4",
    )


def load_explicit_ratings(limit=500000):
    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT
            u.id_utilisateur,
            COALESCE(u.age, 0) AS age,
            COALESCE(u.pays, 'UNK') AS pays,

            l.isbn,
            COALESCE(l.langue, 'UNK') AS langue,
            COALESCE(c.nomcat, 'UNK') AS categorie,
            COALESCE(YEAR(l.date_publication), 0) AS annee_publication,
            COALESCE(l.resume, '') AS resume,

            COALESCE(pop.nb_evaluations, 0) AS popularite,

            COALESCE(user_stats.user_avg_rating, 0) AS user_avg_rating,
            COALESCE(user_stats.user_nb_ratings, 0) AS user_nb_ratings,
            COALESCE(user_col.user_nb_collection, 0) AS user_nb_collection,
            COALESCE(user_wish.user_nb_wishlist, 0) AS user_nb_wishlist,

            CASE WHEN s.id_souhait IS NULL THEN 0 ELSE 1 END AS book_in_user_wishlist,

            COALESCE(cat_col.user_category_collection_count, 0) AS user_category_collection_count,
            COALESCE(cat_wish.user_category_wishlist_count, 0) AS user_category_wishlist_count,

            e.note AS note,
            CASE WHEN e.note >= 4 THEN 1 ELSE 0 END AS liked

        FROM Evaluation e

        JOIN Utilisateur u
            ON u.id_utilisateur = e.utilisateur_id

        JOIN Livre l
            ON l.isbn = e.livre_isbn

        LEFT JOIN Categorie c
            ON c.id = l.categorie_id

        LEFT JOIN Souhait s
            ON s.utilisateur_id = u.id_utilisateur
            AND s.livre_isbn = l.isbn

        LEFT JOIN (
            SELECT livre_isbn, COUNT(*) AS nb_evaluations
            FROM Evaluation
            GROUP BY livre_isbn
        ) pop
            ON pop.livre_isbn = l.isbn

        LEFT JOIN (
            SELECT
                utilisateur_id,
                AVG(note) AS user_avg_rating,
                COUNT(*) AS user_nb_ratings
            FROM Evaluation
            WHERE note IS NOT NULL
            GROUP BY utilisateur_id
        ) user_stats
            ON user_stats.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT utilisateur_id, COUNT(*) AS user_nb_collection
            FROM Collection
            GROUP BY utilisateur_id
        ) user_col
            ON user_col.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT utilisateur_id, COUNT(*) AS user_nb_wishlist
            FROM Souhait
            GROUP BY utilisateur_id
        ) user_wish
            ON user_wish.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT
                col.utilisateur_id,
                lv.categorie_id,
                COUNT(*) AS user_category_collection_count
            FROM Collection col
            JOIN Livre lv ON lv.isbn = col.livre_isbn
            GROUP BY col.utilisateur_id, lv.categorie_id
        ) cat_col
            ON cat_col.utilisateur_id = u.id_utilisateur
            AND cat_col.categorie_id = l.categorie_id

        LEFT JOIN (
            SELECT
                sw.utilisateur_id,
                lv.categorie_id,
                COUNT(*) AS user_category_wishlist_count
            FROM Souhait sw
            JOIN Livre lv ON lv.isbn = sw.livre_isbn
            GROUP BY sw.utilisateur_id, lv.categorie_id
        ) cat_wish
            ON cat_wish.utilisateur_id = u.id_utilisateur
            AND cat_wish.categorie_id = l.categorie_id

        LIMIT %s
        """,
        (limit,),
    )

    rows = cur.fetchall()
    conn.close()
    return pd.DataFrame(rows)


def load_implicit_negatives(max_negatives_per_user=20):
    """
    Crée des exemples négatifs implicites :
    pour chaque utilisateur ayant déjà interagi, on prend des livres
    qu'il n'a ni notés, ni ajoutés en collection, ni ajoutés en wishlist.

    Hypothèse produit :
    absence totale d'interaction ≈ signal faible de non-préférence.
    """
    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT
            u.id_utilisateur,
            COALESCE(u.age, 0) AS age,
            COALESCE(u.pays, 'UNK') AS pays,

            l.isbn,
            COALESCE(l.langue, 'UNK') AS langue,
            COALESCE(c.nomcat, 'UNK') AS categorie,
            COALESCE(YEAR(l.date_publication), 0) AS annee_publication,
            COALESCE(l.resume, '') AS resume,

            COALESCE(pop.nb_evaluations, 0) AS popularite,

            COALESCE(user_stats.user_avg_rating, 0) AS user_avg_rating,
            COALESCE(user_stats.user_nb_ratings, 0) AS user_nb_ratings,
            COALESCE(user_col.user_nb_collection, 0) AS user_nb_collection,
            COALESCE(user_wish.user_nb_wishlist, 0) AS user_nb_wishlist,

            0 AS book_in_user_wishlist,

            COALESCE(cat_col.user_category_collection_count, 0) AS user_category_collection_count,
            COALESCE(cat_wish.user_category_wishlist_count, 0) AS user_category_wishlist_count,

            0 AS note,
            0 AS liked

        FROM Utilisateur u

        JOIN Livre l

        LEFT JOIN Categorie c
            ON c.id = l.categorie_id

        LEFT JOIN Evaluation e
            ON e.utilisateur_id = u.id_utilisateur
            AND e.livre_isbn = l.isbn

        LEFT JOIN Collection col_existing
            ON col_existing.utilisateur_id = u.id_utilisateur
            AND col_existing.livre_isbn = l.isbn

        LEFT JOIN Souhait wish_existing
            ON wish_existing.utilisateur_id = u.id_utilisateur
            AND wish_existing.livre_isbn = l.isbn

        LEFT JOIN (
            SELECT livre_isbn, COUNT(*) AS nb_evaluations
            FROM Evaluation
            GROUP BY livre_isbn
        ) pop
            ON pop.livre_isbn = l.isbn

        LEFT JOIN (
            SELECT
                utilisateur_id,
                AVG(note) AS user_avg_rating,
                COUNT(*) AS user_nb_ratings
            FROM Evaluation
            WHERE note IS NOT NULL
            GROUP BY utilisateur_id
        ) user_stats
            ON user_stats.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT utilisateur_id, COUNT(*) AS user_nb_collection
            FROM Collection
            GROUP BY utilisateur_id
        ) user_col
            ON user_col.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT utilisateur_id, COUNT(*) AS user_nb_wishlist
            FROM Souhait
            GROUP BY utilisateur_id
        ) user_wish
            ON user_wish.utilisateur_id = u.id_utilisateur

        LEFT JOIN (
            SELECT
                col.utilisateur_id,
                lv.categorie_id,
                COUNT(*) AS user_category_collection_count
            FROM Collection col
            JOIN Livre lv ON lv.isbn = col.livre_isbn
            GROUP BY col.utilisateur_id, lv.categorie_id
        ) cat_col
            ON cat_col.utilisateur_id = u.id_utilisateur
            AND cat_col.categorie_id = l.categorie_id

        LEFT JOIN (
            SELECT
                sw.utilisateur_id,
                lv.categorie_id,
                COUNT(*) AS user_category_wishlist_count
            FROM Souhait sw
            JOIN Livre lv ON lv.isbn = sw.livre_isbn
            GROUP BY sw.utilisateur_id, lv.categorie_id
        ) cat_wish
            ON cat_wish.utilisateur_id = u.id_utilisateur
            AND cat_wish.categorie_id = l.categorie_id

        WHERE user_stats.user_nb_ratings IS NOT NULL
          AND e.id_evaluation IS NULL
          AND col_existing.id_collection IS NULL
          AND wish_existing.id_souhait IS NULL
        """
    )

    rows = cur.fetchall()
    conn.close()

    df = pd.DataFrame(rows)

    if df.empty:
        return df

    df = (
        df.groupby("id_utilisateur", group_keys=False)
        .sample(n=min(max_negatives_per_user, len(df)), random_state=42)
        if len(df) > max_negatives_per_user
        else df
    )

    return df


def clean_df(df: pd.DataFrame) -> pd.DataFrame:
    numeric_cols = [
        "age",
        "annee_publication",
        "popularite",
        "user_avg_rating",
        "user_nb_ratings",
        "user_nb_collection",
        "user_nb_wishlist",
        "book_in_user_wishlist",
        "user_category_collection_count",
        "user_category_wishlist_count",
        "note",
        "liked",
    ]

    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

    int_cols = [
        "age",
        "annee_publication",
        "popularite",
        "user_nb_ratings",
        "user_nb_collection",
        "user_nb_wishlist",
        "book_in_user_wishlist",
        "user_category_collection_count",
        "user_category_wishlist_count",
        "note",
        "liked",
    ]

    for col in int_cols:
        df[col] = df[col].astype(int)

    for col in ["pays", "langue", "categorie"]:
        df[col] = df[col].astype(str).replace({"None": "UNK", "nan": "UNK"}).fillna("UNK")
        df[col] = df[col].str.strip()
        df.loc[df[col] == "", col] = "UNK"

    df["resume"] = df["resume"].astype(str).replace({"None": "", "nan": ""}).fillna("")
    df["resume"] = df["resume"].str.strip()

    return df.drop_duplicates(subset=["id_utilisateur", "isbn", "liked"])


def main():
    explicit_df = load_explicit_ratings()
    implicit_negatives_df = load_implicit_negatives(max_negatives_per_user=20)

    if explicit_df.empty:
        raise SystemExit("Aucune donnée d'entraînement : table Evaluation vide.")

    df = pd.concat([explicit_df, implicit_negatives_df], ignore_index=True)
    df = clean_df(df)

    y = df["liked"].astype(int)

    print("Répartition des classes :")
    print(y.value_counts())

    X = df[
        [
            "age",
            "pays",
            "langue",
            "categorie",
            "annee_publication",
            "resume",
            "popularite",
            "user_avg_rating",
            "user_nb_ratings",
            "user_nb_collection",
            "user_nb_wishlist",
            "book_in_user_wishlist",
            "user_category_collection_count",
            "user_category_wishlist_count",
        ]
    ].copy()

    numeric_features = [
        "age",
        "annee_publication",
        "popularite",
        "user_avg_rating",
        "user_nb_ratings",
        "user_nb_collection",
        "user_nb_wishlist",
        "book_in_user_wishlist",
        "user_category_collection_count",
        "user_category_wishlist_count",
    ]

    categorical_features = ["pays", "langue", "categorie"]

    preprocessor = ColumnTransformer(
        transformers=[
            ("num", StandardScaler(), numeric_features),
            ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_features),
            ("txt", TfidfVectorizer(max_features=100), "resume"),
        ],
        remainder="drop",
        sparse_threshold=0.3,
    )

    model = GradientBoostingClassifier(
        n_estimators=160,
        learning_rate=0.06,
        max_depth=3,
        random_state=42,
    )

    pipeline = Pipeline(
        steps=[
            ("prep", preprocessor),
            ("model", model),
        ]
    )

    stratify = y if y.nunique() > 1 else None

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=stratify,
    )

    pipeline.fit(X_train, y_train)
    y_pred = pipeline.predict(X_test)

    print("Accuracy:", accuracy_score(y_test, y_pred))
    print(classification_report(y_test, y_pred, zero_division=0))

    joblib.dump(pipeline, MODEL_PATH)
    print(f"✅ Sauvegardé : {MODEL_PATH}")


if __name__ == "__main__":
    main()