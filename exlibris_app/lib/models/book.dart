class Book {
  final String isbn;
  final String titre;
  final String auteur;
  final String? categorie;
  final String? imagePetite;
  final String? resume;
  final String? editeur;
  final String? langue;

  Book({
    required this.isbn,
    required this.titre,
    required this.auteur,
    this.categorie,
    this.imagePetite,
    this.resume,
    this.editeur,
    this.langue,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      isbn: json['isbn']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      auteur: json['auteur']?.toString() ?? '',
      categorie: json['categorie']?.toString(),
      imagePetite: json['image_petite']?.toString(),
      resume: json['resume']?.toString(),
      editeur: json['editeur']?.toString(),
      langue: json['langue']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isbn': isbn,
      'titre': titre,
      'auteur': auteur,
      'categorie': categorie,
      'image_petite': imagePetite,
      'resume': resume,
      'editeur': editeur,
      'langue': langue,
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
