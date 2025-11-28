class Exchange {
  final int id;
  final int demandeurId;
  final int destinataireId;
  final String livreDemandeurIsbn;
  final String livreDestinataireIsbn;
  final String statut;
  final DateTime dateCreation;
  final DateTime? dateDerniereMaj;

  Exchange({
    required this.id,
    required this.demandeurId,
    required this.destinataireId,
    required this.livreDemandeurIsbn,
    required this.livreDestinataireIsbn,
    required this.statut,
    required this.dateCreation,
    this.dateDerniereMaj,
  });

  factory Exchange.fromJson(Map<String, dynamic> json) {
    return Exchange(
      id: json['id_echange'] as int,
      demandeurId: json['demandeur_id'] as int,
      destinataireId: json['destinataire_id'] as int,
      livreDemandeurIsbn: json['livre_demandeur_isbn'] as String,
      livreDestinataireIsbn: json['livre_destinataire_isbn'] as String,
      statut: json['statut'] as String,
      dateCreation: DateTime.parse(json['date_creation'] as String),
      dateDerniereMaj: json['date_derniere_maj'] != null
          ? DateTime.parse(json['date_derniere_maj'] as String)
          : null,
    );
  }
}
