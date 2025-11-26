class Rating {
  final String isbn;
  final int note;
  final String? avis;

  const Rating({required this.isbn, required this.note, this.avis});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      isbn: json['isbn'] as String,
      note: json['note'] as int,
      avis: json['avis'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'isbn': isbn, 'note': note, 'avis': avis};
  }
}
