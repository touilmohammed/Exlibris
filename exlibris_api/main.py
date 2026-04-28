from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from core.database import get_db_connection
from core.config import ALLOWED_ORIGIN_REGEX, ALLOWED_ORIGINS, DB_NAME
from dependencies.auth import get_current_user_id
from routers.auth import router as auth_router
from routers.exchanges import router as exchanges_router
from routers.payments import router as payments_router
from routers.stripe import router as stripe_router
from routers.messages import router as messages_router
from routers.notifications import router as notifications_router
from routers.ia import router as ia_router
from services.ia_service import load_models, recommend_for_user, similar_books
from services.notification_service import create_notification, notify_user
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    load_models()
    yield


app = FastAPI(
    title="ExLibris",
    description="Api Exlibris.",
    version="1.0.0",
    root_path="/exlibris-api",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------------------------
# Modèles Pydantic
# --------------------------------------------------------------------
class UserProfile(BaseModel):
    id: int
    nom_utilisateur: str
    email: str
    age: Optional[int] = None
    sexe: Optional[str] = None
    pays: Optional[str] = None
    avatar_url: Optional[str] = None
    nb_livres_collection: int = 0
    nb_livres_wishlist: int = 0
    nb_amis: int = 0
    pgp_public_key: Optional[str] = None
    pgp_private_key_enc: Optional[str] = None

class UpdateUserBody(BaseModel):
    nom_utilisateur: Optional[str] = None
    email: Optional[str] = None
    age: Optional[int] = None
    sexe: Optional[str] = None
    pays: Optional[str] = None

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

class SimilarBookOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    editeur: Optional[str] = None
    image: Optional[str] = None
    similarity: float

class RecommendationOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    categorie: Optional[str] = None
    image_petite: Optional[str] = None
    resume: Optional[str] = None
    editeur: Optional[str] = None
    langue: Optional[str] = None
    score: float


# --------------------------------------------------------------------
# Auth (base de données)
# --------------------------------------------------------------------
# --------------------------------------------------------------------
# Sécurité / Dépendance user courant
# --------------------------------------------------------------------

@app.get("/me/recommendations", response_model=List[RecommendationOut])
def me_recommendations(limit: int = 10, current_user_id: int = Depends(get_current_user_id)):
    return recommend_for_user(current_user_id, limit)

@app.get("/reco/similar", response_model=List[SimilarBookOut])
def reco_similar(isbn: str, limit: int = 6):
    return similar_books(isbn, limit)


# --------------------------------------------------------------------
# Healthcheck
# --------------------------------------------------------------------
@app.get("/")
def health():
    return {"ok": True, "service": "ExLibris API", "db": DB_NAME}


# --------------------------------------------------------------------
# Auth (base de données)
# --------------------------------------------------------------------

@app.get("/me/profile", response_model=UserProfile)
def get_my_profile(current_user_id: int = Depends(get_current_user_id)):
    """Récupère les infos du profil de l'utilisateur courant + stats."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        # Infos user
        cur.execute(
            "SELECT id_utilisateur, nom_utilisateur, email, age, sexe, pays, pgp_public_key, pgp_private_key_enc FROM Utilisateur WHERE id_utilisateur = %s",
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
        age=row[3],
        sexe=row[4],
        pays=row[5],
        avatar_url=None,
        nb_livres_collection=nb_col,
        nb_livres_wishlist=nb_wish,
        nb_amis=nb_amis,
        pgp_public_key=row[6],
        pgp_private_key_enc=row[7]
    )


@app.patch("/me/profile")
def update_my_profile(
    body: UpdateUserBody,
    current_user_id: int = Depends(get_current_user_id)
):
    """Met à jour les informations de l'utilisateur connecté."""
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Construire dynamiquement la requête SET
        updates = []
        params = []

        if body.nom_utilisateur is not None:
            updates.append("nom_utilisateur = %s")
            params.append(body.nom_utilisateur)
        
        if body.email is not None:
            # Vérifier si l'email existe déjà ailleurs
            cur.execute("SELECT 1 FROM Utilisateur WHERE email = %s AND id_utilisateur <> %s", (body.email, current_user_id))
            if cur.fetchone():
                conn.close()
                raise HTTPException(status_code=409, detail="Email déjà utilisé")
            updates.append("email = %s")
            params.append(body.email)

        if body.age is not None:
            updates.append("age = %s")
            params.append(body.age)

        if body.sexe is not None:
            if body.sexe not in ('male', 'femelle', 'indefini'):
                 raise HTTPException(status_code=400, detail="Sexe invalide (male, femelle, indefini)")
            updates.append("sexe = %s")
            params.append(body.sexe)

        if body.pays is not None:
            updates.append("pays = %s")
            params.append(body.pays)

        if not updates:
            conn.close()
            return {"ok": True, "message": "Aucune modification demandée"}

        sql = f"UPDATE Utilisateur SET {', '.join(updates)} WHERE id_utilisateur = %s"
        params.append(current_user_id)

        cur.execute(sql, tuple(params))
        conn.commit()

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    
    conn.close()
    return {"ok": True, "message": "Profil mis à jour"}


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

        # --- NOTIFICATION LOGIC ---
        try:
            # Récupérer les infos nécessaires (nom user, titre livre)
            cur.execute("SELECT nom_utilisateur FROM Utilisateur WHERE id_utilisateur = %s", (current_user_id,))
            u_row = cur.fetchone()
            username = u_row[0] if u_row else "Un ami"

            cur.execute("SELECT titre FROM Livre WHERE isbn = %s", (item.isbn,))
            l_row = cur.fetchone()
            book_title = l_row[0] if l_row else "un livre"

            # Trouver les amis qui ont ce livre en collection
            sql_friends_match = """
                SELECT u.id_utilisateur
                FROM Amitie a
                JOIN Utilisateur u ON (
                    (a.utilisateur_1_id = %s AND a.utilisateur_2_id = u.id_utilisateur)
                    OR (a.utilisateur_2_id = %s AND a.utilisateur_1_id = u.id_utilisateur)
                )
                JOIN Collection c ON c.utilisateur_id = u.id_utilisateur
                WHERE a.statut = 'accepte' AND c.livre_isbn = %s
            """
            cur.execute(sql_friends_match, (current_user_id, current_user_id, item.isbn))
            friend_ids = [r[0] for r in cur.fetchall()]

            for f_id in friend_ids:
                notif = create_notification(
                    event_type="wishlist_match",
                    title="Livre recherche par un ami !",
                    message=f"{username} a ajoute '{book_title}' a sa liste de souhaits. Tu l'as en collection !",
                    data={
                        "friend_id": current_user_id,
                        "friend_name": username,
                        "isbn": item.isbn,
                        "book_title": book_title
                    }
                )
                notify_user(f_id, notif)
        except Exception as e:
            # On ne bloque pas l'ajout au souhait si la notification échoue
            print(f"Erreur notification wishlist match: {e}")

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
    unread_messages: int = 0
    pgp_public_key: Optional[str] = None


@app.get("/friends", response_model=List[Friend])
def get_friends(current_user_id: int = Depends(get_current_user_id)):
    """Récupère la liste des amis confirmés de l'utilisateur courant."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        sql = """
            SELECT u.id_utilisateur, u.nom_utilisateur,
                   (SELECT COUNT(*) FROM Message m 
                    WHERE m.expediteur_id = u.id_utilisateur 
                      AND m.destinataire_id = %s 
                      AND m.lu = FALSE) as unread,
                   u.pgp_public_key

            FROM Amitie a
            JOIN Utilisateur u ON (
                (a.utilisateur_1_id = %s AND a.utilisateur_2_id = u.id_utilisateur)
                OR (a.utilisateur_2_id = %s AND a.utilisateur_1_id = u.id_utilisateur)
            )
            WHERE a.statut = 'accepte'
        """
        cur.execute(sql, (current_user_id, current_user_id, current_user_id))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return [Friend(id=row[0], nom=row[1], unread_messages=row[2], pgp_public_key=row[3]) for row in rows]


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

        notification = create_notification(
            event_type="friend_request",
            title="Nouvelle demande d'ami",
            message="Vous avez recu une demande d'ami.",
            data={"from_user_id": current_user_id},
        )
        notify_user(friend_id, notification)
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()
    return {"ok": True}


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


app.include_router(auth_router)
app.include_router(exchanges_router)
app.include_router(payments_router)
app.include_router(stripe_router)
app.include_router(messages_router)
app.include_router(notifications_router)
app.include_router(ia_router)
