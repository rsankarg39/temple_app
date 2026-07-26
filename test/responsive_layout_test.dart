import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_book_app/theme/app_theme.dart';
import 'package:temple_book_app/theme/responsive_layout.dart';

Widget _host({
  required Size size,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Responsive breakpoints', () {
    testWidgets('iPhone SE 375px uses short tab labels', (tester) async {
      await tester.pumpWidget(
        _host(
          size: const Size(375, 667),
          child: Builder(
            builder: (context) {
              expect(Responsive.isCompact(context), isTrue);
              final tab = responsiveDashboardTab(
                context,
                title: 'Family Heads',
                shortTitle: 'Family',
              );
              return tab.child as Text;
            },
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'Family');
    });

    testWidgets('Galaxy S8+ 360px tab bar is scrollable', (tester) async {
      await tester.pumpWidget(
        _host(
          size: const Size(360, 740),
          child: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    bottom: responsiveDashboardTabBar(
                      context,
                      [
                        responsiveDashboardTab(
                          context,
                          title: 'User Roles',
                          shortTitle: 'Roles',
                        ),
                        responsiveDashboardTab(
                          context,
                          title: 'Committee',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isTrue);
      expect(tabBar.tabAlignment, TabAlignment.start);
    });

    testWidgets('iPad Pro 1024px uses expanded layout flag', (tester) async {
      await tester.pumpWidget(
        _host(
          size: const Size(1024, 1366),
          child: Builder(
            builder: (context) {
              expect(Responsive.isExpanded(context), isTrue);
              expect(
                Responsive.sp(context, compact: 12, medium: 13, expanded: 14),
                14,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('TempleDashboardTitle fits on narrow width', (tester) async {
      await tester.pumpWidget(
        _host(
          size: const Size(360, 740),
          child: const TempleDashboardTitle(
            templeName: 'Default Temple',
            roleLabel: 'ADMIN',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Default Temple'), findsOneWidget);
    });
  });
}
