ALTER TABLE Utilisateur
    ADD COLUMN mot_de_passe_hash VARCHAR(255) NULL AFTER mot_de_passe,
    ADD COLUMN email_verifie TINYINT(1) NOT NULL DEFAULT 0 AFTER mot_de_passe_hash,
    ADD COLUMN date_creation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER role;

CREATE TABLE IF NOT EXISTS email_verification (
    id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    code VARCHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    used_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    KEY ix_email_verification_user (user_id),
    KEY ix_email_verification_code (code),
    KEY ix_email_verification_expires_at (expires_at),

    CONSTRAINT fk_email_verification_user
        FOREIGN KEY (user_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;