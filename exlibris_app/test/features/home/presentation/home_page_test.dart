import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/home/presentation/home_page.dart';
import 'package:flutter_application_1/features/auth/data/auth_repository.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/features/exchanges/data/exchanges_repository.dart';
import 'package:flutter_application_1/features/friends/data/friends_repository.dart';
import 'package:flutter_application_1/features/profile/data/profile_repository.dart';
import 'package:flutter_application_1/features/ratings/data/ratings_repository.dart';
import 'package:flutter_application_1/features/wishlist/data/wishlist_repository.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('HomePage Tests', () {
    late FakeAuthRepository authRepo;
    late FakeBooksRepository booksRepo;
    late FakeWishlistRepository wishlistRepo;
    late FakeFriendsRepository friendsRepo;
    late FakeExchangesRepository exchangesRepo;
    late FakeProfileRepository profileRepo;
    late FakeRatingsRepository ratingsRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
      booksRepo = FakeBooksRepository();
      wishlistRepo = FakeWishlistRepository();
      friendsRepo = FakeFriendsRepository();
      exchangesRepo = FakeExchangesRepository();
      profileRepo = FakeProfileRepository();
      ratingsRepo = FakeRatingsRepository();
    });

    Widget createTestEnv(WidgetTester tester) {
      // Increase surface size to avoid overflow in tests with 96px bottom padding
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return createTestWidget(
        child: const HomePage(),
        initialLocation: '/home',
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          booksRepositoryProvider.overrideWithValue(booksRepo),
          wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
          friendsRepositoryProvider.overrideWithValue(friendsRepo),
          exchangesRepositoryProvider.overrideWithValue(exchangesRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          ratingsRepositoryProvider.overrideWithValue(ratingsRepo),
        ],
      );
    }

    testWidgets('renders HomePage with bottom navigation', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Check for navigation labels
      expect(find.text('Accueil'), findsWidgets);
      expect(find.text('Bibliotheque'), findsWidgets);
      expect(find.text('Echanges'), findsWidgets);
      expect(find.text('Reseau'), findsWidgets);
      expect(find.text('Explorer'), findsWidgets);
    });

    testWidgets('bottom navigation switches correctly to Bibliotheque', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Tap on Bibliotheque tab
      // There might be multiple "Bibliotheque" texts (Tab and Header)
      final libTab = find.text('Bibliotheque').last;
      await tester.tap(libTab);
      // Pump multiple times to ensure AnimatedSwitcher and FutureProvider finish
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify header and empty state
      expect(find.text('Bibliotheque'), findsWidgets);
      expect(find.text('Ta collection est encore vide.'), findsWidgets);
    });

    testWidgets('bottom navigation switches correctly to Explorer', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      final searchTab = find.text('Explorer').last;
      await tester.tap(searchTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Search field should be visible with updated hint
      expect(find.text('Explorer'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Titre, auteur ou ISBN'), findsOneWidget);
    });
  });
}
