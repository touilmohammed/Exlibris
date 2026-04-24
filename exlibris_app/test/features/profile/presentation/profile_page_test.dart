import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/profile/presentation/profile_page.dart';
import 'package:flutter_application_1/features/profile/data/profile_repository.dart';
import 'package:flutter_application_1/features/auth/data/auth_repository.dart';

import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ProfilePage Tests', () {
    late FakeProfileRepository profileRepo;
    late FakeAuthRepository authRepo;

    setUp(() {
      profileRepo = FakeProfileRepository();
      authRepo = FakeAuthRepository();
    });

    Widget createTestEnv(WidgetTester tester) {
      // Increase surface size to avoid overflow and off-screen buttons
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return createTestWidget(
        child: const ProfilePage(),
        initialLocation: '/profile',
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
    }

    testWidgets('renders profile and allows editing', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      expect(find.text('Mon profil'), findsWidgets);
      expect(find.text('TestUser'), findsWidgets);
      expect(find.text('test@test.com'), findsWidgets);
      
      // Tap edit button to show editable fields
      await tester.tap(find.text('Modifier le profil'));
      await tester.pump();

      expect(find.text('Nom').first, findsOneWidget);
      expect(find.text('Email').first, findsOneWidget);
    });

    testWidgets('toggles editing mode', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Find 'Modifier le profil' button
      final editButton = find.text('Modifier le profil');
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Now it should show 'Annuler' and 'Sauvegarder'
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Sauvegarder'), findsOneWidget);
    });

    testWidgets('calls updateProfile and saves settings', (tester) async {
      await tester.pumpWidget(createTestEnv(tester));
      await tester.pumpAndSettle();

      // Start editing
      await tester.tap(find.text('Modifier le profil'));
      await tester.pump();

      final nameField = find.widgetWithText(TextFormField, 'Nom utilisateur'); 
      await tester.enterText(nameField, 'NewName');
      
      await tester.tap(find.text('Sauvegarder'));
      await tester.pumpAndSettle();

      expect(profileRepo.updateCalled, isTrue);
    });
  });
}
