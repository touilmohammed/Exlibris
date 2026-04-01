import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/exchanges/presentation/exchanges_page.dart';
import 'package:flutter_application_1/features/exchanges/data/exchanges_repository.dart';
import 'package:flutter_application_1/features/profile/data/profile_repository.dart';
import 'package:flutter_application_1/features/profile/domain/user_profile.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/models/exchange.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

class MockExchangesRepository extends FakeExchangesRepository {
  bool cancelCalled = false;
  bool acceptCalled = false;
  bool refuseCalled = false;

  @override
  Future<List<Exchange>> getMyExchanges() async => [
    Exchange(
      id: 1,
      expediteurId: 1,
      destinataireId: 2,
      livreDemandeurIsbn: 'LIVRE1',
      livreDestinataireIsbn: 'LIVRE2',
      statut: 'demande_envoyee',
      dateEchange: DateTime.now(),
      livreDemandeurTitre: 'Livre 1',
      livreDestinataireTitre: 'Livre 2',
    ),
    Exchange(
      id: 2,
      expediteurId: 3,
      destinataireId: 1,
      livreDemandeurIsbn: 'LIVRE3',
      livreDestinataireIsbn: 'LIVRE4',
      statut: 'demande_envoyee',
      dateEchange: DateTime.now(),
      livreDemandeurTitre: 'Livre 3',
      livreDestinataireTitre: 'Livre 4',
    ),
  ];

  @override
  Future<void> cancelExchange(int id) async {
    cancelCalled = true;
  }

  @override
  Future<void> acceptExchange(int id) async {
    acceptCalled = true;
  }

  @override
  Future<void> refuseExchange(int id) async {
    refuseCalled = true;
  }
}

class MockExchangesProfileRepo extends FakeProfileRepository {
  @override
  Future<UserProfile> getMyProfile() async =>
      UserProfile(id: 1, nomUtilisateur: 'TestUser', email: 'test@test.com');
}

void main() {
  group('ExchangesPage Tests', () {
    Widget createTestEnv(WidgetTester tester, MockExchangesRepository repo) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return createTestWidget(
        child: const Scaffold(body: ExchangesPage()),
        overrides: [
          exchangesRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(
            MockExchangesProfileRepo(),
          ),
          booksRepositoryProvider.overrideWithValue(FakeBooksRepository()),
        ],
      );
    }

    testWidgets('renders exchanges and buttons depending on role', (
      tester,
    ) async {
      final repo = MockExchangesRepository();

      await tester.pumpWidget(createTestEnv(tester, repo));
      await tester.pumpAndSettle();

      expect(find.text('Echanges'), findsOneWidget);
      expect(find.text('Tes propositions et leur statut'), findsOneWidget);

      // Total 'En attente': 1 in overview + 1 in filter + 2 in the cards
      expect(find.text('En attente'), findsNWidgets(4));

      // First exchange: Sender can cancel (id: 1 is expeditions)
      expect(find.text('Annuler la demande'), findsOneWidget);

      // Second exchange: Receiver can accept/refuse (id: 1 is destinataire)
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);

      // Test actions
      await tester.tap(find.text('Annuler la demande'));
      await tester.pump();
      expect(repo.cancelCalled, isTrue);

      await tester.tap(find.text('Accepter'));
      await tester.pump();
      expect(repo.acceptCalled, isTrue);

      await tester.tap(find.text('Refuser'));
      await tester.pump();
      expect(repo.refuseCalled, isTrue);
    });
  });
}
