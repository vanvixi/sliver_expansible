import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _DisposeSpy extends StatefulWidget {
  const _DisposeSpy();

  static int disposeCount = 0;

  @override
  State<_DisposeSpy> createState() => _DisposeSpyState();
}

class _DisposeSpyState extends State<_DisposeSpy> {
  @override
  void dispose() {
    _DisposeSpy.disposeCount++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 1);
}

Widget _buildScaffold({
  required SliverExpansibleController controller,
  SliverExpansibleComponentBuilder? headerBuilder,
  SliverExpansibleComponentBuilder? bodyBuilder,
  SliverExpansibleBuilder? expansibleBuilder,
  AnimationStyle? animationStyle,
  SliverExpansibleBodyRevealMode bodyRevealMode =
      SliverExpansibleBodyRevealMode.sliverClipReveal,
  bool maintainState = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          if (expansibleBuilder == null)
            SliverExpansible(
              controller: controller,
              animationStyle: animationStyle,
              maintainState: maintainState,
              bodyRevealMode: bodyRevealMode,
              sliverHeaderBuilder: headerBuilder ??
                  (context, animation) =>
                      const SliverToBoxAdapter(child: Text('Header')),
              sliverBodyBuilder: bodyBuilder ??
                  (context, animation) =>
                      const SliverToBoxAdapter(child: Text('Body')),
            )
          else
            SliverExpansible(
              controller: controller,
              animationStyle: animationStyle,
              maintainState: maintainState,
              bodyRevealMode: bodyRevealMode,
              sliverExpansibleBuilder: expansibleBuilder,
              sliverHeaderBuilder: headerBuilder ??
                  (context, animation) =>
                      const SliverToBoxAdapter(child: Text('Header')),
              sliverBodyBuilder: bodyBuilder ??
                  (context, animation) =>
                      const SliverToBoxAdapter(child: Text('Body')),
            ),
        ],
      ),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // Lazy build
  // ---------------------------------------------------------------------------

  testWidgets('collapsed is lazy — builder items not built', (tester) async {
    final controller = SliverExpansibleController();
    var buildCount = 0;

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        headerBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: Text('Header'));
        },
        bodyBuilder: (context, animation) {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              buildCount++;
              return Text('Item $index');
            }, childCount: 1000),
          );
        },
      ),
    );

    expect(buildCount, lessThan(10));
  });

  testWidgets('expand builds items progressively', (tester) async {
    final controller = SliverExpansibleController();
    var buildCount = 0;

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        headerBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: Text('Header'));
        },
        bodyBuilder: (context, animation) {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              buildCount++;
              return const SizedBox(height: 48);
            }, childCount: 1000),
          );
        },
      ),
    );

    final initialBuildCount = buildCount;
    expect(initialBuildCount, lessThan(10));

    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final midBuildCount = buildCount;

    expect(midBuildCount, greaterThan(initialBuildCount));
    expect(midBuildCount, lessThan(200));

    await tester.pumpAndSettle();

    expect(buildCount, lessThan(400));
  });

  // ---------------------------------------------------------------------------
  // maintainState
  // ---------------------------------------------------------------------------

  testWidgets('maintainState=false removes body subtree after collapse', (
    tester,
  ) async {
    _DisposeSpy.disposeCount = 0;
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        maintainState: false,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 100),
        ),
        bodyBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: _DisposeSpy());
        },
      ),
    );

    expect(_DisposeSpy.disposeCount, 0);

    controller.collapse();
    await tester.pumpAndSettle();

    expect(_DisposeSpy.disposeCount, 1);
  });

  testWidgets('maintainState=true keeps body subtree after collapse', (
    tester,
  ) async {
    _DisposeSpy.disposeCount = 0;
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        maintainState: true,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 100),
        ),
        bodyBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: _DisposeSpy());
        },
      ),
    );

    controller.collapse();
    await tester.pumpAndSettle();

    expect(_DisposeSpy.disposeCount, 0);
  });

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  testWidgets('collapsed body excluded from semantics when maintained', (
    tester,
  ) async {
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        animationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 100),
        ),
        bodyBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: Text('Body'));
        },
      ),
    );

    final semanticsHandle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('Body')),
      matchesSemantics(label: 'Body'),
    );

    controller.collapse();
    await tester.pumpAndSettle();
    expect(() => tester.getSemantics(find.text('Body')), throwsA(anything));

    semanticsHandle.dispose();
  });

  testWidgets(
    'builderControlled collapsed body excluded from semantics when maintained',
    (tester) async {
      final controller = SliverExpansibleController();

      await tester.pumpWidget(
        _buildScaffold(
          controller: controller,
          bodyRevealMode: SliverExpansibleBodyRevealMode.builderControlled,
          maintainState: true,
          animationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 100),
          ),
          bodyBuilder: (context, animation) {
            return const SliverToBoxAdapter(child: Text('Body'));
          },
        ),
      );

      // Subtree exists (maintained), but it's offstage in the collapsed state.
      expect(find.text('Body', skipOffstage: false), findsOneWidget);

      final semanticsHandle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Body'), findsNothing);

      controller.expand();
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Body'), findsOneWidget);

      semanticsHandle.dispose();
    },
  );

  // ---------------------------------------------------------------------------
  // AnimationStyle
  // ---------------------------------------------------------------------------

  testWidgets('AnimationStyle.noAnimation expands instantly', (tester) async {
    final controller = SliverExpansibleController();

    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        maintainState: false,
        animationStyle: AnimationStyle.noAnimation,
        bodyBuilder: (context, animation) {
          return const SliverToBoxAdapter(child: Text('Body'));
        },
      ),
    );

    expect(find.text('Body'), findsNothing);

    controller.expand();
    await tester.pump(); // single pump — no animation frames needed

    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('custom duration delays full reveal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 50));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverExpansible(
                controller: controller,
                animationStyle: const AnimationStyle(
                  duration: Duration(seconds: 1),
                  curve: Curves.linear,
                ),
                sliverHeaderBuilder: (context, animation) {
                  return const SliverToBoxAdapter(child: Text('Header'));
                },
                sliverBodyBuilder: (context, animation) {
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 1000),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // 10% through

    // At 10% of a linear animation, the scroll extent is significantly smaller
    // than after the animation completes.
    final midExtent = scrollController.position.maxScrollExtent;
    expect(midExtent, greaterThan(0));

    await tester.pumpAndSettle();
    final endExtent = scrollController.position.maxScrollExtent;
    expect(endExtent, greaterThan(midExtent));
    expect(endExtent, greaterThan(800));
  });

  // ---------------------------------------------------------------------------
  // Controller swap
  // ---------------------------------------------------------------------------

  testWidgets('swapping controller transfers expansion state', (tester) async {
    final controllerA = SliverExpansibleController()..expand();
    final controllerB = SliverExpansibleController(); // collapsed

    Widget buildWith(SliverExpansibleController c) => _buildScaffold(
          controller: c,
          maintainState: false,
          animationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 50),
          ),
          bodyBuilder: (context, animation) {
            return const SliverToBoxAdapter(child: Text('Body'));
          },
        );

    await tester.pumpWidget(buildWith(controllerA));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsOneWidget);

    // Swap to controllerB (collapsed)
    await tester.pumpWidget(buildWith(controllerB));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsNothing);

    // Old controller no longer drives anything
    controllerA.collapse();
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Controller.of / maybeOf
  // ---------------------------------------------------------------------------

  testWidgets(
    'SliverExpansibleController.of() finds controller from descendant',
    (tester) async {
      final expected = SliverExpansibleController()..expand();
      SliverExpansibleController? found;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverExpansible(
                  controller: expected,
                  sliverHeaderBuilder: (context, animation) {
                    return const SliverToBoxAdapter(child: Text('Header'));
                  },
                  sliverBodyBuilder: (context, animation) {
                    return SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          found = SliverExpansibleController.of(context);
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(found, same(expected));
    },
  );

  testWidgets(
    'SliverExpansibleController.maybeOf() returns null outside tree',
    (tester) async {
      SliverExpansibleController? result = SliverExpansibleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = SliverExpansibleController.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result, isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // expansibleBuilder
  // ---------------------------------------------------------------------------

  testWidgets('expansibleBuilder overrides default header+body layout', (
    tester,
  ) async {
    const customKey = Key('custom-wrapper');
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverExpansible(
                controller: controller,
                sliverHeaderBuilder: (context, animation) =>
                    const SliverToBoxAdapter(child: Text('Header')),
                sliverBodyBuilder: (context, animation) =>
                    const SliverToBoxAdapter(child: Text('Body')),
                sliverExpansibleBuilder: (context, header, body, animation) {
                  return SliverMainAxisGroup(
                    key: customKey,
                    slivers: [header, body],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(customKey), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });
}
