import random
import string
import pymysql
from pymysql import MySQLError
import hashlib
from datetime import date

DB = dict(
    host="87.106.141.247",
    port=3306,
    user="exlibris",
    password="exlibris2b",
    database="exlibris",
    charset="utf8mb4",
    cursorclass=pymysql.cursors.Cursor
)

def conn():
    return pymysql.connect(**DB)

def fetch_all_isbns(cur, limit=10000):
    cur.execute("SELECT isbn FROM Livre WHERE isbn IS NOT NULL LIMIT %s", (limit,))
    return [r[0] for r in cur.fetchall()]

def fetch_user_ids(cur):
    cur.execute("SELECT id_utilisateur FROM Utilisateur")
    return [r[0] for r in cur.fetchall()]

def fetch_existing_emails(cur):
    cur.execute("SELECT email FROM Utilisateur")
    return {r[0] for r in cur.fetchall()}

def random_password(length=10):
    chars = string.ascii_letters + string.digits
    return "".join(random.choice(chars) for _ in range(length))

def ensure_users(cur, target_users=30):
    """
    Crée des utilisateurs réalistes jusqu'à atteindre target_users
    (sans supprimer ni modifier ceux existants).
    """
    existing_ids = fetch_user_ids(cur)
    existing_emails = fetch_existing_emails(cur)
    need = max(0, target_users - len(existing_ids))
    if need == 0:
        return existing_ids

    # Données "réalistes" pour une appli de lecture/échange (France majoritaire + un peu de diversité)
    first_names_m = ["Simon", "Mathieu", "Mohammed", "Abdoul", "Habib", "Lucas", "Hugo", "Nicolas", "Yanis", "Karim"]
    first_names_f = ["Inès", "Alice", "Sarah", "Yasmine", "Lina", "Emma", "Chloé", "Nora", "Mariam", "Camille"]
    last_names = ["Rossi", "Martin", "Bernard", "Dubois", "Moreau", "Laurent", "Simon", "Garcia", "Lambert", "Fontaine"]

    # Pays cohérents avec ton champ (pays texte)
    countries = ["France", "Belgique", "Suisse", "Maroc", "Algérie", "Tunisie", "Italie", "Espagne", "Portugal"]
    country_weights = [65, 5, 5, 6, 6, 4, 3, 3, 3]  # France majoritaire

    # Sexe
    sexes = [("Homme", first_names_m), ("Femme", first_names_f)]

    # Rôle : très peu d’admin
    def pick_role():
        return "admin" if random.random() < 0.05 else "lecteur"

    created_ids = []
    for _ in range(need):
        sexe, pool = random.choice(sexes)
        prenom = random.choice(pool)
        nom = random.choice(last_names)
        username = f"{prenom}{nom}{random.randint(10,999)}"

        # Email unique
        base_email = f"{prenom.lower()}.{nom.lower()}@test.com"
        email = base_email
        k = 1
        while email in existing_emails:
            k += 1
            email = f"{prenom.lower()}.{nom.lower()}{k}@test.com"
        existing_emails.add(email)

        age = random.randint(18, 45)
        pays = random.choices(countries, weights=country_weights, k=1)[0]
        role = pick_role()

        # Mot de passe simple pour proto
        mdp = "pass"  # ou random_password()

        cur.execute("""
            INSERT INTO Utilisateur (nom_utilisateur, email, mot_de_passe, age, sexe, pays, role)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (username, email, mdp, age, sexe, pays, role))

        created_ids.append(cur.lastrowid)

    return existing_ids + created_ids

def stable_random_date_from_isbn(isbn: str) -> str:
    """
    Donne une date YYYY-MM-DD stable à partir de l'ISBN.
    Réaliste: majorité après 1990, un peu avant.
    """
    # seed stable via hash
    h = hashlib.sha1(isbn.encode("utf-8", errors="ignore")).hexdigest()
    seed = int(h[:8], 16)
    rng = random.Random(seed)

    # années pondérées (beaucoup de récents)
    # 1950-1989 (10%), 1990-2009 (35%), 2010-2024 (55%)
    p = rng.random()
    if p < 0.10:
        year = rng.randint(1950, 1989)
    elif p < 0.45:
        year = rng.randint(1990, 2009)
    else:
        year = rng.randint(2010, 2024)

    month = rng.randint(1, 12)
    day = rng.randint(1, 28)  # safe pour tous les mois
    return f"{year:04d}-{month:02d}-{day:02d}"

def fill_missing_book_dates(cur, isbns, commit_every=1000):
    """
    Met date_publication pour les livres où elle est NULL.
    Stable et réaliste.
    """
    # On ne met à jour que ceux à NULL
    cur.execute("SELECT COUNT(*) FROM Livre WHERE date_publication IS NULL")
    missing = cur.fetchone()[0]
    if missing == 0:
        print("✅ date_publication déjà renseignée pour tous les livres.")
        return 0

    print(f"🛠️ Remplissage date_publication manquante... (à corriger: {missing})")
    updated = 0

    for i, isbn in enumerate(isbns, start=1):
        # update uniquement si NULL
        pub_date = stable_random_date_from_isbn(isbn)
        cur.execute("""
            UPDATE Livre
            SET date_publication = %s
            WHERE isbn = %s AND date_publication IS NULL
        """, (pub_date, isbn))
        updated += cur.rowcount

        # commits batch (optionnel)
        if commit_every and i % commit_every == 0:
            print(f"  ...progress {i}/{len(isbns)} (updated={updated})")

    print(f"✅ dates ajoutées: {updated}")
    return updated

def ensure_friendships(cur, user_ids, min_friends=2, max_friends=6):
    """
    Remplit Amitie avec des relations acceptées + quelques en_attente.
    Évite les doublons (u1,u2) et (u2,u1).
    """
    # Index des relations existantes
    cur.execute("SELECT utilisateur_1_id, utilisateur_2_id FROM Amitie")
    existing = set()
    for u1, u2 in cur.fetchall():
        existing.add((min(u1,u2), max(u1,u2)))

    inserted = 0

    for u in user_ids:
        target = random.randint(min_friends, max_friends)
        candidates = [x for x in user_ids if x != u]
        random.shuffle(candidates)
        friends = 0

        for v in candidates:
            if friends >= target:
                break
            a, b = min(u,v), max(u,v)
            if (a,b) in existing:
                continue

            statut = "accepte" if random.random() < 0.85 else "en_attente"
            cur.execute("""
                INSERT INTO Amitie (utilisateur_1_id, utilisateur_2_id, statut)
                VALUES (%s, %s, %s)
            """, (a, b, statut))
            existing.add((a,b))
            inserted += 1
            friends += 1

    return inserted

def seed_user_content(cur, user_ids, isbns):
    """
    Remplit Collection, Souhait, Evaluation.
    """
    random.seed(42)

    collection_per_user = (15, 40)
    wishlist_per_user   = (5, 20)
    ratings_per_user    = (10, 30)

    inserted_collection = 0
    inserted_wishlist = 0
    inserted_ratings = 0

    for uid in user_ids:
        # Collection
        col_n = random.randint(*collection_per_user)
        col_books = set(random.sample(isbns, k=min(col_n, len(isbns))))

        for isbn in col_books:
            cur.execute("""
                INSERT IGNORE INTO Collection (utilisateur_id, livre_isbn)
                VALUES (%s, %s)
            """, (uid, isbn))
            inserted_collection += cur.rowcount

        # Wishlist
        wish_n = random.randint(*wishlist_per_user)
        remaining = list(set(isbns) - col_books)
        source = remaining if len(remaining) >= wish_n else isbns
        wish_books = set(random.sample(source, k=min(wish_n, len(source))))

        for isbn in wish_books:
            cur.execute("""
                INSERT IGNORE INTO Souhait (utilisateur_id, livre_isbn)
                VALUES (%s, %s)
            """, (uid, isbn))
            inserted_wishlist += cur.rowcount

        # Evaluations (essentiel pour entraîner)
        rate_n = random.randint(*ratings_per_user)
        rated_candidates = list(col_books)
        if len(rated_candidates) < rate_n:
            rated_candidates += random.sample(isbns, k=min(rate_n - len(rated_candidates), len(isbns)))
        rated_books = random.sample(rated_candidates, k=min(rate_n, len(rated_candidates)))

        for isbn in rated_books :
            # Distribution réaliste
            note = random.choices(
                population=[0,1,2,3,4,5,6,7,8,9,10],
                weights=   [1,1,2,3,6,10,14,18,18,10,5],
                k=1
            )[0]
            if note >= 8:
                avis = "Très bon livre, je recommande."
            elif note <= 3:
                avis = "Je n'ai pas accroché."
            else:
                avis = "Lecture correcte."

            cur.execute("""
                INSERT INTO Evaluation (utilisateur_id, livre_isbn, note, avis)
                VALUES (%s, %s, %s, %s)
            """, (uid, isbn, note, avis))
            inserted_ratings += 1

    return inserted_collection, inserted_wishlist, inserted_ratings

def main():
    cn = conn()
    cur = cn.cursor()

    # 1) livres existants
    isbns = fetch_all_isbns(cur, limit=10000)
    # 1bis) corriger les dates manquantes dans Livre
    fill_missing_book_dates(cur, isbns)
    if not isbns:
        print("❌ Aucun livre dans Livre. Peuple d'abord Livre.")
        cn.close()
        return

    try:
        # 2) utilisateurs
        user_ids_before = fetch_user_ids(cur)
        user_ids = ensure_users(cur, target_users=30)
        created_users = len(user_ids) - len(user_ids_before)

        # 3) amitiés
        inserted_amitie = ensure_friendships(cur, user_ids)

        # 4) contenus user (collection/wishlist/evals)
        inserted_collection, inserted_wishlist, inserted_ratings = seed_user_content(cur, user_ids, isbns)

        cn.commit()

        print("✅ Seed terminé.")
        print(f"Utilisateurs créés: {created_users} (total: {len(user_ids)})")
        print(f"Amitiés insérées: {inserted_amitie}")
        print(f"Collection ajoutée: {inserted_collection}")
        print(f"Wishlist ajoutée: {inserted_wishlist}")
        print(f"Evaluations ajoutées: {inserted_ratings}")

    except MySQLError as e:
        cn.rollback()
        print("❌ Erreur seed:", e)
    finally:
        cur.close()
        cn.close()

if __name__ == "__main__":
    main()
