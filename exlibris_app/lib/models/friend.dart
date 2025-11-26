class Friend {
  final int id;
  final String nom;
  final String? avatarUrl;

  Friend({required this.id, required this.nom, this.avatarUrl});

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as int,
    nom: json['nom'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'avatar_url': avatarUrl,
  };
}
