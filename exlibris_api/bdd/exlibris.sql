-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Hôte : mariadb
-- Généré le : mar. 20 jan. 2026 à 14:12
-- Version du serveur : 11.7.2-MariaDB-ubu2404
-- Version de PHP : 8.2.27

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `exlibris`
--

-- --------------------------------------------------------

--
-- Structure de la table `Amitie`
--

CREATE TABLE `Amitie` (
  `id_amitie` int(11) NOT NULL,
  `utilisateur_1_id` int(11) NOT NULL,
  `utilisateur_2_id` int(11) NOT NULL,
  `statut` enum('en_attente','accepte') DEFAULT 'en_attente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Categorie`
--

CREATE TABLE `Categorie` (
  `id` int(11) NOT NULL,
  `nomcat` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Collection`
--

CREATE TABLE `Collection` (
  `id_collection` int(11) NOT NULL,
  `utilisateur_id` int(11) NOT NULL,
  `livre_isbn` varchar(13) NOT NULL,
  `date_ajout` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Diffusion`
--

CREATE TABLE `Diffusion` (
  `id_diffusion` int(11) NOT NULL,
  `titre` varchar(255) DEFAULT NULL,
  `contenu` text DEFAULT NULL,
  `type_contenu` enum('texte','image','lien','fiche_livre') DEFAULT 'texte',
  `diffuseur_id` int(11) NOT NULL,
  `date_debut` datetime DEFAULT current_timestamp(),
  `date_fin` datetime DEFAULT NULL,
  `actif` tinyint(1) DEFAULT 1,
  `visibilite` enum('publique','amis','privee') DEFAULT 'publique'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Echange`
--

CREATE TABLE `Echange` (
  `id_demande` int(11) NOT NULL,
  `expediteur_id` int(11) NOT NULL,
  `livre_demandeur_isbn` varchar(13) NOT NULL,
  `livre_destinataire_isbn` varchar(13) NOT NULL,
  `date_echange` datetime DEFAULT current_timestamp(),
  `statut` enum('demande_envoyee','demande_acceptee_refusee','proposition_confirmee','annulee','terminee') DEFAULT 'demande_envoyee'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Evaluation`
--

CREATE TABLE `Evaluation` (
  `id_evaluation` int(11) NOT NULL,
  `utilisateur_id` int(11) NOT NULL,
  `livre_isbn` varchar(13) NOT NULL,
  `note` int(11) DEFAULT NULL CHECK (`note` between 0 and 10),
  `avis` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Livre`
--

CREATE TABLE `Livre` (
  `isbn` varchar(13) NOT NULL,
  `titre` varchar(255) NOT NULL,
  `auteur` varchar(255) DEFAULT NULL,
  `date_publication` date DEFAULT NULL,
  `resume` text DEFAULT NULL,
  `editeur` varchar(255) DEFAULT NULL,
  `langue` varchar(50) DEFAULT NULL,
  `categorie_id` int(11) DEFAULT NULL,
  `statut` enum('disponible','indisponible') DEFAULT 'disponible',
  `image_petite` text DEFAULT NULL,
  `image_moyenne` text DEFAULT NULL,
  `image_grande` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Souhait`
--

CREATE TABLE `Souhait` (
  `id_souhait` int(11) NOT NULL,
  `utilisateur_id` int(11) NOT NULL,
  `livre_isbn` varchar(13) NOT NULL,
  `date_ajout` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Suggestion`
--

CREATE TABLE `Suggestion` (
  `id_suggestion` int(11) NOT NULL,
  `expediteur_id` int(11) NOT NULL,
  `destinataire_id` int(11) NOT NULL,
  `livre_isbn` varchar(13) NOT NULL,
  `date_suggestion` datetime DEFAULT current_timestamp(),
  `acceptee` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure de la table `Utilisateur`
--

CREATE TABLE `Utilisateur` (
  `id_utilisateur` int(11) NOT NULL,
  `nom_utilisateur` varchar(150) NOT NULL,
  `email` varchar(255) NOT NULL,
  `mot_de_passe` varchar(128) NOT NULL,
  `age` int(11) DEFAULT NULL,
  `sexe` varchar(20) DEFAULT NULL,
  `religion` varchar(100) DEFAULT NULL,
  `pays` varchar(100) DEFAULT NULL,
  `role` enum('lecteur','admin') DEFAULT 'lecteur'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `Amitie`
--
ALTER TABLE `Amitie`
  ADD PRIMARY KEY (`id_amitie`),
  ADD KEY `utilisateur_1_id` (`utilisateur_1_id`),
  ADD KEY `utilisateur_2_id` (`utilisateur_2_id`);

--
-- Index pour la table `Categorie`
--
ALTER TABLE `Categorie`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `Collection`
--
ALTER TABLE `Collection`
  ADD PRIMARY KEY (`id_collection`),
  ADD KEY `utilisateur_id` (`utilisateur_id`),
  ADD KEY `livre_isbn` (`livre_isbn`);

--
-- Index pour la table `Diffusion`
--
ALTER TABLE `Diffusion`
  ADD PRIMARY KEY (`id_diffusion`),
  ADD KEY `diffuseur_id` (`diffuseur_id`);

--
-- Index pour la table `Echange`
--
ALTER TABLE `Echange`
  ADD PRIMARY KEY (`id_demande`),
  ADD KEY `expediteur_id` (`expediteur_id`),
  ADD KEY `livre_demandeur_isbn` (`livre_demandeur_isbn`),
  ADD KEY `livre_destinataire_isbn` (`livre_destinataire_isbn`);

--
-- Index pour la table `Evaluation`
--
ALTER TABLE `Evaluation`
  ADD PRIMARY KEY (`id_evaluation`),
  ADD KEY `utilisateur_id` (`utilisateur_id`),
  ADD KEY `livre_isbn` (`livre_isbn`);

--
-- Index pour la table `Livre`
--
ALTER TABLE `Livre`
  ADD PRIMARY KEY (`isbn`),
  ADD KEY `categorie_id` (`categorie_id`);

--
-- Index pour la table `Souhait`
--
ALTER TABLE `Souhait`
  ADD PRIMARY KEY (`id_souhait`),
  ADD KEY `utilisateur_id` (`utilisateur_id`),
  ADD KEY `livre_isbn` (`livre_isbn`);

--
-- Index pour la table `Suggestion`
--
ALTER TABLE `Suggestion`
  ADD PRIMARY KEY (`id_suggestion`),
  ADD KEY `expediteur_id` (`expediteur_id`),
  ADD KEY `destinataire_id` (`destinataire_id`),
  ADD KEY `livre_isbn` (`livre_isbn`);

--
-- Index pour la table `Utilisateur`
--
ALTER TABLE `Utilisateur`
  ADD PRIMARY KEY (`id_utilisateur`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT pour les tables déchargées
--

--
-- AUTO_INCREMENT pour la table `Amitie`
--
ALTER TABLE `Amitie`
  MODIFY `id_amitie` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Categorie`
--
ALTER TABLE `Categorie`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Collection`
--
ALTER TABLE `Collection`
  MODIFY `id_collection` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Diffusion`
--
ALTER TABLE `Diffusion`
  MODIFY `id_diffusion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Echange`
--
ALTER TABLE `Echange`
  MODIFY `id_demande` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Evaluation`
--
ALTER TABLE `Evaluation`
  MODIFY `id_evaluation` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Souhait`
--
ALTER TABLE `Souhait`
  MODIFY `id_souhait` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Suggestion`
--
ALTER TABLE `Suggestion`
  MODIFY `id_suggestion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `Utilisateur`
--
ALTER TABLE `Utilisateur`
  MODIFY `id_utilisateur` int(11) NOT NULL AUTO_INCREMENT;

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `Amitie`
--
ALTER TABLE `Amitie`
  ADD CONSTRAINT `Amitie_ibfk_1` FOREIGN KEY (`utilisateur_1_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Amitie_ibfk_2` FOREIGN KEY (`utilisateur_2_id`) REFERENCES `Utilisateur` (`id_utilisateur`);

--
-- Contraintes pour la table `Collection`
--
ALTER TABLE `Collection`
  ADD CONSTRAINT `Collection_ibfk_1` FOREIGN KEY (`utilisateur_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Collection_ibfk_2` FOREIGN KEY (`livre_isbn`) REFERENCES `Livre` (`isbn`);

--
-- Contraintes pour la table `Diffusion`
--
ALTER TABLE `Diffusion`
  ADD CONSTRAINT `Diffusion_ibfk_1` FOREIGN KEY (`diffuseur_id`) REFERENCES `Utilisateur` (`id_utilisateur`);

--
-- Contraintes pour la table `Echange`
--
ALTER TABLE `Echange`
  ADD CONSTRAINT `Echange_ibfk_1` FOREIGN KEY (`expediteur_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Echange_ibfk_2` FOREIGN KEY (`livre_demandeur_isbn`) REFERENCES `Livre` (`isbn`),
  ADD CONSTRAINT `Echange_ibfk_3` FOREIGN KEY (`livre_destinataire_isbn`) REFERENCES `Livre` (`isbn`);

--
-- Contraintes pour la table `Evaluation`
--
ALTER TABLE `Evaluation`
  ADD CONSTRAINT `Evaluation_ibfk_1` FOREIGN KEY (`utilisateur_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Evaluation_ibfk_2` FOREIGN KEY (`livre_isbn`) REFERENCES `Livre` (`isbn`);

--
-- Contraintes pour la table `Livre`
--
ALTER TABLE `Livre`
  ADD CONSTRAINT `Livre_ibfk_1` FOREIGN KEY (`categorie_id`) REFERENCES `Categorie` (`id`);

--
-- Contraintes pour la table `Souhait`
--
ALTER TABLE `Souhait`
  ADD CONSTRAINT `Souhait_ibfk_1` FOREIGN KEY (`utilisateur_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Souhait_ibfk_2` FOREIGN KEY (`livre_isbn`) REFERENCES `Livre` (`isbn`);

--
-- Contraintes pour la table `Suggestion`
--
ALTER TABLE `Suggestion`
  ADD CONSTRAINT `Suggestion_ibfk_1` FOREIGN KEY (`expediteur_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Suggestion_ibfk_2` FOREIGN KEY (`destinataire_id`) REFERENCES `Utilisateur` (`id_utilisateur`),
  ADD CONSTRAINT `Suggestion_ibfk_3` FOREIGN KEY (`livre_isbn`) REFERENCES `Livre` (`isbn`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
