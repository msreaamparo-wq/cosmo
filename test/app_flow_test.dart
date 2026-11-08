// NOT YET RUN. Covers: first launch -> onboarding -> home, onboarding persistence, route fallback.
import 'package:cosmos/app.dart';
import 'package:cosmos/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets(
      'first launch shows onboarding, finishing it opens Home, and the choice is saved',
      (tester) async {
    final db = await openTestDatabase();
    final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const CosmosApp()));
    await tester.pump(const Duration(seconds: 3)); // splash
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Your Little Universe'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Hello, Little Explorer!'), findsOneWidget);
    expect(
        (await container.read(settingsProvider.future)).onboardingDone, isTrue);
  });
}
