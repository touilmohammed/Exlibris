ALTER TABLE Echange
MODIFY COLUMN statut ENUM(
    'demande_envoyee',
    'demande_acceptee',
    'paiement_en_attente',
    'paiement_effectue',
    'expedition_confirmee',
    'reception_confirmee',
    'demande_refusee',
    'annule',
    'termine'
) NOT NULL DEFAULT 'demande_envoyee';

CREATE TABLE IF NOT EXISTS PaiementEchange (
    id_paiement INT NOT NULL AUTO_INCREMENT,
    echange_id INT NOT NULL,
    payeur_id INT NOT NULL,
    montant DECIMAL(10,2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'EUR',
    provider VARCHAR(50) NOT NULL DEFAULT 'sandbox',
    provider_session_id VARCHAR(255) NULL,
    provider_payment_intent_id VARCHAR(255) NULL,
    statut ENUM(
        'en_attente',
        'paye',
        'echoue',
        'rembourse',
        'libere'
    ) NOT NULL DEFAULT 'en_attente',
    date_creation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_paiement DATETIME NULL,
    date_derniere_maj DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id_paiement),
    KEY ix_paiement_echange (echange_id),
    KEY ix_paiement_payeur (payeur_id),

    CONSTRAINT fk_paiement_echange
        FOREIGN KEY (echange_id) REFERENCES Echange(id_echange)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_paiement_payeur
        FOREIGN KEY (payeur_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;