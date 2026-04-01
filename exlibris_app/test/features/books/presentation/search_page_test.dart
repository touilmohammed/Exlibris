import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/books/presentation/search_page.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/features/wishlist/data/wishlist_repository.dart';
import 'package:flutter_application_1/features/ratings/data/ratings_repository.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('SearchPage Tests', () {
    late FakeBooksRepository booksRepo;
    late FakeWishlistRepository wishlistRepo;
    late FakeRatingsRepository ratingsRepo;

    setUp(() {
      booksRepo = FakeBooksRepository();
      wishlistRepo = FakeWishlistRepository();
      ratingsRepo = FakeRatingsRepository();
    });

    Widget createTestEnv() {
      return createTestWidget(
        child: const Scaffold(body: SearchPage()),
        overrides: [
          booksRepositoryProvider.overrideWithValue(booksRepo),
          wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
          ratingsRepositoryProvider.overrideWithValue(ratingsRepo),
        ],
      );
    }

    testWidgets('renders search field and initial recommendations', (
      tester,
    ) async {
      await tester.pumpWidget(createTestEnv());
      await tester.pumpAndSettle();

      expect(find.text('Explorer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('performs search and displays results', (tester) async {
      await tester.pumpWidget(createTestEnv());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Harry Potter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Harry Potter'), findsWidgets);
    });
  });
}
