import os
import csv
import hashlib
from datetime import datetime
import pymysql
from pymysql import MySQLError

# ----------------------------
# Connexion MariaDB
# ----------------------------
def get_connection():
    return pymysql.connect(
        host="87.106.141.247",
        port=3306,
        user="exlibris",
        password="exlibris2b",
        database="exlibris",
        charset="utf8mb4",
        cursorclass=pymysql.cursors.Cursor,
        autocommit=False,
    )

# ----------------------------
# Helpers
# ----------------------------
def clean_str(x):
    if x is None:
        return None
    x = str(x).strip()
    return x if x != "" else None

def make_fake_isbn(title, author, publisher):
    """
    Si le CSV n'a pas d'ISBN fiable : on crée un identifiant stable (13 chars)
    à partir d'un hash. (Ce n'est pas un vrai ISBN, mais unique et stable.)
    """
    base = f"{title}|{author}|{publisher}".encode("utf-8", errors="ignore")
    h = hashlib.sha1(base).hexdigest()  # 40 chars
    digits = "".join([c for c in h if c.isdigit()])  # garder chiffres
    if len(digits) < 13:
        digits = (digits + "0" * 13)[:13]
    return digits[:13]

def to_date(value):
    if not value:
        return None
    v = str(value).strip()
    if v == "":
        return None
    # essaie YYYY-MM-DD
    try:
        datetime.strptime(v, "%Y-%m-%d")
        return v
    except:
        pass
    # essaie YYYY
    if len(v) == 4 and v.isdigit():
        return f"{v}-01-01"
    return None

def load_categories(cur):
    cur.execute("SELECT id, nomcat FROM Categorie")
    return {name.lower(): cid for cid, name in cur.fetchall()}

def get_or_create_category(cur, cache, cat_name):
    if not cat_name:
        return None
    key = cat_name.strip().lower()
    if key in cache:
        return cache[key]
    # créer si pas existante
    cur.execute("INSERT INTO Categorie (nomcat) VALUES (%s)", (cat_name.strip(),))
    cid = cur.lastrowid
    cache[key] = cid
    return cid

# ----------------------------
# Import principal
# ----------------------------
def import_preprocessed(csv_path, delimiter=",", batch_size=2000, limit=None):
    conn = get_connection()
    cur = conn.cursor()

    # cache catégories
    cat_cache = load_categories(cur)

    inserted = 0
    skipped = 0
    batch = []

    print(f"📂 Import: {csv_path}")
    print(f"➡️ delimiter={delimiter} batch_size={batch_size}")

    with open(csv_path, "r", encoding="utf-8", errors="ignore", newline="") as f:
        reader = csv.DictReader(f, delimiter=delimiter)

        # Colonnes typiques attendues du Preprocessed_data.csv
        # book_title, book_author, publisher, Summary, Category, img_m
        for i, row in enumerate(reader, start=1):
            if limit and i > limit:
                break

            title = clean_str(row.get("book_title") or row.get("title") or row.get("titre"))
            author = clean_str(row.get("book_author") or row.get("author") or row.get("auteur"))
            publisher = clean_str(row.get("publisher") or row.get("editeur"))
            summary = clean_str(row.get("Summary") or row.get("summary") or row.get("resume"))
            category_name = clean_str(row.get("Category") or row.get("category") or row.get("categorie"))
            img = clean_str(row.get("img_m") or row.get("image_moyenne") or row.get("image"))

            # date si existante (souvent pas dans ce CSV)
            pub_date = to_date(row.get("date_publication") or row.get("publication_date") or row.get("year"))

            # ISBN si présent, sinon hash stable
            isbn = clean_str(row.get("isbn"))
            if not isbn or len(isbn) < 10:
                isbn = make_fake_isbn(title or "", author or "", publisher or "")

            # si pas de titre, on skip (inutile)
            if not title:
                skipped += 1
                continue

            # catégorie -> id
            categorie_id = None
            if category_name:
                categorie_id = get_or_create_category(cur, cat_cache, category_name)

            # Construire tuple pour insert
            batch.append((
                isbn[:13],
                title[:255],
                (author or "")[:255],
                pub_date,
                summary,
                (publisher or "")[:255],
                "fr",  # si ton dataset est francophone; sinon row.get("langue")
                categorie_id,
                "disponible",
                None,      # image_petite
                img,       # image_moyenne
                None       # image_grande
            ))

            if len(batch) >= batch_size:
                inserted, skipped = flush_batch(cur, conn, batch, inserted, skipped)
                batch = []

        # flush final
        if batch:
            inserted, skipped = flush_batch(cur, conn, batch, inserted, skipped)

    cur.close()
    conn.close()
    print(f"✅ Terminé. inserted={inserted} skipped={skipped}")

def flush_batch(cur, conn, batch, inserted, skipped):
    try:
        # ON DUPLICATE KEY UPDATE pour éviter que ça casse sur ISBN déjà présent
        cur.executemany("""
            INSERT INTO Livre (
                isbn, titre, auteur, date_publication,
                resume, editeur, langue, categorie_id,
                statut, image_petite, image_moyenne, image_grande
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE
                titre=VALUES(titre),
                auteur=VALUES(auteur),
                date_publication=VALUES(date_publication),
                resume=VALUES(resume),
                editeur=VALUES(editeur),
                langue=VALUES(langue),
                categorie_id=VALUES(categorie_id),
                statut=VALUES(statut),
                image_moyenne=VALUES(image_moyenne)
        """, batch)
        conn.commit()
        inserted += len(batch)
        print(f"✔ batch inséré: +{len(batch)} (total {inserted})")
    except Exception as e:
        conn.rollback()
        skipped += len(batch)
        print(f"⚠️ batch rollback (skipped +{len(batch)}): {e}")
    return inserted, skipped

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python import_preprocessed_books.py <Preprocessed_data.csv> [delimiter]")
        raise SystemExit(1)
    path = sys.argv[1]
    delim = sys.argv[2] if len(sys.argv) >= 3 else ","
    import_preprocessed(path, delimiter=delim, batch_size=2000)
