import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/library/presentation/library_page.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/features/wishlist/data/wishlist_repository.dart';
import 'package:flutter_application_1/features/profile/data/profile_repository.dart';
import 'package:flutter_application_1/models/book.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('LibraryPage Tests', () {
    late FakeBooksRepository booksRepo;
    late FakeWishlistRepository wishlistRepo;
    late FakeProfileRepository profileRepo;

    setUp(() {
      booksRepo = FakeBooksRepository();
      wishlistRepo = FakeWishlistRepository();
      profileRepo = FakeProfileRepository();
    });

    Widget createTestEnv(
      WidgetTester tester, {
      List<Override> extraOverrides = const [],
    }) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return createTestWidget(
        child: const LibraryPage(),
        initialLocation: '/library',
        overrides: [
          booksRepositoryProvider.overrideWithValue(booksRepo),
          wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          ...extraOverrides,
        ],
      );
    }

    testWidgets('shows empty state for collection', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      expect(find.text('Bibliotheque'), findsWidgets);
      expect(find.text('Ta collection est encore vide.'), findsWidgets);
    });

    testWidgets('switches to wishlist tab and shows empty state', (
      tester,
    ) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Tap on Wishlist tab (the one in the tab bar, not overview)
      await tester.tap(find.text('Wishlist').last);
      await tester.pumpAndSettle();

      expect(find.text('Ta wishlist est vide.'), findsWidgets);
    });

    testWidgets('shows books grid when collection is not empty', (
      tester,
    ) async {
      final testBook = Book(
        isbn: '123',
        titre: 'Test Book Grid',
        auteur: 'Test Author',
        categorie: 'Test',
        imagePetite: null,
      );

      booksRepo.collection = [testBook];

      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      expect(find.text('Test Book Grid'), findsOneWidget);
    });

    testWidgets('shows books grid when wishlist is not empty', (tester) async {
      final testBook = Book(
        isbn: '456',
        titre: 'Wishlist Book',
        auteur: 'Wish Author',
        categorie: 'Test',
        imagePetite: null,
      );

      wishlistRepo.wishlist = [testBook];

      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Switch to wishlist using the tab bar button
      await tester.tap(find.text('Wishlist').last);
      await tester.pumpAndSettle();

      expect(find.text('Wishlist Book'), findsOneWidget);
    });
  });
}
