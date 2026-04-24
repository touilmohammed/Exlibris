class Friend {
  final int id;
  final String nom;
  final String? avatarUrl;
  final int unreadMessages;
  final String? pgpPublicKey;

  Friend({
    required this.id,
    required this.nom,
    this.avatarUrl,
    this.unreadMessages = 0,
    this.pgpPublicKey,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as int,
    nom: json['nom'] as String,
    avatarUrl: json['avatar_url'] as String?,
    unreadMessages: json['unread_messages'] as int? ?? 0,
    pgpPublicKey: json['pgp_public_key'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'avatar_url': avatarUrl,
    'unread_messages': unreadMessages,
    'pgp_public_key': pgpPublicKey,
  };
}
