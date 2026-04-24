CREATE TABLE Message (
    id_message INT NOT NULL AUTO_INCREMENT,
    expediteur_id INT NOT NULL,
    destinataire_id INT NOT NULL,
    contenu TEXT NOT NULL,
    date_envoi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lu BOOLEAN NOT NULL DEFAULT FALSE,
    
    PRIMARY KEY (id_message),
    KEY ix_message_expediteur (expediteur_id),
    KEY ix_message_destinataire (destinataire_id),

    CONSTRAINT fk_message_expediteur
        FOREIGN KEY (expediteur_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_message_destinataire
        FOREIGN KEY (destinataire_id) REFERENCES Utilisateur(id_utilisateur)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
