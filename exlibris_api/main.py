from fastapi import FastAPI, HTTPException, Query, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import pymysql
import os
from dotenv import load_dotenv
import joblib
from pathlib import Path
import pandas as pd
import json
from scipy.sparse import load_npz
from sklearn.metrics.pairwise import linear_kernel

# Charger les variables d'environnement depuis .env.local
load_dotenv('.env.local')

# --------------------------------------------------------------------
# Config BDD MariaDB (depuis .env)
# --------------------------------------------------------------------
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "exlibris")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "exlibris")



ML_PIPELINE = None
ML_PATH = Path(__file__).parent / "ml" / "reco_pipeline.pkl"

TFIDF_VECT = None
TFIDF_MATRIX = None
TFIDF_META = None

TFIDF_VECT_PATH = Path(__file__).parent / "ml" / "tfidf_vectorizer.pkl"
TFIDF_MATRIX_PATH = Path(__file__).parent / "ml" / "tfidf_matrix.npz"
TFIDF_META_PATH = Path(__file__).parent / "ml" / "tfidf_meta.json"

def get_db_connection():
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            cursorclass=pymysql.cursors.Cursor,
        )
        return conn
    except Exception as e:
        raise RuntimeError(f"Erreur de connexion MariaDB: {e}")


# --------------------------------------------------------------------
# App FastAPI + CORS
# --------------------------------------------------------------------
app = FastAPI(
    title="ExLibris",
    description="Api Exlibris.",
    version="1.0.0",
    root_path="/exlibris-api",
)

@app.on_event("startup")
def load_ml():
    global ML_PIPELINE
    try:
        ML_PIPELINE = joblib.load(ML_PATH)
        print("[ML] reco_pipeline chargé.")
    except Exception as e:
        ML_PIPELINE = None
        print(f"[ML] Impossible de charger le modèle: {e}")
        # --- Charger modèle TF-IDF (content-based) ---
    global TFIDF_VECT, TFIDF_MATRIX, TFIDF_META
    try:
        TFIDF_VECT = joblib.load(TFIDF_VECT_PATH)
        TFIDF_MATRIX = load_npz(TFIDF_MATRIX_PATH)
        with open(TFIDF_META_PATH, "r", encoding="utf-8") as f:
            TFIDF_META = json.load(f)
        print("[ML] TFIDF modèle livres chargé.")
    except Exception as e:
        TFIDF_VECT = None
        TFIDF_MATRIX = None
        TFIDF_META = None
        print(f"[ML] Impossible de charger TFIDF: {e}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # à restreindre plus tard si besoin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------------------------
# Modèles Pydantic
# --------------------------------------------------------------------
class SignUpBody(BaseModel):
    email: EmailStr
    nom_utilisateur: str
    mot_de_passe: str  # ⚠️ en prod : ne jamais stocker en clair


class LoginBody(BaseModel):
    email: EmailStr
    mot_de_passe: str


class ConfirmBody(BaseModel):
    token: str


class UserProfile(BaseModel):
    id: int
    nom_utilisateur: str
    email: str
    avatar_url: Optional[str] = None
    nb_livres_collection: int = 0
    nb_livres_wishlist: int = 0
    nb_amis: int = 0


class Book(BaseModel):
    isbn: str
    titre: str
    auteur: str
    categorie: Optional[str] = None
    image_petite: Optional[str] = None
    resume: Optional[str] = None
    editeur: Optional[str] = None
    langue: Optional[str] = None
    note_moyenne: Optional[float] = None


class AddItem(BaseModel):
    isbn: str


class RatingBody(BaseModel):
    isbn: str
    note: int
    avis: Optional[str] = None


class RatingOut(BaseModel):
    isbn: str
    note: int
    avis: Optional[str] = None


class ExchangeCreate(BaseModel):
    destinataire_id: int
    livre_demandeur_isbn: str
    livre_destinataire_isbn: str


class ExchangeOut(BaseModel):
    id_demande: int
    expediteur_id: int
    livre_demandeur_isbn: str
    livre_demandeur_titre: Optional[str] = None
    livre_destinataire_isbn: str
    livre_destinataire_titre: Optional[str] = None
    statut: str
    date_echange: Optional[str] = None

class SimilarBookOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    editeur: Optional[str] = None
    image: Optional[str] = None
    similarity: float

def row_to_exchange(row) -> ExchangeOut:
    return ExchangeOut(
        id_demande=row[0],
        expediteur_id=row[1],
        livre_demandeur_isbn=row[2],
        livre_demandeur_titre=row[3],
        livre_destinataire_isbn=row[4],
        livre_destinataire_titre=row[5],
        statut=row[6],
        date_echange=str(row[7]) if row[7] else None,
    )

class RecommendationOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    score: float


@app.get("/me/recommendations", response_model=List[RecommendationOut])
def me_recommendations(limit: int = 10):
    if ML_PIPELINE is None:
        raise HTTPException(status_code=503, detail="Modèle IA non disponible")

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Profil user (tu as age + pays seulement -> OK)
        cur.execute("""
            SELECT COALESCE(age, 0), COALESCE(pays, 'UNK')
            FROM Utilisateur
            WHERE id_utilisateur = %s
        """, (CURRENT_USER_ID,))
        u = cur.fetchone()
        if not u:
            conn.close()
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        age, pays = int(u[0]), str(u[1] or "UNK")

        # Livres déjà possédés
        cur.execute("""
            SELECT livre_isbn FROM Collection WHERE utilisateur_id = %s
        """, (CURRENT_USER_ID,))
        owned = {r[0] for r in cur.fetchall()}

        # Candidats: derniers livres (tu peux changer la stratégie)
        cur.execute("""
            SELECT
                l.isbn, l.titre, COALESCE(l.auteur, ''),
                COALESCE(l.langue, 'UNK'),
                COALESCE(c.nomcat, 'UNK') AS categorie,
                COALESCE(YEAR(l.date_publication), 0) AS annee_publication,
                COALESCE(l.resume, '') AS resume
            FROM Livre l
            LEFT JOIN Categorie c ON c.id = l.categorie_id
            ORDER BY l.date_publication DESC
            LIMIT 500
        """)
        books = cur.fetchall()

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    # Filtrer déjà en collection
    candidates = [b for b in books if b[0] not in owned]
    if not candidates:
        return []

    # Construire DataFrame batch pour le pipeline
    X = pd.DataFrame([{
        "age": age,
        "pays": pays,
        "langue": b[3],
        "categorie": b[4],
        "annee_publication": int(b[5] or 0),
        "resume": b[6],
    } for b in candidates])

    proba = ML_PIPELINE.predict_proba(X)[:, 1]

    scored = []
    for i, b in enumerate(candidates):
        scored.append((b[0], b[1], b[2], float(proba[i])))

    scored.sort(key=lambda x: x[3], reverse=True)
    top = scored[:max(1, limit)]

    return [
        RecommendationOut(isbn=s[0], titre=s[1], auteur=s[2], score=round(s[3], 4))
        for s in top
    ]

@app.get("/reco/similar", response_model=List[SimilarBookOut])
def reco_similar(isbn: str, limit: int = 6):
    if TFIDF_MATRIX is None or TFIDF_META is None:
        raise HTTPException(status_code=503, detail="Modèle TF-IDF non disponible")

    # retrouver l'index du livre dans meta
    idx = None
    for i, item in enumerate(TFIDF_META):
        if str(item.get("isbn")) == str(isbn):
            idx = i
            break

    if idx is None:
        raise HTTPException(status_code=404, detail="ISBN introuvable dans l'index TF-IDF")

    sims = linear_kernel(TFIDF_MATRIX[idx], TFIDF_MATRIX).flatten()
    order = sims.argsort()[::-1]

    results = []
    for j in order:
        if j == idx:
            continue
        it = TFIDF_META[int(j)]
        results.append(SimilarBookOut(
            isbn=it.get("isbn", ""),
            titre=it.get("titre", ""),
            auteur=it.get("auteur", ""),
            editeur=it.get("editeur", None),
            image=it.get("image", None),
            similarity=float(sims[int(j)]),
        ))
        if len(results) >= max(1, limit):
            break

    return results

# --------------------------------------------------------------------
# Stockage des tokens actifs (pour le proto)
# --------------------------------------------------------------------
TOKENS: dict[str, int] = {}  # token -> user_id


# --------------------------------------------------------------------
# Healthcheck
# --------------------------------------------------------------------
@app.get("/")
def health():
    return {"ok": True, "service": "ExLibris API", "db": DB_NAME}


# --------------------------------------------------------------------
# Auth (base de données)
# --------------------------------------------------------------------
# --------------------------------------------------------------------
# Sécurité / Dépendance user courant
# --------------------------------------------------------------------
from fastapi import Header

def get_current_user_id(authorization: Optional[str] = Header(None)) -> int:
    """
    Récupère l'ID utilisateur depuis le header Authorization: Bearer <token>.
    Vérifie la présence du token dans le dictionnaire TOKENS.
    """
    if not authorization:
        print("AUTH DEBUG: No Authorization header")
        raise HTTPException(status_code=401, detail="Token manquant")
    
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        print(f"AUTH DEBUG: Invalid format: {authorization}")
        raise HTTPException(status_code=401, detail="Format Authorization invalide")
    
    token = parts[1]
    user_id = TOKENS.get(token)
    print(f"AUTH DEBUG: Token received: {token[:6]}... -> User ID resolved: {user_id}")

    if not user_id:
         print("AUTH DEBUG: Token not found in TOKENS")
         raise HTTPException(status_code=401, detail="Token invalide ou expiré")
    
    return user_id


# --------------------------------------------------------------------
# Auth (base de données)
# --------------------------------------------------------------------
@app.post("/auth/signup")
def signup(body: SignUpBody):
    """Inscription d'un nouvel utilisateur dans la table Utilisateur."""
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Vérifier si l'email existe déjà
        cur.execute("SELECT 1 FROM Utilisateur WHERE email = %s", (body.email,))
        if cur.fetchone():
            conn.close()
            raise HTTPException(status_code=409, detail="Email déjà utilisé")

        # Insérer le nouvel utilisateur
        cur.execute(
            """
            INSERT INTO Utilisateur (nom_utilisateur, email, mot_de_passe)
            VALUES (%s, %s, %s)
            """,
            (body.nom_utilisateur, body.email, body.mot_de_passe),
        )
        conn.commit()
        user_id = cur.lastrowid
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return {"ok": True, "user_id": user_id}


@app.post("/auth/login")
def login(body: LoginBody):
    """Connexion d'un utilisateur existant."""
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT id_utilisateur, mot_de_passe FROM Utilisateur WHERE email = %s
            """,
            (body.email,),
        )
        row = cur.fetchone()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    if not row or row[1] != body.mot_de_passe:
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    user_id = row[0]
    # Générer un token simple (en prod : utiliser JWT)
    import secrets
    token = secrets.token_hex(16)
    TOKENS[token] = user_id
    print(f"LOGIN DEBUG: User logged in. Email={body.email} -> ID={user_id}. Token={token[:6]}...")

    return {"token": token, "user_id": user_id}


@app.post("/auth/confirm")
def confirm(body: ConfirmBody):
    # Pour l'instant, on accepte n'importe quel token
    return {"ok": True, "message": "Email confirmé"}


@app.get("/me/profile", response_model=UserProfile)
def get_my_profile(current_user_id: int = Depends(get_current_user_id)):
    """Récupère les infos du profil de l'utilisateur courant + stats."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        # Infos user
        cur.execute(
            "SELECT id_utilisateur, nom_utilisateur, email FROM Utilisateur WHERE id_utilisateur = %s",
            (current_user_id,)
        )
        row = cur.fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")
        
        # Stats
        cur.execute("SELECT COUNT(*) FROM Collection WHERE utilisateur_id = %s", (current_user_id,))
        nb_col = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM Souhait WHERE utilisateur_id = %s", (current_user_id,))
        nb_wish = cur.fetchone()[0]

        cur.execute("""
            SELECT COUNT(*) FROM Amitie 
            WHERE (utilisateur_1_id = %s OR utilisateur_2_id = %s) 
              AND statut = 'accepte'
        """, (current_user_id, current_user_id))
        nb_amis = cur.fetchone()[0]

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    
    return UserProfile(
        id=row[0],
        nom_utilisateur=row[1],
        email=row[2],
        avatar_url=None,
        nb_livres_collection=nb_col,
        nb_livres_wishlist=nb_wish,
        nb_amis=nb_amis
    )


# --------------------------------------------------------------------
# Livres : lecture depuis SQLite (table Livre)
# --------------------------------------------------------------------
@app.get("/livres", response_model=List[Book])
def search_livres(
    query: Optional[str] = Query(
        default=None, description="Recherche sur titre ou auteur"
    ),
    auteur: Optional[str] = Query(
        default=None, description="Filtre uniquement sur l'auteur"
    ),
    isbn: Optional[str] = Query(
        default=None, description="Recherche exacte sur l'ISBN"
    ),
    limit: int = Query(
        default=50,
        le=200,
        description="Nombre maximum de livres renvoyés",
    ),
):
    """
    Lis les livres dans la table SQLite `Livre`.

    Colonnes attendues dans la table Livre :
      - isbn
      - titre
      - auteur
      - categorie       (nullable)
      - image_petite    (nullable)

    /livres
    /livres?query=camus
    /livres?isbn=9780143127741
    /livres?auteur=Harari
    """

    conn = get_db_connection()
    cur = conn.cursor()

    sql = """
        SELECT l.isbn, l.titre, l.auteur, c.nomcat, l.image_petite, l.resume, l.editeur, l.langue
        FROM Livre l
        LEFT JOIN Categorie c ON c.id = l.categorie_id
    """
    clauses = []
    params: list = []

    if isbn:
        clauses.append("isbn = %s")
        params.append(isbn)

    if query:
        like = f"%{query}%"
        clauses.append("(titre LIKE %s OR auteur LIKE %s)")
        params.extend([like, like])

    if auteur:
        like_a = f"%{auteur}%"
        clauses.append("auteur LIKE %s")
        params.append(like_a)

    if clauses:
        sql += " WHERE " + " AND ".join(clauses)

    sql += " LIMIT %s"
    params.append(limit)

    try:
        cur.execute(sql, params)
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    return [
        Book(
            isbn=row[0],
            titre=row[1],
            auteur=row[2] or "",
            categorie=row[3],
            image_petite=row[4],
            resume=row[5],
            editeur=row[6],
            langue=row[7],
        )
        for row in rows
    ]


# --------------------------------------------------------------------
# Collection utilisateur (stockée en base, table Collection)
# --------------------------------------------------------------------
@app.get("/me/collection", response_model=List[Book])
def get_collection(current_user_id: int = Depends(get_current_user_id)):
    """
    Renvoie les livres de la collection de l'utilisateur courant
    (current_user_id) en joignant Collection -> Livre.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    sql = """
        SELECT l.isbn, l.titre, l.auteur, cat.nomcat, l.image_petite, l.resume, l.editeur, l.langue
        FROM Collection col
        JOIN Livre l ON l.isbn = col.livre_isbn
        LEFT JOIN Categorie cat ON cat.id = l.categorie_id
        WHERE col.utilisateur_id = %s
        ORDER BY col.date_ajout DESC
    """

    try:
        cur.execute(sql, (current_user_id,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    return [
        Book(
            isbn=row[0],
            titre=row[1],
            auteur=row[2] or "",
            categorie=row[3],
            image_petite=row[4],
            resume=row[5],
            editeur=row[6],
            langue=row[7],
        )
        for row in rows
    ]


@app.get("/users/{user_id}/collection", response_model=List[Book])
def get_user_collection(user_id: int):
    """
    Renvoie les livres de la collection d'un autre utilisateur.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    sql = """
        SELECT l.isbn, l.titre, l.auteur, cat.nomcat, l.image_petite, l.resume, l.editeur, l.langue
        FROM Collection col
        JOIN Livre l ON l.isbn = col.livre_isbn
        LEFT JOIN Categorie cat ON cat.id = l.categorie_id
        WHERE col.utilisateur_id = %s
        ORDER BY col.date_ajout DESC
    """

    try:
        cur.execute(sql, (user_id,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    return [
        Book(
            isbn=row[0],
            titre=row[1],
            auteur=row[2] or "",
            categorie=row[3],
            image_petite=row[4],
            resume=row[5],
            editeur=row[6],
            langue=row[7],
        )
        for row in rows
    ]


@app.post("/me/collection")
def add_collection(item: AddItem, current_user_id: int = Depends(get_current_user_id)):
    """
    Ajoute un livre à la collection de l'utilisateur courant, si :
      - le livre existe dans Livre
      - et qu'il n'est pas déjà dans Collection pour cet utilisateur.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # 1) vérifier que le livre existe
        cur.execute("SELECT 1 FROM Livre WHERE isbn = %s", (item.isbn,))
        if cur.fetchone() is None:
            conn.close()
            raise HTTPException(status_code=404, detail="Livre introuvable")

        # 2) vérifier qu'il n'est pas déjà dans la collection
        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, item.isbn),
        )
        if cur.fetchone() is not None:
            conn.close()
            # on ne lève pas d’erreur, on signale juste que c’était déjà là
            return {"ok": True, "already": True}

        # 3) insérer
        cur.execute(
            """
            INSERT INTO Collection (utilisateur_id, livre_isbn)
            VALUES (%s, %s)
            """,
            (current_user_id, item.isbn),
        )
        conn.commit()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return {"ok": True}


@app.delete("/me/collection")
def remove_collection(
    isbn: str = Query(..., description="ISBN à retirer de la collection"),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Retire un livre de la collection de l'utilisateur courant.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            DELETE FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, isbn),
        )
        conn.commit()
        deleted = cur.rowcount
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    if deleted == 0:
        raise HTTPException(
            status_code=404, detail="Livre non présent dans la collection"
        )

    return {"ok": True}


# --------------------------------------------------------------------
# WISHLIST utilisateur (table Souhait)
# --------------------------------------------------------------------
@app.get("/me/wishlist", response_model=List[Book])
def get_wishlist(current_user_id: int = Depends(get_current_user_id)):
    """
    Renvoie les livres présents dans la wishlist de l'utilisateur courant
    en lisant la table Souhait + jointure avec Livre.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT l.isbn, l.titre, l.auteur, cat.nomcat, l.image_petite, l.resume, l.editeur, l.langue
            FROM Souhait s
            JOIN Livre l ON l.isbn = s.livre_isbn
            LEFT JOIN Categorie cat ON cat.id = l.categorie_id
            WHERE s.utilisateur_id = %s
            ORDER BY s.date_ajout DESC
            """,
            (current_user_id,),
        )
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    return [
        Book(
            isbn=row[0],
            titre=row[1],
            auteur=row[2] or "",
            categorie=row[3],
            image_petite=row[4],
            resume=row[5],
            editeur=row[6],
            langue=row[7],
        )
        for row in rows
    ]


@app.post("/me/wishlist")
def add_wishlist(item: AddItem, current_user_id: int = Depends(get_current_user_id)):
    """
    Ajoute un livre à la wishlist de l'utilisateur courant
    dans la table Souhait.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # 1) vérifier que le livre existe
        cur.execute("SELECT 1 FROM Livre WHERE isbn = %s", (item.isbn,))
        row = cur.fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Livre introuvable")

        # 2) vérifier s'il est déjà dans la wishlist
        cur.execute(
            """
            SELECT 1 FROM Souhait
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, item.isbn),
        )
        already = cur.fetchone()
        if already:
            conn.close()
            return {"ok": True, "message": "Déjà dans la wishlist"}

        # 3) insérer dans Souhait
        cur.execute(
            """
            INSERT INTO Souhait (utilisateur_id, livre_isbn)
            VALUES (%s, %s)
            """,
            (current_user_id, item.isbn),
        )
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return {"ok": True}


@app.delete("/me/wishlist")
def remove_wishlist(
    isbn: str = Query(..., description="ISBN à retirer de la wishlist"),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Retire un livre de la wishlist de l'utilisateur courant
    dans la table Souhait.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            DELETE FROM Souhait
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, isbn),
        )
        if cur.rowcount == 0:
            conn.close()
            raise HTTPException(
                status_code=404, detail="Livre non présent dans la wishlist"
            )
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return {"ok": True}


# --------------------------------------------------------------------
# Amis (depuis la base de données)
# --------------------------------------------------------------------
class Friend(BaseModel):
    id: int
    nom: str
    avatar_url: Optional[str] = None


# 1) Amis actuels
FRIENDS: list[Friend] = [
    Friend(id=1, nom="Alice"),
    Friend(id=2, nom="Bob"),
    Friend(id=3, nom="Charlie"),
]

# 2) Demandes reçues (en attente)
PENDING_FRIEND_REQUESTS_INCOMING: list[Friend] = [
    Friend(id=4, nom="Diane"),
    Friend(id=5, nom="Ethan"),
]

# 3) Demandes envoyées (en attente de validation par l’autre)
PENDING_FRIEND_REQUESTS_OUTGOING: list[Friend] = []

# 4) Candidats possibles pour la recherche (pas encore amis / pas en attente)
CANDIDATE_FRIENDS: list[Friend] = [
    Friend(id=6, nom="Fiona"),
    Friend(id=7, nom="George"),
    Friend(id=8, nom="Hector"),
    Friend(id=9, nom="Inès"),
]


@app.get("/friends", response_model=List[Friend])
def get_friends(current_user_id: int = Depends(get_current_user_id)):
    """Récupère la liste des amis confirmés de l'utilisateur courant."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            SELECT u.id_utilisateur, u.nom_utilisateur
            FROM Amitie a
            JOIN Utilisateur u ON (
                (a.utilisateur_1_id = %s AND a.utilisateur_2_id = u.id_utilisateur)
                OR (a.utilisateur_2_id = %s AND a.utilisateur_1_id = u.id_utilisateur)
            )
            WHERE a.statut = 'accepte'
        """
        cur.execute(sql, (current_user_id, current_user_id))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.get("/friends/requests", response_model=List[Friend])
def get_friend_requests_incoming(current_user_id: int = Depends(get_current_user_id)):
    """Demandes d'amis reçues (en attente)."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            SELECT u.id_utilisateur, u.nom_utilisateur
            FROM Amitie a
            JOIN Utilisateur u ON a.utilisateur_1_id = u.id_utilisateur
            WHERE a.utilisateur_2_id = %s AND a.statut = 'en_attente'
        """
        cur.execute(sql, (current_user_id,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.get("/friends/requests/incoming", response_model=List[Friend])
def get_friend_requests_incoming_alias(current_user_id: int = Depends(get_current_user_id)):
    """Alias pour les demandes reçues."""
    return get_friend_requests_incoming(current_user_id)


@app.get("/friends/requests-outgoing", response_model=List[Friend])
def get_friend_requests_outgoing(current_user_id: int = Depends(get_current_user_id)):
    """Demandes d'amis envoyées (en attente)."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            SELECT u.id_utilisateur, u.nom_utilisateur
            FROM Amitie a
            JOIN Utilisateur u ON a.utilisateur_2_id = u.id_utilisateur
            WHERE a.utilisateur_1_id = %s AND a.statut = 'en_attente'
        """
        cur.execute(sql, (current_user_id,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.delete("/friends/{friend_id}")
def remove_friend(friend_id: int, current_user_id: int = Depends(get_current_user_id)):
    """Supprimer un ami."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            DELETE FROM Amitie 
            WHERE (utilisateur_1_id = %s AND utilisateur_2_id = %s)
               OR (utilisateur_1_id = %s AND utilisateur_2_id = %s)
        """
        cur.execute(sql, (current_user_id, friend_id, friend_id, current_user_id))
        conn.commit()
        if cur.rowcount == 0:
            conn.close()
            raise HTTPException(status_code=404, detail="Ami non trouvé")
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return {"ok": True}


@app.post("/friends/requests/{friend_id}/accept")
def accept_friend_request(friend_id: int, current_user_id: int = Depends(get_current_user_id)):
    """Accepter une demande d'ami reçue."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            UPDATE Amitie 
            SET statut = 'accepte'
            WHERE utilisateur_1_id = %s AND utilisateur_2_id = %s AND statut = 'en_attente'
        """
        cur.execute(sql, (friend_id, current_user_id))
        conn.commit()
        if cur.rowcount == 0:
            conn.close()
            raise HTTPException(status_code=404, detail="Demande non trouvée")
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return {"ok": True}


@app.post("/friends/requests/{friend_id}/refuse")
def refuse_friend_request(friend_id: int, current_user_id: int = Depends(get_current_user_id)):
    """Refuser une demande d'ami reçue."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            DELETE FROM Amitie 
            WHERE utilisateur_1_id = %s AND utilisateur_2_id = %s AND statut = 'en_attente'
        """
        cur.execute(sql, (friend_id, current_user_id))
        conn.commit()
        if cur.rowcount == 0:
            conn.close()
            raise HTTPException(status_code=404, detail="Demande non trouvée")
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return {"ok": True}


@app.get("/friends/search", response_model=List[Friend])
def search_friends(
    q: str = Query(..., description="Nom / pseudo de la personne à rechercher"),
    current_user_id: int = Depends(get_current_user_id)
):
    """Recherche d'utilisateurs (exclut les amis et demandes en cours)."""
    q_lower = q.lower().strip()
    if not q_lower:
        return []
    
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            SELECT u.id_utilisateur, u.nom_utilisateur
            FROM Utilisateur u
            WHERE u.id_utilisateur != %s
              AND LOWER(u.nom_utilisateur) LIKE %s
              AND u.id_utilisateur NOT IN (
                  SELECT CASE 
                      WHEN a.utilisateur_1_id = %s THEN a.utilisateur_2_id 
                      ELSE a.utilisateur_1_id 
                  END
                  FROM Amitie a
                  WHERE a.utilisateur_1_id = %s OR a.utilisateur_2_id = %s
              )
            LIMIT 20
        """
        cur.execute(sql, (current_user_id, f"%{q_lower}%", current_user_id, current_user_id, current_user_id))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.post("/friends/requests/{friend_id}")
def send_friend_request(friend_id: int, current_user_id: int = Depends(get_current_user_id)):
    """Envoyer une demande d'ami."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        # Vérifier que l'utilisateur existe
        cur.execute("SELECT 1 FROM Utilisateur WHERE id_utilisateur = %s", (friend_id,))
        if not cur.fetchone():
            conn.close()
            raise HTTPException(status_code=404, detail="Utilisateur inconnu")
        
        # Ne pas s'ajouter soi-même
        if friend_id == current_user_id:
            conn.close()
            raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous ajouter vous-même")
        
        # Vérifier qu'il n'y a pas déjà une relation
        cur.execute("""
            SELECT 1 FROM Amitie 
            WHERE (utilisateur_1_id = %s AND utilisateur_2_id = %s)
               OR (utilisateur_1_id = %s AND utilisateur_2_id = %s)
        """, (current_user_id, friend_id, friend_id, current_user_id))
        if cur.fetchone():
            conn.close()
            raise HTTPException(status_code=400, detail="Demande déjà existante ou déjà amis")
        
        # Créer la demande
        cur.execute("""
            INSERT INTO Amitie (utilisateur_1_id, utilisateur_2_id, statut)
            VALUES (%s, %s, 'en_attente')
        """, (current_user_id, friend_id))
        conn.commit()
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return {"ok": True}


# --------------------------------------------------------------------
# Échanges de livres (proto : CURRENT_USER_ID = 1)
# --------------------------------------------------------------------

EXCHANGE_ALLOWED_STATUS = {
    "demande_envoyee",
    "demande_acceptee",
    "demande_refusee",
    "proposition_confirmee",
    "annule",
    "termine",
}


@app.post("/exchanges", response_model=ExchangeOut)
def create_exchange(body: ExchangeCreate, current_user_id: int = Depends(get_current_user_id)):
    """
    Crée une nouvelle demande d'échange.
    NOTE: La BDD ne stocke PAS le destinataire_id dans la table Echange.
    C'est donc un échange "ouvert" sur le livre destinataire.
    """
    if body.destinataire_id == current_user_id:
        raise HTTPException(
            status_code=400,
            detail="On ne peut pas créer un échange avec soi-même.",
        )

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Vérifier que les deux livres existent
        cur.execute("SELECT 1 FROM Livre WHERE isbn = %s", (body.livre_demandeur_isbn,))
        if not cur.fetchone():
            conn.close()
            raise HTTPException(
                status_code=404,
                detail="Livre du demandeur introuvable",
            )

        cur.execute(
            "SELECT 1 FROM Livre WHERE isbn = %s",
            (body.livre_destinataire_isbn,),
        )
        if not cur.fetchone():
            conn.close()
            raise HTTPException(
                status_code=404,
                detail="Livre du destinataire introuvable",
            )

        # Insertion de l'échange (SANS destinataire_id, car colonne inexistante)
        cur.execute(
            """
            INSERT INTO Echange (
                expediteur_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_echange
            )
            VALUES (%s, %s, %s, 'demande_envoyee', CURRENT_TIMESTAMP)
            """,
            (
                current_user_id,
                body.livre_demandeur_isbn,
                body.livre_destinataire_isbn,
            ),
        )
        id_demande = cur.lastrowid

        # Récupérer la ligne pour la renvoyer
        cur.execute(
            """
            SELECT
                e.id_demande,
                e.expediteur_id,
                e.livre_demandeur_isbn,
                l1.titre,
                e.livre_destinataire_isbn,
                l2.titre,
                e.statut,
                e.date_echange
            FROM Echange e
            LEFT JOIN Livre l1 ON e.livre_demandeur_isbn = l1.isbn
            LEFT JOIN Livre l2 ON e.livre_destinataire_isbn = l2.isbn
            WHERE e.id_demande = %s
            """,
            (id_demande,),
        )
        row = cur.fetchone()
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(row)


@app.get("/me/exchanges", response_model=List[ExchangeOut])
def list_my_exchanges(
    role: Optional[str] = Query(
        default=None,
        description="Filtre sur le rôle : 'demandeur', 'destinataire' ou vide pour tout",
    ),
    statut: Optional[str] = Query(
        default=None,
        description="Filtre sur le statut",
    ),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Liste les échanges.
    - Demandeur = expediteur_id est MOI
    - Destinataire = livre_destinataire_isbn est DANS MA COLLECTION
    """
    conn = get_db_connection()
    cur = conn.cursor()

    # On récupère TOUS les échanges qui me concernent
    # Soit je l'ai envoyé (expediteur_id = ME)
    # Soit je "possède" le livre demandé (livre_destinataire_isbn IN MyCollection)
    sql = """
        SELECT
            e.id_demande,
            e.expediteur_id,
            e.livre_demandeur_isbn,
            l1.titre as titre_demandeur,
            e.livre_destinataire_isbn,
            l2.titre as titre_destinataire,
            e.statut,
            e.date_echange
        FROM Echange e
        LEFT JOIN Collection c ON e.livre_destinataire_isbn = c.livre_isbn AND c.utilisateur_id = %s
        LEFT JOIN Livre l1 ON e.livre_demandeur_isbn = l1.isbn
        LEFT JOIN Livre l2 ON e.livre_destinataire_isbn = l2.isbn
        WHERE e.expediteur_id = %s OR c.utilisateur_id IS NOT NULL
    """
    params = [current_user_id, current_user_id]

    # Note: le filtrage par role/statut est plus complexe en SQL direct ici
    # on va filtrer en Python pour simplifier la logique "destinataire dynamique"
    
    try:
        cur.execute(sql, params)
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    results = []
    for row in rows:
        exc = row_to_exchange(row)
        
        # Determine my role
        is_sender = (exc.expediteur_id == current_user_id)
        # Recipient logic handled by the query (if I wasn't sender, I must be recipient)
        
        if role == "demandeur" and not is_sender:
            continue
        if role == "destinataire" and is_sender:
            continue
            
        if statut and exc.statut != statut:
            continue
            
        results.append(exc)

    return results


def _get_exchange_for_update(cur, exchange_id: int):
    cur.execute(
        """
        SELECT
            e.id_demande,
            e.expediteur_id,
            e.livre_demandeur_isbn,
            l1.titre,
            e.livre_destinataire_isbn,
            l2.titre,
            e.statut,
            e.date_echange
        FROM Echange e
        LEFT JOIN Livre l1 ON e.livre_demandeur_isbn = l1.isbn
        LEFT JOIN Livre l2 ON e.livre_destinataire_isbn = l2.isbn
        WHERE e.id_demande = %s
        """,
        (exchange_id,),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Échange introuvable")
    return row


@app.post("/exchanges/{exchange_id}/accept", response_model=ExchangeOut)
def accept_exchange(exchange_id: int, current_user_id: int = Depends(get_current_user_id)):
    """
    Accepte l'échange. Vérifie que je possède le livre demandé.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        # row: id, expediteur, livre_dem, titre_dem, livre_dest, titre_dest, statut, date
        livre_dest_isbn = row[4]
        statut = row[6]

        # Vérifier que JE possède le livre destinataire
        cur.execute(
            "SELECT 1 FROM Collection WHERE utilisateur_id = %s AND livre_isbn = %s",
            (current_user_id, livre_dest_isbn)
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=403,
                detail="Vous ne possédez pas le livre demandé, impossible d'accepter.",
            )

        if statut != "demande_envoyee":
            raise HTTPException(
                status_code=400,
                detail="Statut invalide pour acceptation.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'proposition_confirmee'
            WHERE id_demande = %s
            """,
            (exchange_id,),
        )
        
        # --- ECHANGE DES LIVRES DANS LA COLLECTION ---
        expediteur_id = row[1]
        livre_demandeur_isbn = row[2]
        # livre_dest_isbn = row[4] (déjà récupéré au dessus)

        # 1. Le livre de l'expéditeur (demandeur) devient le mien (destinataire)
        # On vérifie d'abord que l'expéditeur l'a bien toujours (sécurité)
        cur.execute(
            """
            UPDATE Collection
            SET utilisateur_id = %s
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, expediteur_id, livre_demandeur_isbn)
        )
        
        # 2. Mon livre (destinataire) devient celui de l'expéditeur
        cur.execute(
            """
            UPDATE Collection
            SET utilisateur_id = %s
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (expediteur_id, current_user_id, livre_dest_isbn)
        )
        # ---------------------------------------------
        
        # Re-fetch for return
        row = _get_exchange_for_update(cur, exchange_id)
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(row)


@app.post("/exchanges/{exchange_id}/refuse", response_model=ExchangeOut)
def refuse_exchange(exchange_id: int, current_user_id: int = Depends(get_current_user_id)):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        livre_dest_isbn = row[4]
        
        # Vérifier que JE possède le livre (donc je suis légitime pour refuser)
        cur.execute(
            "SELECT 1 FROM Collection WHERE utilisateur_id = %s AND livre_isbn = %s",
            (current_user_id, livre_dest_isbn)
        )
        if not cur.fetchone():
             raise HTTPException(status_code=403, detail="Non autorisé")

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'annulee'
            WHERE id_demande = %s
            """,
            (exchange_id,),
        )
        row = _get_exchange_for_update(cur, exchange_id)
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(row)


@app.post("/exchanges/{exchange_id}/cancel", response_model=ExchangeOut)
def cancel_exchange(exchange_id: int, current_user_id: int = Depends(get_current_user_id)):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        expediteur_id = row[1]

        if expediteur_id != current_user_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le demandeur peut annuler.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'annulee'
            WHERE id_demande = %s
            """,
            (exchange_id,),
        )
        row = _get_exchange_for_update(cur, exchange_id)
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(row)


# --------------------------------------------------------------------
# Évaluations (notes / avis) utilisateur (proto : user_id=1)
# --------------------------------------------------------------------

# On utilisera l'utilisateur 1 pour le moment

@app.post("/me/ratings", response_model=RatingOut)
def add_or_update_rating(body: RatingBody, current_user_id: int = Depends(get_current_user_id)):
    """
    Ajoute ou met à jour la note/avis de l'utilisateur courant
    pour un livre donné.
    """
    # Vérification rapide côté API
    if body.note < 0 or body.note > 10:
        raise HTTPException(
            status_code=400,
            detail="La note doit être entre 0 et 10.",
        )

    conn = get_db_connection()
    cur = conn.cursor()

    # Vérifier que le livre existe
    try:
        cur.execute("SELECT 1 FROM Livre WHERE isbn = %s", (body.isbn,))
        row = cur.fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Livre introuvable")

        # Voir si une évaluation existe déjà pour (user, livre)
        cur.execute(
            """
            SELECT id_evaluation
            FROM Evaluation
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, body.isbn),
        )
        existing = cur.fetchone()

        if existing:
            # Mise à jour
            cur.execute(
                """
                UPDATE Evaluation
                SET note = %s, avis = %s
                WHERE utilisateur_id = %s AND livre_isbn = %s
                """,
                (body.note, body.avis, current_user_id, body.isbn),
            )
        else:
            # Insertion
            cur.execute(
                """
                INSERT INTO Evaluation (utilisateur_id, livre_isbn, note, avis)
                VALUES (%s, %s, %s, %s)
                """,
                (current_user_id, body.isbn, body.note, body.avis),
            )

        conn.commit()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return RatingOut(isbn=body.isbn, note=body.note, avis=body.avis)


@app.get("/me/ratings", response_model=List[RatingOut])
def get_my_ratings(isbn: Optional[str] = Query(default=None), current_user_id: int = Depends(get_current_user_id)):
    """
    Récupère les évaluations de l'utilisateur courant.
    - Si isbn est fourni : renvoie au plus 1 élément (la note pour ce livre).
    - Sinon : renvoie toutes ses évaluations.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        if isbn:
            cur.execute(
                """
                SELECT livre_isbn, note, avis
                FROM Evaluation
                WHERE utilisateur_id = %s AND livre_isbn = %s
                """,
                (current_user_id, isbn),
            )
        else:
            cur.execute(
                """
                SELECT livre_isbn, note, avis
                FROM Evaluation
                WHERE utilisateur_id = %s
                """,
                (current_user_id,),
            )

        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()

    return [
        RatingOut(isbn=row[0], note=row[1], avis=row[2])
        for row in rows
    ]