import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/books/presentation/book_details_page.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/features/wishlist/data/wishlist_repository.dart';
import 'package:flutter_application_1/features/ratings/data/ratings_repository.dart';
import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/models/rating.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

class BookDetailsFakeBooksRepo extends FakeBooksRepository {
  bool addCollectionCalled = false;
  
  @override
  Future<List<Book>> getCollection() async => [];
  
  @override
  Future<void> addToCollection(String isbn) async {
    addCollectionCalled = true;
  }
}

class BookDetailsFakeRatingsRepo extends FakeRatingsRepository {
  @override
  Future<List<Rating>> getMyRatings({String? isbn}) async => [
    Rating(isbn: 'BOOK123', note: 8, avis: "Super livre"),
  ];
}

void main() {
  group('BookDetailsPage Tests', () {
    late Book testBook;

    setUp(() {
      testBook = Book(
        isbn: 'BOOK123',
        titre: 'Titre du test',
        auteur: 'Auteur du test',
        categorie: 'Essai',
        resume: 'Un grand resume',
        imagePetite: null,
      );
    });

    testWidgets('renders book details', (tester) async {
      final booksRepo = BookDetailsFakeBooksRepo();
      final wishlistRepo = FakeWishlistRepository();
      final ratingsRepo = BookDetailsFakeRatingsRepo();

      await tester.pumpWidget(
        createTestWidget(
          child: BookDetailsPage(book: testBook),
          overrides: [
            booksRepositoryProvider.overrideWithValue(booksRepo),
            wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
            ratingsRepositoryProvider.overrideWithValue(ratingsRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fiche livre'), findsOneWidget);
      expect(find.text('Titre du test'), findsOneWidget);
      expect(find.text('Auteur du test'), findsOneWidget);
      expect(find.text('Essai'), findsAtLeastNWidgets(1));
      expect(find.text('ISBN BOOK123'), findsOneWidget);

      expect(find.text('Un grand resume'), findsWidgets);
      
      // Checking buttons
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Souhait'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget); // Rating is 8
    });

    testWidgets('adds to collection on tap', (tester) async {
      final booksRepo = BookDetailsFakeBooksRepo();
      
      await tester.pumpWidget(
        createTestWidget(
          child: BookDetailsPage(book: testBook),
          overrides: [
            booksRepositoryProvider.overrideWithValue(booksRepo),
            wishlistRepositoryProvider.overrideWithValue(FakeWishlistRepository()),
            ratingsRepositoryProvider.overrideWithValue(FakeRatingsRepository()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final addToCollectionBtn = find.text('Ajouter');
      await tester.tap(addToCollectionBtn);
      await tester.pumpAndSettle();

      expect(booksRepo.addCollectionCalled, isTrue);
    });
  });
}
