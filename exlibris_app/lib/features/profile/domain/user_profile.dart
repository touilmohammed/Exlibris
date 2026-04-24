class UserProfile {
  final int id;
  final String nomUtilisateur;
  final String email;
  final int? age;
  final String? sexe;
  final String? pays;
  final int nbLivresCollection;
  final int nbLivresWishlist;
  final int nbAmis;
  final String? pgpPublicKey;
  final String? pgpPrivateKeyEnc;

  UserProfile({
    required this.id,
    required this.nomUtilisateur,
    required this.email,
    this.age,
    this.sexe,
    this.pays,
    this.nbLivresCollection = 0,
    this.nbLivresWishlist = 0,
    this.nbAmis = 0,
    this.pgpPublicKey,
    this.pgpPrivateKeyEnc,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      nomUtilisateur: json['nom_utilisateur'] as String,
      email: json['email'] as String,
      age: json['age'] as int?,
      sexe: json['sexe'] as String?,
      pays: json['pays'] as String?,
      nbLivresCollection: json['nb_livres_collection'] as int? ?? 0,
      nbLivresWishlist: json['nb_livres_wishlist'] as int? ?? 0,
      nbAmis: json['nb_amis'] as int? ?? 0,
      pgpPublicKey: json['pgp_public_key'] as String?,
      pgpPrivateKeyEnc: json['pgp_private_key_enc'] as String?,
    );
  }
}
