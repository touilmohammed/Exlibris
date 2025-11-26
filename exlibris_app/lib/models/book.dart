class Book {
  final String isbn;
  final String titre;
  final String auteur;
  final String? categorie;
  final String? imagePetite;

  Book({
    required this.isbn,
    required this.titre,
    required this.auteur,
    this.categorie,
    this.imagePetite,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      isbn: json['isbn']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      auteur: json['auteur']?.toString() ?? '',
      categorie: json['categorie']?.toString(),
      imagePetite: json['image_petite']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isbn': isbn,
      'titre': titre,
      'auteur': auteur,
      'categorie': categorie,
      'image_petite': imagePetite,
    };
  }

  // Pour pouvoir utiliser contains(), supprimer, etc. sur les listes
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && isbn == other.isbn;

  @override
  int get hashCode => isbn.hashCode;
}
