import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xoropower/main.dart';

void main() {
  testWidgets('Application mounts with its configured router', (tester) async {
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) =>
              const Scaffold(body: Text('XoroPower test route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [goRouterProvider.overrideWithValue(router)],
        child: const XoroPowerApp(),
      ),
    );

    expect(find.text('XoroPower test route'), findsOneWidget);
  });
}
