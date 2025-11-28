-- Active les FK pour SQLite (utile si tu lances ce script dans un outil)
PRAGMA foreign_keys = ON;

-- ===========================
-- TABLE Utilisateur
-- ===========================
CREATE TABLE IF NOT EXISTS Utilisateur (
    id_utilisateur     INTEGER PRIMARY KEY AUTOINCREMENT,
    nom_utilisateur    TEXT NOT NULL,
    email              TEXT NOT NULL UNIQUE,
    mot_de_passe       TEXT NOT NULL,
    age                INTEGER,
    ville              TEXT,
    region             TEXT,
    pays               TEXT,
    role               TEXT NOT NULL DEFAULT 'lecteur'
        CHECK (role IN ('lecteur', 'admin'))
);

-- ===========================
-- TABLE Livre
-- (si elle existe déjà avec ces colonnes, IF NOT EXISTS ne fera rien)
-- ===========================
CREATE TABLE IF NOT EXISTS Livre (
    isbn              TEXT PRIMARY KEY,
    titre             TEXT NOT NULL,
    auteur            TEXT,
    annee_publication INTEGER,
    editeur           TEXT,
    resume            TEXT,
    langue            TEXT,
    categorie         TEXT,
    image_petite      TEXT,
    image_moyenne     TEXT,
    image_grande      TEXT
);

-- ===========================
-- TABLE Evaluation
-- ===========================
CREATE TABLE IF NOT EXISTS Evaluation (
    id_evaluation   INTEGER PRIMARY KEY AUTOINCREMENT,
    utilisateur_id  INTEGER NOT NULL,
    livre_isbn      TEXT NOT NULL,
    note            INTEGER NOT NULL CHECK (note BETWEEN 0 AND 10),
    avis            TEXT,
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
        ON DELETE CASCADE
);

-- ===========================
-- TABLE Souhait (wishlist)
-- ===========================
CREATE TABLE IF NOT EXISTS Souhait (
    id_souhait      INTEGER PRIMARY KEY AUTOINCREMENT,
    utilisateur_id  INTEGER NOT NULL,
    livre_isbn      TEXT NOT NULL,
    date_ajout      TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
        ON DELETE CASCADE
);

-- ===========================
-- TABLE Collection
-- ===========================
CREATE TABLE IF NOT EXISTS Collection (
    id_collection   INTEGER PRIMARY KEY AUTOINCREMENT,
    utilisateur_id  INTEGER NOT NULL,
    livre_isbn      TEXT NOT NULL,
    date_ajout      TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
        ON DELETE CASCADE
);

-- ===========================
-- TABLE Amitie
-- ===========================
CREATE TABLE IF NOT EXISTS Amitie (
    id_amitie       INTEGER PRIMARY KEY AUTOINCREMENT,
    utilisateur_1_id INTEGER NOT NULL,
    utilisateur_2_id INTEGER NOT NULL,
    statut          TEXT NOT NULL DEFAULT 'en_attente'
        CHECK (statut IN ('en_attente', 'accepte')),
    FOREIGN KEY (utilisateur_1_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (utilisateur_2_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE
);

-- ===========================
-- TABLE Suggestion
-- ===========================
CREATE TABLE IF NOT EXISTS Suggestion (
    id_suggestion   INTEGER PRIMARY KEY AUTOINCREMENT,
    expediteur_id   INTEGER NOT NULL,
    destinataire_id INTEGER NOT NULL,
    livre_isbn      TEXT NOT NULL,
    date_suggestion TEXT DEFAULT (datetime('now')),
    acceptee        INTEGER NOT NULL DEFAULT 0
        CHECK (acceptee IN (0, 1)),
    FOREIGN KEY (expediteur_id)   REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (destinataire_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE,
    FOREIGN KEY (livre_isbn)      REFERENCES Livre(isbn)
        ON DELETE CASCADE
);

-- ===========================
-- TABLE Echange
-- ===========================
CREATE TABLE IF NOT EXISTS Echange (
    id_echange INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Qui a initié l'échange
    demandeur_id INTEGER NOT NULL,

    -- L'ami à qui on propose l'échange
    destinataire_id INTEGER NOT NULL,

    -- Livre que le demandeur propose
    livre_demandeur_isbn TEXT NOT NULL,

    -- Livre que le destinataire devra donner en échange
    livre_destinataire_isbn TEXT NOT NULL,

    -- état global de l’échange
    statut TEXT NOT NULL CHECK (
        statut IN (
            'demande_envoyee',   -- tu viens de proposer l'échange
            'demande_acceptee',  -- l’autre accepte le principe
            'demande_refusee',   -- l’autre refuse
            'proposition_confirmee', -- les deux confirment les livres
            'annule',            -- annulé par l’un des deux
            'termine'            -- échange finalisé
        )
    ),

    date_creation      DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_derniere_maj  DATETIME,

    FOREIGN KEY (demandeur_id) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (destinataire_id) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (livre_demandeur_isbn) REFERENCES Livre(isbn),
    FOREIGN KEY (livre_destinataire_isbn) REFERENCES Livre(isbn)
);

