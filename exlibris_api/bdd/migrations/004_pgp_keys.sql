ALTER TABLE Utilisateur
ADD COLUMN pgp_public_key TEXT NULL,
ADD COLUMN pgp_private_key_enc TEXT NULL;
