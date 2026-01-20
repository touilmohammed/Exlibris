from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import pymysql
import os
from dotenv import load_dotenv

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

# Pour l’instant : on suppose que l'utilisateur connecté a l'id 1
CURRENT_USER_ID = 1


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
    id_echange: int
    demandeur_id: int
    destinataire_id: int
    livre_demandeur_isbn: str
    livre_destinataire_isbn: str
    statut: str
    date_creation: Optional[str] = None
    date_derniere_maj: Optional[str] = None


def row_to_exchange(row) -> ExchangeOut:
    return ExchangeOut(
        id_echange=row[0],
        demandeur_id=row[1],
        destinataire_id=row[2],
        livre_demandeur_isbn=row[3],
        livre_destinataire_isbn=row[4],
        statut=row[5],
        date_creation=row[6],
        date_derniere_maj=row[7],
    )


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
    global CURRENT_USER_ID
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

    # Mettre à jour l'utilisateur courant pour les autres endpoints
    CURRENT_USER_ID = user_id

    return {"token": token, "user_id": user_id}


@app.post("/auth/confirm")
def confirm(body: ConfirmBody):
    # Pour l'instant, on accepte n'importe quel token
    return {"ok": True, "message": "Email confirmé"}


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
def get_collection():
    """
    Renvoie les livres de la collection de l'utilisateur courant
    (CURRENT_USER_ID) en joignant Collection -> Livre.
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
        cur.execute(sql, (CURRENT_USER_ID,))
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
def add_collection(item: AddItem):
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
            (CURRENT_USER_ID, item.isbn),
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
            (CURRENT_USER_ID, item.isbn),
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
            (CURRENT_USER_ID, isbn),
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
def get_wishlist():
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
            (CURRENT_USER_ID,),
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
def add_wishlist(item: AddItem):
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
            (CURRENT_USER_ID, item.isbn),
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
            (CURRENT_USER_ID, item.isbn),
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
            (CURRENT_USER_ID, isbn),
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
def get_friends():
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
        cur.execute(sql, (CURRENT_USER_ID, CURRENT_USER_ID))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.get("/friends/requests", response_model=List[Friend])
def get_friend_requests_incoming():
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
        cur.execute(sql, (CURRENT_USER_ID,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.get("/friends/requests/incoming", response_model=List[Friend])
def get_friend_requests_incoming_alias():
    """Alias pour les demandes reçues."""
    return get_friend_requests_incoming()


@app.get("/friends/requests-outgoing", response_model=List[Friend])
def get_friend_requests_outgoing():
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
        cur.execute(sql, (CURRENT_USER_ID,))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.delete("/friends/{friend_id}")
def remove_friend(friend_id: int):
    """Supprimer un ami."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            DELETE FROM Amitie 
            WHERE (utilisateur_1_id = %s AND utilisateur_2_id = %s)
               OR (utilisateur_1_id = %s AND utilisateur_2_id = %s)
        """
        cur.execute(sql, (CURRENT_USER_ID, friend_id, friend_id, CURRENT_USER_ID))
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
def accept_friend_request(friend_id: int):
    """Accepter une demande d'ami reçue."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            UPDATE Amitie 
            SET statut = 'accepte'
            WHERE utilisateur_1_id = %s AND utilisateur_2_id = %s AND statut = 'en_attente'
        """
        cur.execute(sql, (friend_id, CURRENT_USER_ID))
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
def refuse_friend_request(friend_id: int):
    """Refuser une demande d'ami reçue."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            DELETE FROM Amitie 
            WHERE utilisateur_1_id = %s AND utilisateur_2_id = %s AND statut = 'en_attente'
        """
        cur.execute(sql, (friend_id, CURRENT_USER_ID))
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
        cur.execute(sql, (CURRENT_USER_ID, f"%{q_lower}%", CURRENT_USER_ID, CURRENT_USER_ID, CURRENT_USER_ID))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1]) for row in rows]


@app.post("/friends/requests/{friend_id}")
def send_friend_request(friend_id: int):
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
        if friend_id == CURRENT_USER_ID:
            conn.close()
            raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous ajouter vous-même")
        
        # Vérifier qu'il n'y a pas déjà une relation
        cur.execute("""
            SELECT 1 FROM Amitie 
            WHERE (utilisateur_1_id = %s AND utilisateur_2_id = %s)
               OR (utilisateur_1_id = %s AND utilisateur_2_id = %s)
        """, (CURRENT_USER_ID, friend_id, friend_id, CURRENT_USER_ID))
        if cur.fetchone():
            conn.close()
            raise HTTPException(status_code=400, detail="Demande déjà existante ou déjà amis")
        
        # Créer la demande
        cur.execute("""
            INSERT INTO Amitie (utilisateur_1_id, utilisateur_2_id, statut)
            VALUES (%s, %s, 'en_attente')
        """, (CURRENT_USER_ID, friend_id))
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
def create_exchange(body: ExchangeCreate):
    """
    Crée une nouvelle demande d'échange :
      - CURRENT_USER_ID = demandeur
      - destinataire_id = ami
      - deux ISBN (un pour moi, un pour lui)
    """
    if body.destinataire_id == CURRENT_USER_ID:
        raise HTTPException(
            status_code=400,
            detail="On ne peut pas créer un échange avec soi-même.",
        )

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Vérifier que le destinataire existe
        cur.execute(
            "SELECT 1 FROM Utilisateur WHERE id_utilisateur = %s",
            (body.destinataire_id,),
        )
        if not cur.fetchone():
            conn.close()
            raise HTTPException(status_code=404, detail="Destinataire introuvable")

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

        # Insertion de l'échange
        cur.execute(
            """
            INSERT INTO Echange (
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_creation,
                date_derniere_maj
            )
            VALUES (%s, %s, %s, %s, 'demande_envoyee', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """,
            (
                CURRENT_USER_ID,
                body.destinataire_id,
                body.livre_demandeur_isbn,
                body.livre_destinataire_isbn,
            ),
        )
        echange_id = cur.lastrowid

        # Récupérer la ligne pour la renvoyer
        cur.execute(
            """
            SELECT
                id_echange,
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_creation,
                date_derniere_maj
            FROM Echange
            WHERE id_echange = %s
            """,
            (echange_id,),
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
        description="Filtre sur le statut (demande_envoyee, demande_acceptee, ...)",
    ),
):
    """
    Liste les échanges où l'utilisateur courant est demandeur ou destinataire.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    sql = """
        SELECT
            id_echange,
            demandeur_id,
            destinataire_id,
            livre_demandeur_isbn,
            livre_destinataire_isbn,
            statut,
            date_creation,
            date_derniere_maj
        FROM Echange
        WHERE 1=1
    """
    params: list = []

    if role == "demandeur":
        sql += " AND demandeur_id = %s"
        params.append(CURRENT_USER_ID)
    elif role == "destinataire":
        sql += " AND destinataire_id = %s"
        params.append(CURRENT_USER_ID)
    else:
        # tous les échanges où je suis impliqué
        sql += " AND (demandeur_id = %s OR destinataire_id = %s)"
        params.extend([CURRENT_USER_ID, CURRENT_USER_ID])

    if statut:
        if statut not in EXCHANGE_ALLOWED_STATUS:
            raise HTTPException(status_code=400, detail="Statut invalide")
        sql += " AND statut = %s"
        params.append(statut)

    try:
        cur.execute(sql, params)
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return [row_to_exchange(r) for r in rows]


def _get_exchange_for_update(cur, exchange_id: int):
    cur.execute(
        """
        SELECT
            id_echange,
            demandeur_id,
            destinataire_id,
            livre_demandeur_isbn,
            livre_destinataire_isbn,
            statut,
            date_creation,
            date_derniere_maj
        FROM Echange
        WHERE id_echange = %s
        """,
        (exchange_id,),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Échange introuvable")
    return row


@app.post("/exchanges/{exchange_id}/accept", response_model=ExchangeOut)
def accept_exchange(exchange_id: int):
    """
    Le destinataire accepte la demande d'échange.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        echange = row_to_exchange(row)

        if echange.destinataire_id != CURRENT_USER_ID:
            raise HTTPException(
                status_code=403,
                detail="Seul le destinataire peut accepter l'échange.",
            )

        if echange.statut != "demande_envoyee":
            raise HTTPException(
                status_code=400,
                detail="Seules les demandes en attente peuvent être acceptées.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'demande_acceptee',
                date_derniere_maj = CURRENT_TIMESTAMP
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        cur.execute(
            """
            SELECT
                id_echange,
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_creation,
                date_derniere_maj
            FROM Echange
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )
        updated = cur.fetchone()
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(updated)


@app.post("/exchanges/{exchange_id}/refuse", response_model=ExchangeOut)
def refuse_exchange(exchange_id: int):
    """
    Le destinataire refuse la demande d'échange.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        echange = row_to_exchange(row)

        if echange.destinataire_id != CURRENT_USER_ID:
            raise HTTPException(
                status_code=403,
                detail="Seul le destinataire peut refuser l'échange.",
            )

        if echange.statut != "demande_envoyee":
            raise HTTPException(
                status_code=400,
                detail="Seules les demandes en attente peuvent être refusées.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'demande_refusee',
                date_derniere_maj = CURRENT_TIMESTAMP
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        cur.execute(
            """
            SELECT
                id_echange,
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_creation,
                date_derniere_maj
            FROM Echange
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )
        updated = cur.fetchone()
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(updated)


@app.post("/exchanges/{exchange_id}/cancel", response_model=ExchangeOut)
def cancel_exchange(exchange_id: int):
    """
    Le demandeur annule sa demande d'échange (tant qu'elle est en attente).
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)
        echange = row_to_exchange(row)

        if echange.demandeur_id != CURRENT_USER_ID:
            raise HTTPException(
                status_code=403,
                detail="Seul le demandeur peut annuler l'échange.",
            )

        if echange.statut not in ("demande_envoyee", "demande_acceptee"):
            raise HTTPException(
                status_code=400,
                detail="Cet échange ne peut plus être annulé.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'annule',
                date_derniere_maj = CURRENT_TIMESTAMP
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        cur.execute(
            """
            SELECT
                id_echange,
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut,
                date_creation,
                date_derniere_maj
            FROM Echange
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )
        updated = cur.fetchone()
        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return row_to_exchange(updated)


# --------------------------------------------------------------------
# Évaluations (notes / avis) utilisateur (proto : user_id=1)
# --------------------------------------------------------------------
# On utilisera l'utilisateur 1 pour le moment
CURRENT_USER_ID = 1


@app.post("/me/ratings", response_model=RatingOut)
def add_or_update_rating(body: RatingBody):
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
            (CURRENT_USER_ID, body.isbn),
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
                (body.note, body.avis, CURRENT_USER_ID, body.isbn),
            )
        else:
            # Insertion
            cur.execute(
                """
                INSERT INTO Evaluation (utilisateur_id, livre_isbn, note, avis)
                VALUES (%s, %s, %s, %s)
                """,
                (CURRENT_USER_ID, body.isbn, body.note, body.avis),
            )

        conn.commit()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")

    conn.close()
    return RatingOut(isbn=body.isbn, note=body.note, avis=body.avis)


@app.get("/me/ratings", response_model=List[RatingOut])
def get_my_ratings(isbn: Optional[str] = Query(default=None)):
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
                (CURRENT_USER_ID, isbn),
            )
        else:
            cur.execute(
                """
                SELECT livre_isbn, note, avis
                FROM Evaluation
                WHERE utilisateur_id = %s
                """,
                (CURRENT_USER_ID,),
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