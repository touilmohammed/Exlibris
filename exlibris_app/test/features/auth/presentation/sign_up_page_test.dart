import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/presentation/sign_up_page.dart';
import 'package:flutter_application_1/features/auth/data/auth_repository.dart';
import '../../../helpers/test_helper.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('SignUpPage Tests', () {
    late FakeAuthRepository fakeAuthRepository;
    bool navigatedToSignIn = false;

    setUp(() {
      fakeAuthRepository = FakeAuthRepository();
      navigatedToSignIn = false;
    });

    Widget createTestEnv() {
      return createTestWidget(
        child: const SignUpPage(),
        initialLocation: '/signup',
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepository),
        ],
        overrideRoutes: [
          GoRoute(
            path: '/signup',
            builder: (context, state) => const SignUpPage(),
          ),
          GoRoute(
            path: '/signin',
            builder: (context, state) {
              navigatedToSignIn = true;
              return const Scaffold(body: Text('Sign In Page'));
            },
          ),
        ],
      );
    }

    testWidgets('renders sign up form properly', (tester) async {
      await tester.pumpWidget(createTestEnv());
      
      expect(find.text('Créer un compte'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // Username, email, pwd, confirm pwd
      expect(find.text('Créer mon compte'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(createTestEnv());
      
      await tester.tap(find.text('Créer mon compte'));
      await tester.pump();

      expect(find.text('Veuillez entrer votre nom'), findsOneWidget);
      expect(find.text('Veuillez entrer votre email'), findsOneWidget);
      expect(find.text('Veuillez entrer un mot de passe'), findsOneWidget);
      expect(find.text('Veuillez confirmer votre mot de passe'), findsOneWidget);

      expect(fakeAuthRepository.signUpCalled, isFalse);
    });

    testWidgets('shows validation error when passwords do not match', (tester) async {
      await tester.pumpWidget(createTestEnv());

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'johndoe');
      await tester.enterText(inputs.at(1), 'john@test.com');
      await tester.enterText(inputs.at(2), 'password123');
      await tester.enterText(inputs.at(3), 'notmatching');

      await tester.tap(find.text('Créer mon compte'));
      await tester.pump();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
      expect(fakeAuthRepository.signUpCalled, isFalse);
    });

    testWidgets('calls signUp and navigates on success after email confirmation', (tester) async {
      await tester.pumpWidget(createTestEnv());

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'johndoe');
      await tester.enterText(inputs.at(1), 'john@test.com');
      await tester.enterText(inputs.at(2), 'password123');
      await tester.enterText(inputs.at(3), 'password123');
      
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle(); // Wait for signup to call dialog

      expect(fakeAuthRepository.signUpCalled, isTrue);
      
      // Verify dialog is shown
      expect(find.text('Vérifie tes mails'), findsOneWidget);
      
      // Enter confirmation code
      await tester.enterText(find.byType(TextFormField).last, '1234');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(navigatedToSignIn, isTrue);
      expect(find.text('Inscription réussie et email confirmé !'), findsWidgets);
    });
    
    testWidgets('shows error toast on conflict (used email)', (tester) async {
      fakeAuthRepository.shouldThrowError = true;
      
      await tester.pumpWidget(createTestEnv());

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'johndoe');
      await tester.enterText(inputs.at(1), 'used@test.com');
      await tester.enterText(inputs.at(2), 'password123');
      await tester.enterText(inputs.at(3), 'password123');
      
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();

      expect(fakeAuthRepository.signUpCalled, isTrue);
      expect(navigatedToSignIn, isFalse);
      
      expect(find.text('Cet email est déjà utilisé'), findsOneWidget);
    });
  });
}
