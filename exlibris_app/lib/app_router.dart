import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/sign_in_page.dart';
import 'features/auth/presentation/sign_up_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/books/presentation/book_details_page.dart';
import 'features/exchanges/presentation/pick_my_book_page.dart';
import 'features/exchanges/presentation/pick_their_book_page.dart';
import 'features/exchanges/presentation/exchanges_page.dart';
import 'models/book.dart';
import 'models/friend.dart';
import 'core/token_storage.dart';

class AppRouter {
  static final _router = GoRouter(
    initialLocation: '/decide',
    routes: [
      GoRoute(
        path: '/decide',
        builder: (context, state) => const _DecidePage(),
      ),
      GoRoute(path: '/signin', builder: (context, state) => const SignInPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: '/book',
        builder: (context, state) {
          final book = state.extra as Book;
          return BookDetailsPage(book: book);
        },
      ),
      GoRoute(
        path: '/exchange/pick-mine',
        builder: (context, state) {
          final friend = state.extra as Friend;
          return PickMyBookPage(friend: friend);
        },
      ),
      GoRoute(
        path: '/exchange/pick-theirs',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return PickTheirBookPage(
            friend: data['friend'] as Friend,
            myBook: data['myBook'] as Book,
          );
        },
      ),
      GoRoute(
        path: '/my-exchanges',
        builder: (context, state) => const ExchangesPage(),
      ),
    ],
  );

  static GoRouter get router => _router;

  // Helpers pratiques
  static void goSignIn(BuildContext context) => context.go('/signin');
  static void goSignUp(BuildContext context) => context.go('/signup');
  static void goHome(BuildContext context) => context.go('/home');
}

/// Page qui décide : connecté -> /home, sinon -> /signin
class _DecidePage extends StatefulWidget {
  const _DecidePage();

  @override
  State<_DecidePage> createState() => _DecidePageState();
}

class _DecidePageState extends State<_DecidePage> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Effacer l'ancien token pour forcer une nouvelle connexion
    // TODO: Supprimer cette ligne après le premier test réussi
    await TokenStorage.clear();
    
    final token = await TokenStorage.read();
    if (!mounted) return;
    if (token == null) {
      AppRouter.goSignIn(context);
    } else {
      AppRouter.goHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
