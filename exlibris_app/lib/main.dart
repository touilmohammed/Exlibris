import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/env.dart';
import 'core/stripe_bootstrap.dart';

final String stripePublishableKey = Env.stripePublishableKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env.local");
  await initializeStripe(stripePublishableKey);
  runApp(const ProviderScope(child: ExLibrisApp()));
}

class ExLibrisApp extends StatelessWidget {
  const ExLibrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ExLibris',
      debugShowCheckedModeBanner: false, // 🔹 Enlève le ruban DEBUG
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
      ),
      routerConfig: AppRouter.router,
    );
  }
}
