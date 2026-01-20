class UserProfile {
  final int id;
  final String nomUtilisateur;
  final String email;
  final int nbLivresCollection;
  final int nbLivresWishlist;
  final int nbAmis;

  UserProfile({
    required this.id,
    required this.nomUtilisateur,
    required this.email,
    this.nbLivresCollection = 0,
    this.nbLivresWishlist = 0,
    this.nbAmis = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      nomUtilisateur: json['nom_utilisateur'] as String,
      email: json['email'] as String,
      nbLivresCollection: json['nb_livres_collection'] as int? ?? 0,
      nbLivresWishlist: json['nb_livres_wishlist'] as int? ?? 0,
      nbAmis: json['nb_amis'] as int? ?? 0,
    );
  }
}
