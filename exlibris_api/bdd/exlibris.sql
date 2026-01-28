-- =========================================================
-- Schéma ExLibris - MariaDB 
-- Contraintes UNIQUE 
-- =========================================================

SET SQL_MODE = "STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION";
SET time_zone = "+00:00";
START TRANSACTION;

-- Pour éviter les soucis d'ordre de drop/create
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS Echange;
DROP TABLE IF EXISTS Suggestion;
DROP TABLE IF EXISTS Diffusion;
DROP TABLE IF EXISTS Amitie;
DROP TABLE IF EXISTS Evaluation;
DROP TABLE IF EXISTS Souhait;
DROP TABLE IF EXISTS Collection;
DROP TABLE IF EXISTS Livre;
DROP TABLE IF EXISTS Categorie;
DROP TABLE IF EXISTS Utilisateur;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------
-- TABLE Utilisateur
-- ---------------------------------------------------------
CREATE TABLE Utilisateur (
  id_utilisateur   INT NOT NULL AUTO_INCREMENT,
  nom_utilisateur  VARCHAR(150) NOT NULL,
  email            VARCHAR(255) NOT NULL,
  mot_de_passe     VARCHAR(255) NOT NULL,  
  age              INT NULL,
  sexe             ENUM('male','femelle','indefini') NULL DEFAULT 'indefini',
  pays             VARCHAR(100) NULL,
  role             ENUM('lecteur','admin') NOT NULL DEFAULT 'lecteur',

  PRIMARY KEY (id_utilisateur),
  UNIQUE KEY ux_utilisateur_email (email),

  CHECK (age IS NULL OR age BETWEEN 0 AND 150)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Categorie
-- ---------------------------------------------------------
CREATE TABLE Categorie (
  id     INT NOT NULL AUTO_INCREMENT,
  nomcat VARCHAR(100) NOT NULL,

  PRIMARY KEY (id),
  UNIQUE KEY ux_categorie_nomcat (nomcat)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Livre
-- ---------------------------------------------------------
CREATE TABLE Livre (
  isbn             VARCHAR(13) NOT NULL,
  titre            VARCHAR(255) NOT NULL,
  auteur           VARCHAR(255) NULL,
  date_publication DATE NULL,
  resume           TEXT NULL,
  editeur          VARCHAR(255) NULL,
  langue           VARCHAR(50) NULL,
  categorie_id     INT NULL,
  statut           ENUM('disponible','indisponible') NOT NULL DEFAULT 'disponible',
  image_petite     TEXT NULL,
  image_moyenne    TEXT NULL,
  image_grande     TEXT NULL,

  PRIMARY KEY (isbn),
  KEY ix_livre_categorie (categorie_id),

  CONSTRAINT fk_livre_categorie
    FOREIGN KEY (categorie_id) REFERENCES Categorie(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Evaluation
-- (1 note par utilisateur et par livre)
-- ---------------------------------------------------------
CREATE TABLE Evaluation (
  id_evaluation   INT NOT NULL AUTO_INCREMENT,
  utilisateur_id  INT NOT NULL,
  livre_isbn      VARCHAR(13) NOT NULL,
  note            INT NULL,
  avis            TEXT NULL,

  PRIMARY KEY (id_evaluation),
  KEY ix_evaluation_user (utilisateur_id),
  KEY ix_evaluation_livre (livre_isbn),

  -- Empêche doublon user+livre
  UNIQUE KEY ux_evaluation_user_livre (utilisateur_id, livre_isbn),

  CONSTRAINT fk_evaluation_user
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_evaluation_livre
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (note IS NULL OR note BETWEEN 0 AND 10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Souhait
-- (1 occurrence max par utilisateur et par livre)
-- ---------------------------------------------------------
CREATE TABLE Souhait (
  id_souhait      INT NOT NULL AUTO_INCREMENT,
  utilisateur_id  INT NOT NULL,
  livre_isbn      VARCHAR(13) NOT NULL,
  date_ajout      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id_souhait),
  KEY ix_souhait_user (utilisateur_id),
  KEY ix_souhait_livre (livre_isbn),

  UNIQUE KEY ux_souhait_user_livre (utilisateur_id, livre_isbn),

  CONSTRAINT fk_souhait_user
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_souhait_livre
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Collection
-- (1 occurrence max par utilisateur et par livre)
-- ---------------------------------------------------------
CREATE TABLE Collection (
  id_collection   INT NOT NULL AUTO_INCREMENT,
  utilisateur_id  INT NOT NULL,
  livre_isbn      VARCHAR(13) NOT NULL,
  date_ajout      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id_collection),
  KEY ix_collection_user (utilisateur_id),
  KEY ix_collection_livre (livre_isbn),

  UNIQUE KEY ux_collection_user_livre (utilisateur_id, livre_isbn),

  CONSTRAINT fk_collection_user
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_collection_livre
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Amitie
-- empêche doublon A-B / B-A grâce à LEAST/GREATEST en colonnes générées
-- ---------------------------------------------------------
CREATE TABLE Amitie (
  id_amitie        INT NOT NULL AUTO_INCREMENT,
  utilisateur_1_id INT NOT NULL,
  utilisateur_2_id INT NOT NULL,
  statut           ENUM('en_attente','accepte') NOT NULL DEFAULT 'en_attente',

  -- Colonnes "normalisées" (A-B == B-A)
  utilisateur_min_id INT AS (LEAST(utilisateur_1_id, utilisateur_2_id)) STORED,
  utilisateur_max_id INT AS (GREATEST(utilisateur_1_id, utilisateur_2_id)) STORED,

  PRIMARY KEY (id_amitie),
  KEY ix_amitie_u1 (utilisateur_1_id),
  KEY ix_amitie_u2 (utilisateur_2_id),

  -- Une seule relation par paire d’utilisateurs (peu importe l'ordre)
  UNIQUE KEY ux_amitie_pair (utilisateur_min_id, utilisateur_max_id),

  CONSTRAINT fk_amitie_u1
    FOREIGN KEY (utilisateur_1_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_amitie_u2
    FOREIGN KEY (utilisateur_2_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (utilisateur_1_id <> utilisateur_2_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Suggestion
-- empêche doublons exacts + empêche auto-suggestion
-- ---------------------------------------------------------
CREATE TABLE Suggestion (
  id_suggestion    INT NOT NULL AUTO_INCREMENT,
  expediteur_id    INT NOT NULL,
  destinataire_id  INT NOT NULL,
  livre_isbn       VARCHAR(13) NOT NULL,
  date_suggestion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  acceptee         TINYINT(1) NOT NULL DEFAULT 0,

  PRIMARY KEY (id_suggestion),
  KEY ix_suggestion_expediteur (expediteur_id),
  KEY ix_suggestion_destinataire (destinataire_id),
  KEY ix_suggestion_livre (livre_isbn),

  -- 1 suggestion "identique" max
  UNIQUE KEY ux_suggestion_triplet (expediteur_id, destinataire_id, livre_isbn),

  CONSTRAINT fk_suggestion_expediteur
    FOREIGN KEY (expediteur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_suggestion_destinataire
    FOREIGN KEY (destinataire_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_suggestion_livre
    FOREIGN KEY (livre_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (acceptee IN (0,1)),
  CHECK (expediteur_id <> destinataire_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Diffusion
-- ---------------------------------------------------------
CREATE TABLE Diffusion (
  id_diffusion  INT NOT NULL AUTO_INCREMENT,
  titre         VARCHAR(255) NULL,
  contenu       TEXT NULL,
  type_contenu  ENUM('texte','image','lien','fiche_livre') NOT NULL DEFAULT 'texte',
  diffuseur_id  INT NOT NULL,
  date_debut    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_fin      DATETIME NULL,
  actif         TINYINT(1) NOT NULL DEFAULT 1,
  visibilite    ENUM('publique','amis','privee') NOT NULL DEFAULT 'publique',

  PRIMARY KEY (id_diffusion),
  KEY ix_diffusion_diffuseur (diffuseur_id),

  CONSTRAINT fk_diffusion_diffuseur
    FOREIGN KEY (diffuseur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (actif IN (0,1)),
  CHECK (date_fin IS NULL OR date_fin >= date_debut)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------
-- TABLE Echange
-- + empêche échange avec soi-même
-- + empêche même livre des deux côtés
-- ---------------------------------------------------------
CREATE TABLE Echange (
  id_echange               INT NOT NULL AUTO_INCREMENT,
  demandeur_id             INT NOT NULL,
  destinataire_id          INT NOT NULL,
  livre_demandeur_isbn     VARCHAR(13) NOT NULL,
  livre_destinataire_isbn  VARCHAR(13) NOT NULL,
  statut ENUM(
    'demande_envoyee',
    'demande_acceptee',
    'demande_refusee',
    'proposition_confirmee',
    'annule',
    'termine'
  ) NOT NULL DEFAULT 'demande_envoyee',
  date_creation     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_derniere_maj DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id_echange),
  KEY ix_echange_demandeur (demandeur_id),
  KEY ix_echange_destinataire (destinataire_id),
  KEY ix_echange_livre_demandeur (livre_demandeur_isbn),
  KEY ix_echange_livre_destinataire (livre_destinataire_isbn),

  CONSTRAINT fk_echange_demandeur
    FOREIGN KEY (demandeur_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_echange_destinataire
    FOREIGN KEY (destinataire_id) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_echange_livre_demandeur
    FOREIGN KEY (livre_demandeur_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CONSTRAINT fk_echange_livre_destinataire
    FOREIGN KEY (livre_destinataire_isbn) REFERENCES Livre(isbn)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (demandeur_id <> destinataire_id),
  CHECK (livre_demandeur_isbn <> livre_destinataire_isbn)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


COMMIT;
