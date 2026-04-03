import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';

RenderSliver _findExpansibleBodyRenderObject(WidgetTester tester) {
  for (final element in tester.allElements) {
    final renderObject = element.renderObject;
    if (renderObject is RenderSliver &&
        renderObject.runtimeType.toString() == '_RenderSliverExpansibleBody') {
      return renderObject;
    }
  }
  throw StateError(
    'Could not find _RenderSliverExpansibleBody in render tree.',
  );
}

Widget _buildLayoutHarness({
  required SliverExpansibleController controller,
  required ScrollController scrollController,
  required AnimationStyle animationStyle,
  required Widget bodySliver,
  double outerHeaderExtent = 100,
  double expansibleHeaderExtent = 50,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: outerHeaderExtent)),
          SliverExpansible(
            controller: controller,
            animationStyle: animationStyle,
            maintainState: true,
            headerBuilder: (context, animation) {
              return SliverToBoxAdapter(
                child: SizedBox(height: expansibleHeaderExtent),
              );
            },
            bodyBuilder: (context, animation) => bodySliver,
          ),
        ],
      ),
    ),
  );
}

double _expectedMaxScrollExtent({
  required double viewportExtent,
  required double outerHeaderExtent,
  required double expansibleHeaderExtent,
  required double bodyExtent,
}) {
  final contentExtent = outerHeaderExtent + expansibleHeaderExtent + bodyExtent;
  return math.max(0, contentExtent - viewportExtent);
}

void main() {
  testWidgets(
    'scroll extent is correct when collapsed and expanded (box body)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = SliverExpansibleController();
      final scrollController = ScrollController();

      const outerHeaderExtent = 100.0;
      const headerExtent = 50.0;
      const bodyExtent = 300.0;

      await tester.pumpWidget(
        _buildLayoutHarness(
          controller: controller,
          scrollController: scrollController,
          animationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 200),
            curve: Curves.linear,
          ),
          outerHeaderExtent: outerHeaderExtent,
          expansibleHeaderExtent: headerExtent,
          bodySliver: const SliverToBoxAdapter(
            child: SizedBox(height: bodyExtent),
          ),
        ),
      );

      // Collapsed: body extent is 0.
      final collapsed = scrollController.position.maxScrollExtent;
      expect(
        collapsed,
        _expectedMaxScrollExtent(
          viewportExtent: 100,
          outerHeaderExtent: outerHeaderExtent,
          expansibleHeaderExtent: headerExtent,
          bodyExtent: 0,
        ),
      );

      controller.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // 50% through

      final mid = scrollController.position.maxScrollExtent;
      expect(
        mid,
        closeTo(
          _expectedMaxScrollExtent(
            viewportExtent: 100,
            outerHeaderExtent: outerHeaderExtent,
            expansibleHeaderExtent: headerExtent,
            bodyExtent: bodyExtent * 0.5,
          ),
          0.01,
        ),
      );

      await tester.pumpAndSettle();

      // Expanded: body contributes full extent.
      final expanded = scrollController.position.maxScrollExtent;
      expect(
        expanded,
        _expectedMaxScrollExtent(
          viewportExtent: 100,
          outerHeaderExtent: outerHeaderExtent,
          expansibleHeaderExtent: headerExtent,
          bodyExtent: bodyExtent,
        ),
      );
    },
  );

  testWidgets('scroll extent increases monotonically during linear animation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      _buildLayoutHarness(
        controller: controller,
        scrollController: scrollController,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        bodySliver: const SliverToBoxAdapter(child: SizedBox(height: 300)),
      ),
    );

    controller.expand();
    await tester.pump();

    var last = scrollController.position.maxScrollExtent;
    for (final dt in const [
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
      Duration(milliseconds: 25),
    ]) {
      await tester.pump(dt);
      final current = scrollController.position.maxScrollExtent;
      expect(current, greaterThanOrEqualTo(last));
      last = current;
    }

    await tester.pumpAndSettle();
  });

  testWidgets(
    'hasVisualOverflow is false when collapsed and true when revealed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = SliverExpansibleController();
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildLayoutHarness(
          controller: controller,
          scrollController: scrollController,
          animationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 200),
            curve: Curves.linear,
          ),
          bodySliver: const SliverToBoxAdapter(child: SizedBox(height: 300)),
        ),
      );

      final collapsedBodyRender = _findExpansibleBodyRenderObject(tester);
      expect(collapsedBodyRender.geometry!.hasVisualOverflow, isFalse);

      controller.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final expandedBodyRender = _findExpansibleBodyRenderObject(tester);
      expect(expandedBodyRender.geometry!.hasVisualOverflow, isTrue);
    },
  );

  testWidgets('supports SliverList/SliverGrid/SliverFixedExtentList bodies', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<double> pumpBody(Widget body) async {
      final controller = SliverExpansibleController();
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildLayoutHarness(
          controller: controller,
          scrollController: scrollController,
          animationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 100),
            curve: Curves.linear,
          ),
          bodySliver: body,
        ),
      );

      controller.expand();
      await tester.pumpAndSettle();
      return scrollController.position.maxScrollExtent;
    }

    final listExtent = await pumpBody(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SizedBox(height: 20),
          childCount: 20,
        ),
      ),
    );
    expect(listExtent, greaterThan(0));

    final fixedExtent = await pumpBody(
      SliverFixedExtentList(
        itemExtent: 20,
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SizedBox.shrink(),
          childCount: 20,
        ),
      ),
    );
    expect(fixedExtent, greaterThan(0));

    final gridExtent = await pumpBody(
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 20,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SizedBox.shrink(),
          childCount: 20,
        ),
      ),
    );
    expect(gridExtent, greaterThan(0));
  });

  testWidgets('collapsed body does not receive hits; expanded does', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    final scrollController = ScrollController();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverExpansible(
                controller: controller,
                animationStyle: const AnimationStyle(
                  duration: Duration(milliseconds: 100),
                  curve: Curves.linear,
                ),
                maintainState: true,
                headerBuilder: (context, animation) {
                  return const SliverToBoxAdapter(child: SizedBox(height: 50));
                },
                bodyBuilder: (context, animation) {
                  return SliverToBoxAdapter(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox(height: 100),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    // Tap where the body would appear.
    await tester.tapAt(const Offset(10, 60));
    await tester.pump();
    expect(taps, 0);

    controller.expand();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 60));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('controller can change while animation is running', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controllerA = SliverExpansibleController();
    final controllerB = SliverExpansibleController(); // collapsed
    final scrollController = ScrollController();

    Widget buildWith(SliverExpansibleController controller) {
      return _buildLayoutHarness(
        controller: controller,
        scrollController: scrollController,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        bodySliver: const SliverToBoxAdapter(child: SizedBox(height: 300)),
      );
    }

    await tester.pumpWidget(buildWith(controllerA));

    controllerA.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // mid animation

    // Swap controller while animating; should settle to controllerB (collapsed).
    await tester.pumpWidget(buildWith(controllerB));
    await tester.pumpAndSettle();

    expect(controllerB.isExpanded, isFalse);
  });

  testWidgets('nested SliverExpansible works', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outer = SliverExpansibleController()..expand();
    final inner = SliverExpansibleController()..collapse();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverExpansible(
                controller: outer,
                animationStyle: const AnimationStyle(
                  duration: Duration(milliseconds: 50),
                  curve: Curves.linear,
                ),
                headerBuilder: (context, animation) {
                  return const SliverToBoxAdapter(child: Text('Outer header'));
                },
                bodyBuilder: (context, animation) {
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverExpansible(
                        controller: inner,
                        animationStyle: const AnimationStyle(
                          duration: Duration(milliseconds: 50),
                          curve: Curves.linear,
                        ),
                        headerBuilder: (context, animation) {
                          return const SliverToBoxAdapter(
                            child: Text('Inner header'),
                          );
                        },
                        bodyBuilder: (context, animation) {
                          return const SliverToBoxAdapter(
                            child: Text('Inner body'),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Inner body'), findsNothing);

    inner.expand();
    await tester.pumpAndSettle();
    expect(find.text('Inner body'), findsOneWidget);
  });

  testWidgets('spam expand/collapse does not throw', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      _buildLayoutHarness(
        controller: controller,
        scrollController: scrollController,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        bodySliver: const SliverToBoxAdapter(child: SizedBox(height: 300)),
      ),
    );

    for (var i = 0; i < 10; i++) {
      controller.expand();
      await tester.pump(const Duration(milliseconds: 10));
      controller.collapse();
      await tester.pump(const Duration(milliseconds: 10));
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
