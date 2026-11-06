import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/models/common/floating_nav_bar_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide NavigationIndicator;

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    FloatingNavBarStyle? style,
    ValueChanged<int>? onDestinationSelected,
    int selectedIndex = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FloatingNavigationBar(
              style: style ?? FloatingNavBarStyle.iconAndLabel,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: const [
                FloatingNavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首页',
                ),
                FloatingNavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed),
                  label: '动态',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group('FloatingNavigationBar display style', () {
    testWidgets('iconAndLabel shows icons and labels without tooltips', (
      tester,
    ) async {
      int? tapped;
      await pumpBar(
        tester,
        selectedIndex: 1,
        onDestinationSelected: (index) => tapped = index,
      );

      final bar = tester.widget<FloatingNavigationBar>(
        find.byType(FloatingNavigationBar),
      );
      expect(bar.style, FloatingNavBarStyle.iconAndLabel);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('动态'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);

      await tester.tap(find.byIcon(Icons.home_outlined));
      expect(tapped, 0);
    });

    testWidgets('iconOnly hides labels, keeps tooltips and taps', (
      tester,
    ) async {
      int? tapped;
      await pumpBar(
        tester,
        style: FloatingNavBarStyle.iconOnly,
        selectedIndex: 1,
        onDestinationSelected: (index) => tapped = index,
      );

      expect(find.byType(Tooltip), findsNWidgets(2));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('首页'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0.0);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_outlined));
      expect(tapped, 0);
    });

    testWidgets('labelOnly hides icons, shows every label centered', (
      tester,
    ) async {
      int? tapped;
      await pumpBar(
        tester,
        style: FloatingNavBarStyle.labelOnly,
        onDestinationSelected: (index) => tapped = index,
        selectedIndex: 1,
      );

      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.byIcon(Icons.dynamic_feed_outlined), findsNothing);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('动态'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);

      await tester.tap(find.text('首页'));
      expect(tapped, 0);
    });

    testWidgets('iconOnly uses a compact bar and indicator', (tester) async {
      await pumpBar(tester, style: FloatingNavBarStyle.iconOnly);

      // 两个 destination，每个 56 宽，加左右各 4 的容器内边距；高度 48 + bottomPadding 8。
      final barSize = tester.getSize(find.byType(FloatingNavigationBar));
      expect(barSize, const Size(120, 56));

      // 指示器 = 56 x (48 - 2 * 4)。
      final indicatorSize = tester.getSize(
        find.byType(NavigationIndicator).first,
      );
      expect(indicatorSize, const Size(56, 40));
    });
  });
}
