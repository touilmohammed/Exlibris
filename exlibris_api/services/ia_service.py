from pathlib import Path
from typing import Optional
import json
import subprocess
import sys
import threading

import joblib
import pandas as pd
from scipy.sparse import load_npz
from sklearn.metrics.pairwise import linear_kernel
from fastapi import HTTPException

from core.database import get_db_connection
from services.notification_service import create_notification, notify_users

BASE_DIR = Path(__file__).resolve().parents[1]
ML_DIR = BASE_DIR / "ml"
ML_DIR.mkdir(exist_ok=True)

ML_PATH = ML_DIR / "reco_pipeline.pkl"
TFIDF_VECT_PATH = ML_DIR / "tfidf_vectorizer.pkl"
TFIDF_MATRIX_PATH = ML_DIR / "tfidf_matrix.npz"
TFIDF_META_PATH = ML_DIR / "tfidf_meta.json"
EVENTS_PATH = ML_DIR / "ia_events.json"

ML_PIPELINE = None
TFIDF_VECT = None
TFIDF_MATRIX = None
TFIDF_META = None

_LOCK = threading.Lock()


def load_models():
    global ML_PIPELINE, TFIDF_VECT, TFIDF_MATRIX, TFIDF_META

    with _LOCK:
        try:
            ML_PIPELINE = joblib.load(ML_PATH)
            print("[IA] Modèle personnalisé chargé.")
        except Exception as e:
            ML_PIPELINE = None
            print(f"[IA] Modèle personnalisé indisponible: {e}")

        try:
            TFIDF_VECT = joblib.load(TFIDF_VECT_PATH)
            TFIDF_MATRIX = load_npz(TFIDF_MATRIX_PATH)
            with open(TFIDF_META_PATH, "r", encoding="utf-8") as f:
                TFIDF_META = json.load(f)
            print("[IA] Modèle TF-IDF chargé.")
        except Exception as e:
            TFIDF_VECT = None
            TFIDF_MATRIX = None
            TFIDF_META = None
            print(f"[IA] Modèle TF-IDF indisponible: {e}")


def get_status():
    return {
        "personalized_model": {
            "available": ML_PIPELINE is not None,
            "path": str(ML_PATH),
            "exists": ML_PATH.exists(),
        },
        "similarity_model": {
            "available": TFIDF_MATRIX is not None and TFIDF_META is not None,
            "vectorizer_exists": TFIDF_VECT_PATH.exists(),
            "matrix_exists": TFIDF_MATRIX_PATH.exists(),
            "meta_exists": TFIDF_META_PATH.exists(),
            "indexed_books": len(TFIDF_META) if TFIDF_META else 0,
        },
    }


def compute_content_affinity_scores(user_id: int, candidate_isbns: list[str], cur):
    """
    Calcule un score de similarité entre les livres candidats
    et les livres déjà appréciés / possédés / souhaités par l'utilisateur.

    Sources positives :
    - livres notés >= 4
    - livres en collection
    - livres en wishlist
    """
    if TFIDF_MATRIX is None or TFIDF_META is None:
        return {isbn: 0.0 for isbn in candidate_isbns}

    isbn_to_idx = {
        str(item.get("isbn")): i
        for i, item in enumerate(TFIDF_META)
    }

    cur.execute("""
        SELECT livre_isbn
        FROM Evaluation
        WHERE utilisateur_id = %s AND note >= 4

        UNION

        SELECT livre_isbn
        FROM Collection
        WHERE utilisateur_id = %s

        UNION

        SELECT livre_isbn
        FROM Souhait
        WHERE utilisateur_id = %s
    """, (user_id, user_id, user_id))

    positive_isbns = [str(r[0]) for r in cur.fetchall()]

    positive_indices = [
        isbn_to_idx[isbn]
        for isbn in positive_isbns
        if isbn in isbn_to_idx
    ]

    if not positive_indices:
        return {isbn: 0.0 for isbn in candidate_isbns}

    affinity_scores = {}

    for isbn in candidate_isbns:
        isbn_str = str(isbn)

        if isbn_str not in isbn_to_idx:
            affinity_scores[isbn_str] = 0.0
            continue

        candidate_idx = isbn_to_idx[isbn_str]

        similarities = linear_kernel(
            TFIDF_MATRIX[candidate_idx],
            TFIDF_MATRIX[positive_indices],
        ).flatten()

        affinity_scores[isbn_str] = float(similarities.max()) if len(similarities) > 0 else 0.0

    return affinity_scores


def recommend_for_user(user_id: int, limit: int = 10):
    if ML_PIPELINE is None:
        raise HTTPException(status_code=503, detail="Modèle IA personnalisé non disponible.")

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute("""
            SELECT
                COALESCE(u.age, 0),
                COALESCE(u.pays, 'UNK'),
                COALESCE(user_stats.user_avg_rating, 0),
                COALESCE(user_stats.user_nb_ratings, 0),
                COALESCE(user_col.user_nb_collection, 0),
                COALESCE(user_wish.user_nb_wishlist, 0)
            FROM Utilisateur u
            LEFT JOIN (
                SELECT utilisateur_id, AVG(note) AS user_avg_rating, COUNT(*) AS user_nb_ratings
                FROM Evaluation
                WHERE note IS NOT NULL
                GROUP BY utilisateur_id
            ) user_stats ON user_stats.utilisateur_id = u.id_utilisateur
            LEFT JOIN (
                SELECT utilisateur_id, COUNT(*) AS user_nb_collection
                FROM Collection
                GROUP BY utilisateur_id
            ) user_col ON user_col.utilisateur_id = u.id_utilisateur
            LEFT JOIN (
                SELECT utilisateur_id, COUNT(*) AS user_nb_wishlist
                FROM Souhait
                GROUP BY utilisateur_id
            ) user_wish ON user_wish.utilisateur_id = u.id_utilisateur
            WHERE u.id_utilisateur = %s
        """, (user_id,))

        u = cur.fetchone()

        if not u:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable.")

        age = int(u[0] or 0)
        pays = str(u[1] or "UNK")
        user_avg_rating = float(u[2] or 0)
        user_nb_ratings = int(u[3] or 0)
        user_nb_collection = int(u[4] or 0)
        user_nb_wishlist = int(u[5] or 0)

        cur.execute("SELECT livre_isbn FROM Collection WHERE utilisateur_id = %s", (user_id,))
        owned = {r[0] for r in cur.fetchall()}

        cur.execute("SELECT livre_isbn FROM Souhait WHERE utilisateur_id = %s", (user_id,))
        wished = {r[0] for r in cur.fetchall()}

        cur.execute("""
            SELECT
                l.isbn,
                l.titre,
                COALESCE(l.auteur, ''),
                COALESCE(l.langue, 'UNK'),
                COALESCE(c.nomcat, 'UNK'),
                COALESCE(YEAR(l.date_publication), 0),
                COALESCE(l.resume, ''),
                COALESCE(pop.nb_evaluations, 0),
                COALESCE(cat_col.user_category_collection_count, 0),
                COALESCE(cat_wish.user_category_wishlist_count, 0),
                l.image_petite,
                l.editeur
            FROM Livre l
            LEFT JOIN Categorie c ON c.id = l.categorie_id
            LEFT JOIN (
                SELECT livre_isbn, COUNT(*) AS nb_evaluations
                FROM Evaluation
                GROUP BY livre_isbn
            ) pop ON pop.livre_isbn = l.isbn
            LEFT JOIN (
                SELECT col.utilisateur_id, lv.categorie_id, COUNT(*) AS user_category_collection_count
                FROM Collection col
                JOIN Livre lv ON lv.isbn = col.livre_isbn
                WHERE col.utilisateur_id = %s
                GROUP BY col.utilisateur_id, lv.categorie_id
            ) cat_col ON cat_col.categorie_id = l.categorie_id
            LEFT JOIN (
                SELECT sw.utilisateur_id, lv.categorie_id, COUNT(*) AS user_category_wishlist_count
                FROM Souhait sw
                JOIN Livre lv ON lv.isbn = sw.livre_isbn
                WHERE sw.utilisateur_id = %s
                GROUP BY sw.utilisateur_id, lv.categorie_id
            ) cat_wish ON cat_wish.categorie_id = l.categorie_id
            ORDER BY l.date_publication DESC
            LIMIT 500
        """, (user_id, user_id))

        books = cur.fetchall()
        candidates = [b for b in books if b[0] not in owned]
        candidate_isbns = [str(b[0]) for b in candidates]

        content_scores = compute_content_affinity_scores(
            user_id=user_id,
            candidate_isbns=candidate_isbns,
            cur=cur,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    if not candidates:
        return []

    X = pd.DataFrame([
        {
            "age": age,
            "pays": pays,
            "langue": b[3],
            "categorie": b[4],
            "annee_publication": int(b[5] or 0),
            "resume": b[6],
            "popularite": int(b[7] or 0),
            "user_avg_rating": user_avg_rating,
            "user_nb_ratings": user_nb_ratings,
            "user_nb_collection": user_nb_collection,
            "user_nb_wishlist": user_nb_wishlist,
            "book_in_user_wishlist": 1 if b[0] in wished else 0,
            "user_category_collection_count": int(b[8] or 0),
            "user_category_wishlist_count": int(b[9] or 0),
        }
        for b in candidates
    ])

    personalized_scores = ML_PIPELINE.predict_proba(X)[:, 1]

    scored = []

    for i, b in enumerate(candidates):
        isbn = str(b[0])

        personalized_score = float(personalized_scores[i])
        content_score = float(content_scores.get(isbn, 0.0))

        final_score = (0.70 * personalized_score) + (0.30 * content_score)

        scored.append({
            "isbn": b[0],
            "titre": b[1],
            "auteur": b[2],
            "langue": b[3],
            "categorie": b[4],
            "resume": b[6],
            "image_petite": b[10],
            "editeur": b[11],
            "score": round(final_score, 4),
        })

    scored.sort(key=lambda x: x["score"], reverse=True)

    return scored[:max(1, limit)]


def similar_books(isbn: str, limit: int = 6):
    if TFIDF_MATRIX is None or TFIDF_META is None:
        raise HTTPException(status_code=503, detail="Modèle TF-IDF non disponible.")

    idx = None

    for i, item in enumerate(TFIDF_META):
        if str(item.get("isbn")) == str(isbn):
            idx = i
            break

    if idx is None:
        raise HTTPException(status_code=404, detail="ISBN introuvable dans l'index TF-IDF.")

    sims = linear_kernel(TFIDF_MATRIX[idx], TFIDF_MATRIX).flatten()
    order = sims.argsort()[::-1]

    results = []

    for j in order:
        if j == idx:
            continue

        item = TFIDF_META[int(j)]

        results.append({
            "isbn": item.get("isbn", ""),
            "titre": item.get("titre", ""),
            "auteur": item.get("auteur", ""),
            "editeur": item.get("editeur"),
            "image": item.get("image"),
            "similarity": round(float(sims[int(j)]), 4),
        })

        if len(results) >= max(1, limit):
            break

    return results


def retrain_models(model: str = "all"):
    """
    model:
    - all
    - personalized
    - content
    """
    if model not in ["all", "personalized", "content"]:
        raise ValueError("model doit être: all, personalized ou content")

    if model in ["all", "personalized"]:
        subprocess.run(
            [sys.executable, str(BASE_DIR / "train_reco.py")],
            cwd=str(BASE_DIR),
            check=True,
        )

    if model in ["all", "content"]:
        subprocess.run(
            [sys.executable, str(BASE_DIR / "train_reco_content.py")],
            cwd=str(BASE_DIR),
            check=True,
        )

    load_models()
    reset_events()

    user_ids = _get_all_user_ids()
    if user_ids:
        def _factory(_: int):
            return create_notification(
                event_type="recommendations_ready",
                title="Nouvelles recommandations",
                message="De nouvelles recommandations sont disponibles.",
                data={"model": model},
            )

        notify_users(user_ids, _factory)

    print(f"[IA] Réentraînement terminé: {model}")


def _get_all_user_ids() -> list[int]:
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id_utilisateur FROM Utilisateur")
        rows = cur.fetchall()
        return [int(row[0]) for row in rows]
    except Exception:
        return []
    finally:
        conn.close()


def _default_events():
    return {
        "collection_add": 0,
        "wishlist_add": 0,
        "rating_add": 0,
        "catalog_update": 0,
        "book_import": 0,
    }


def read_events():
    if not EVENTS_PATH.exists():
        return _default_events()

    try:
        with open(EVENTS_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = _default_events()

    for key, value in _default_events().items():
        data.setdefault(key, value)

    return data


def save_events(events: dict):
    with open(EVENTS_PATH, "w", encoding="utf-8") as f:
        json.dump(events, f, ensure_ascii=False, indent=2)


def reset_events():
    save_events(_default_events())


def notify_interaction(event_type: str):
    """
    Logique de réentraînement:
    - rating_add impacte directement le modèle personnalisé.
    - catalog_update/book_import impacte le modèle TF-IDF.
    - wishlist_add/collection_add sont comptés mais ne réentraînent pas encore,
      car le modèle actuel utilise surtout les évaluations.
    """
    if event_type not in _default_events():
        raise HTTPException(status_code=400, detail="Type d'événement IA invalide.")

    events = read_events()
    events[event_type] += 1
    save_events(events)

    scheduled_model: Optional[str] = None

    if events["rating_add"] >= 20:
        scheduled_model = "personalized"

    if events["catalog_update"] >= 1 or events["book_import"] >= 50:
        scheduled_model = "content"

    return {
        "ok": True,
        "events": events,
        "should_retrain": scheduled_model is not None,
        "model_to_retrain": scheduled_model,
        "note": "Les wishlist/collections sont comptées, mais le modèle actuel se réentraîne surtout avec les évaluations.",
    }
