import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_book_app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('preloadFonts completes', () async {
      await AppTheme.preloadFonts();
    });

    test('text theme defines all Material 3 roles with Noto Sans', () {
      final t = AppTheme.light().textTheme;
      expect(t.displayLarge, isNotNull);
      expect(t.displayMedium, isNotNull);
      expect(t.displaySmall, isNotNull);
      expect(t.headlineLarge, isNotNull);
      expect(t.headlineMedium, isNotNull);
      expect(t.headlineSmall, isNotNull);
      expect(t.titleLarge, isNotNull);
      expect(t.titleMedium, isNotNull);
      expect(t.titleSmall, isNotNull);
      expect(t.bodyLarge, isNotNull);
      expect(t.bodyMedium, isNotNull);
      expect(t.bodySmall, isNotNull);
      expect(t.labelLarge, isNotNull);
      expect(t.labelMedium, isNotNull);
      expect(t.labelSmall, isNotNull);

      expect(t.bodyMedium!.fontFamily, AppTheme.fontFamily);
      expect(t.labelLarge!.fontFamily, AppTheme.fontFamily);
      expect(
        t.bodyMedium!.fontFamilyFallback,
        AppTheme.fontFamilyFallback,
      );
    });

    test('tabBarTheme does not set tabAlignment', () {
      expect(AppTheme.light().tabBarTheme.tabAlignment, isNull);
    });

    testWidgets('TabBar does not throw TabAlignment error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Login'),
                    Tab(text: 'Register'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  Center(child: Text('Login body')),
                  Center(child: Text('Register body')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('login layout: SegmentedButton + scroll — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Login')),
                      ButtonSegment(value: 1, label: Text('Register')),
                    ],
                    selected: const {0},
                    onSelectionChanged: (_) {},
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Email', style: AppTheme.light().textTheme.bodyLarge),
                        const SizedBox(height: 400),
                        Text(
                          'Password',
                          style: AppTheme.light().textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
