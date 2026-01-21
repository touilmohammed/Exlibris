class Exchange {
  final int id;
  final int expediteurId;
  final String livreDemandeurIsbn;
  final String? livreDemandeurTitre;
  final String livreDestinataireIsbn;
  final String? livreDestinataireTitre;
  final String statut;
  final DateTime dateEchange;

  Exchange({
    required this.id,
    required this.expediteurId,
    required this.livreDemandeurIsbn,
    this.livreDemandeurTitre,
    required this.livreDestinataireIsbn,
    this.livreDestinataireTitre,
    required this.statut,
    required this.dateEchange,
  });

  factory Exchange.fromJson(Map<String, dynamic> json) {
    return Exchange(
      id: json['id_demande'] as int,
      expediteurId: json['expediteur_id'] as int,
      livreDemandeurIsbn: json['livre_demandeur_isbn'] as String,
      livreDemandeurTitre: json['livre_demandeur_titre'] as String?,
      livreDestinataireIsbn: json['livre_destinataire_isbn'] as String,
      livreDestinataireTitre: json['livre_destinataire_titre'] as String?,
      statut: json['statut'] as String,
      dateEchange: DateTime.parse(json['date_echange'] as String),
    );
  }
}
