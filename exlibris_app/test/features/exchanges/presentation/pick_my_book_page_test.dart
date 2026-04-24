import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/exchanges/presentation/pick_my_book_page.dart';
import 'package:flutter_application_1/features/books/data/books_providers.dart';
import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/models/friend.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('PickMyBookPage Tests', () {
    late FakeBooksRepository booksRepo;

    setUp(() {
      booksRepo = FakeBooksRepository();
    });

    testWidgets('renders my collection for picking', (tester) async {
      booksRepo.collection = [
        Book(
          isbn: 'BOOK1',
          titre: 'Test Book',
          auteur: 'Test Author',
          categorie: 'Test',
          imagePetite: null,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: PickMyBookPage(friend: Friend(id: 1, nom: 'Jean')),
          overrides: [
            collectionProvider.overrideWith((ref) => booksRepo.getCollection()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Choisis le livre que tu proposes a Jean'),
        findsOneWidget,
      );
      expect(find.text('Test Book'), findsOneWidget);
      expect(find.text('Je propose'), findsOneWidget);
    });
  });
}
