import joblib
import numpy as np
import pandas as pd
import pymysql

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import classification_report, accuracy_score

DB_HOST = "87.106.141.247"
DB_PORT = 3306
DB_USER = "exlibris"
DB_PASSWORD = "exlibris2b"
DB_NAME = "exlibris"

def get_conn():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
    )

def load_training_data(limit=500000):
    """
    Dataset d'entraînement basé sur les évaluations réelles:
    Utilisateur(age, pays) + Livre(langue, categorie, année, résumé) -> note
    """
    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT
            u.id_utilisateur,
            u.age AS age,
            u.pays AS pays,
            l.isbn,
            l.langue AS langue,
            c.nomcat AS categorie,
            YEAR(l.date_publication) AS annee_publication,
            l.resume AS resume,
            e.note AS note
        FROM Evaluation e
        JOIN Utilisateur u ON u.id_utilisateur = e.utilisateur_id
        JOIN Livre l ON l.isbn = e.livre_isbn
        LEFT JOIN Categorie c ON c.id = l.categorie_id
        LIMIT %s
        """,
        (limit,),
    )
    rows = cur.fetchall()
    conn.close()
    return pd.DataFrame(rows)

def clean_df(df: pd.DataFrame) -> pd.DataFrame:
    """
    Nettoyage inspiré du notebook:
    - suppression lignes avec manquants critiques
    - normalisation types
    - valeurs par défaut (UNK/0)
    """
    # Colonnes critiques pour apprendre correctement
    critical = ["age", "pays", "langue", "categorie", "annee_publication", "resume", "note"]
    df = df.dropna(subset=critical)

    # Cast / nettoyage texte
    df["age"] = pd.to_numeric(df["age"], errors="coerce").fillna(0).astype(int)
    df["annee_publication"] = pd.to_numeric(df["annee_publication"], errors="coerce").fillna(0).astype(int)
    df["note"] = pd.to_numeric(df["note"], errors="coerce").fillna(0).astype(int)

    # Remplacer valeurs manquantes / vides par UNK
    for col in ["pays", "langue", "categorie"]:
        df[col] = df[col].astype(str).replace({"None": "UNK", "nan": "UNK"}).fillna("UNK")
        df[col] = df[col].str.strip()
        df.loc[df[col] == "", col] = "UNK"

    # Résumé texte
    df["resume"] = df["resume"].astype(str).replace({"None": "", "nan": ""}).fillna("")
    df["resume"] = df["resume"].str.strip()

    # Dédoublonnage (si répétitions exactes)
    df = df.drop_duplicates()

    return df

def main():
    df = load_training_data()
    if df.empty:
        raise SystemExit("Aucune donnée d'entraînement: table Evaluation vide.")

    df = clean_df(df)

    # Target binaire "like"
    # NOTE: votre DB est 0..10 actuellement. Si vous passez à 0..5, garde >=4.
    y = (df["note"] >= 4).astype(int)

    X = df[["age", "pays", "langue", "categorie", "annee_publication", "resume"]].copy()

    numeric_features = ["age", "annee_publication"]
    categorical_features = ["pays", "langue", "categorie"]
    text_feature = "resume"

    # Preprocessing stable (gère valeurs inconnues)
    preprocessor = ColumnTransformer(
        transformers=[
            ("num", StandardScaler(), numeric_features),
            ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_features),
            ("txt", TfidfVectorizer(max_features=100), text_feature),
        ],
        remainder="drop",
        sparse_threshold=0.3,
    )

    model = GradientBoostingClassifier(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=3,
        random_state=42,
    )

    pipeline = Pipeline(steps=[
        ("prep", preprocessor),
        ("model", model),
    ])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    pipeline.fit(X_train, y_train)
    y_pred = pipeline.predict(X_test)

    print("Accuracy:", accuracy_score(y_test, y_pred))
    print(classification_report(y_test, y_pred))

    joblib.dump(pipeline, "reco_pipeline.pkl")
    print("✅ Sauvegardé : reco_pipeline.pkl (pipeline complet prêt pour API)")

if __name__ == "__main__":
    main()
