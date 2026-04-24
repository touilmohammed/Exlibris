import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/presentation/sign_in_page.dart';
import 'package:flutter_application_1/features/auth/data/auth_repository.dart';

// Un faux dépôt pour forcer le comportement de connexion
class FakeAuthRepository implements AuthRepository {
  bool signInCalled = false;
  String? usedEmail;
  String? usedPassword;
  bool shouldThrowError = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalled = true;
    usedEmail = email;
    usedPassword = password;
    if (shouldThrowError) {
      throw Exception('401 Unauthorized');
    }
  }

  @override
  Future<void> signUp({required String email, required String username, required String password}) async {}

  @override
  Future<void> confirmEmail({required String token}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  group('SignInPage Tests', () {
    late FakeAuthRepository fakeAuthRepository;
    late GoRouter testRouter;
    bool navigatedToHome = false;

    setUp(() {
      fakeAuthRepository = FakeAuthRepository();
      navigatedToHome = false;

      // Un routeur spécifique au test pour intercepter la navigation sans utiliser le global
      testRouter = GoRouter(
        initialLocation: '/signin',
        routes: [
          GoRoute(
            path: '/signin',
            builder: (context, state) => const SignInPage(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) {
              navigatedToHome = true;
              return const Scaffold(body: Text('Home Page'));
            },
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) => const Scaffold(body: Text('Sign Up Page')),
          ),
        ],
      );
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepository),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
    }

    testWidgets('renders login form properly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Retrouve ta bibliotheque et tes echanges.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email et mot de passe
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Clique sur le bouton sans remplir
      await tester.tap(find.text('Se connecter'));
      await tester.pump(); // Déclenche le rebuild avec les erreurs

      expect(find.text('Veuillez entrer votre email'), findsOneWidget);
      expect(find.text('Veuillez entrer votre mot de passe'), findsOneWidget);

      // On s'assure que le repository n'a pas été appelé
      expect(fakeAuthRepository.signInCalled, isFalse); 
    });

    testWidgets('calls signIn and navigates on success', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Saisit les identifiants
      final emailField = find.byType(TextFormField).at(0);
      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle(); // On attend la fin du _submit asynchrone

      expect(fakeAuthRepository.signInCalled, isTrue);
      expect(fakeAuthRepository.usedEmail, 'test@example.com');
      
      // Vérifie qu'on a bien navigué vers la page Home
      expect(navigatedToHome, isTrue);
    });
    
    testWidgets('shows error toast on failure', (WidgetTester tester) async {
      // Configuration pour simuler une erreur du serveur
      fakeAuthRepository.shouldThrowError = true;
      
      await tester.pumpWidget(createTestWidget());

      final emailField = find.byType(TextFormField).at(0);
      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(emailField, 'user@test.com');
      await tester.enterText(passwordField, 'wrongpass');
      
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle(); // Attend la fin du traitement et l'affichage

      expect(fakeAuthRepository.signInCalled, isTrue);
      expect(navigatedToHome, isFalse);
      
      // Vérifie l'apparition du SnackBar géré par AppToast
      expect(find.text('Email ou mot de passe incorrect'), findsOneWidget);
    });
  });
}
