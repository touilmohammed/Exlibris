import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/exchange.dart';

void main() {
  group('Exchange Model Tests', () {
    test('fromJson() should correctly parse JSON into an Exchange object', () {
      final json = {
        'id_demande': 1,
        'expediteur_id': 2,
        'destinataire_id': 3,
        'livre_demandeur_isbn': '123',
        'livre_demandeur_titre': 'Book A',
        'livre_destinataire_isbn': '456',
        'livre_destinataire_titre': 'Book B',
        'statut': 'En attente',
        'date_echange': '2026-04-01T10:00:00Z',
      };

      final exchange = Exchange.fromJson(json);

      expect(exchange.id, 1);
      expect(exchange.expediteurId, 2);
      expect(exchange.destinataireId, 3);
      expect(exchange.livreDemandeurIsbn, '123');
      expect(exchange.livreDemandeurTitre, 'Book A');
      expect(exchange.livreDestinataireIsbn, '456');
      expect(exchange.livreDestinataireTitre, 'Book B');
      expect(exchange.statut, 'En attente');
      expect(exchange.dateEchange, DateTime.parse('2026-04-01T10:00:00Z'));
    });

    test('fromJson() should handle nullable fields', () {
      final json = {
        'id_demande': 10,
        'expediteur_id': 20,
        'destinataire_id': null,
        'livre_demandeur_isbn': '111',
        'livre_demandeur_titre': null,
        'livre_destinataire_isbn': '222',
        'livre_destinataire_titre': null,
        'statut': 'Validé',
        'date_echange': '2026-03-01T12:00:00Z',
      };

      final exchange = Exchange.fromJson(json);

      expect(exchange.id, 10);
      expect(exchange.destinataireId, isNull);
      expect(exchange.livreDemandeurTitre, isNull);
      expect(exchange.livreDestinataireTitre, isNull);
    });
  });
}
