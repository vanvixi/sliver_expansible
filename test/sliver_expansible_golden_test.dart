import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';

Widget _buildGoldenHarness({
  required SliverExpansibleController controller,
  required AnimationStyle animationStyle,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: RepaintBoundary(
        key: const Key('golden-boundary'),
        child: CustomScrollView(
          slivers: [
            SliverExpansible(
              controller: controller,
              animationStyle: animationStyle,
              headerBuilder: (context, animation) {
                return const SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Colors.blue,
                    child: SizedBox(
                      height: 48,
                      child: Center(child: Text('Header')),
                    ),
                  ),
                );
              },
              bodyBuilder: (context, animation) {
                return const SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Colors.green,
                    child: SizedBox(
                      height: 120,
                      child: Center(child: Text('Body')),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('collapsed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    await tester.pumpWidget(
      _buildGoldenHarness(
        controller: controller,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      ),
    );

    await expectLater(
      find.byKey(const Key('golden-boundary')),
      matchesGoldenFile('goldens/sliver_expansible_collapsed.png'),
    );
  });

  testWidgets('expanded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController()..expand();
    await tester.pumpWidget(
      _buildGoldenHarness(
        controller: controller,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('golden-boundary')),
      matchesGoldenFile('goldens/sliver_expansible_expanded.png'),
    );
  });

  testWidgets('mid animation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    await tester.pumpWidget(
      _buildGoldenHarness(
        controller: controller,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      ),
    );

    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byKey(const Key('golden-boundary')),
      matchesGoldenFile('goldens/sliver_expansible_mid.png'),
    );
  });
}
