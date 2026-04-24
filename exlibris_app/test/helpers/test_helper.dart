import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Helper to create a testable widget wrapped in ProviderScope and MaterialApp.router
Widget createTestWidget({
  required Widget child,
  List<Override> overrides = const [],
  String initialLocation = '/',
  List<RouteBase>? overrideRoutes,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: overrideRoutes ?? [
      GoRoute(
        path: initialLocation,
        builder: (context, state) => child,
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}
