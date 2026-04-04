import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';

Widget _buildRestorationHarness({
  required SliverExpansibleController controller,
  required Key? key,
  required PageStorageBucket bucket,
  required bool showExpansible,
  bool maintainState = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PageStorage(
        bucket: bucket,
        child: CustomScrollView(
          slivers: [
            if (showExpansible)
              SliverExpansible(
                key: key,
                controller: controller,
                maintainState: maintainState,
                animationStyle: const AnimationStyle(
                  duration: Duration(milliseconds: 50),
                  curve: Curves.linear,
                ),
                sliverHeaderBuilder: (context, animation) {
                  return const SliverToBoxAdapter(child: SizedBox(height: 40));
                },
                sliverBodyBuilder: (context, animation) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(height: 40, child: Text('Body content')),
                  );
                },
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 1)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('restores expanded state with PageStorageKey', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    const key = PageStorageKey('test-key');
    final bucket = PageStorageBucket();

    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controller,
        key: key,
        bucket: bucket,
        showExpansible: true,
      ),
    );

    controller.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    // Remove it from the tree to force disposal (simulates being destroyed,
    // such as when swapping pages in a route).
    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controller,
        key: key,
        bucket: bucket,
        showExpansible: false,
      ),
    );
    await tester.pump();

    // Re-insert with a new controller, keeping the same PageStorageKey. The
    // expanded state should be restored from PageStorage.
    final restoredController = SliverExpansibleController();
    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: restoredController,
        key: key,
        bucket: bucket,
        showExpansible: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsOneWidget);
    expect(restoredController.isExpanded, isTrue);
  });

  testWidgets('does not restore expanded state without PageStorageKey', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = SliverExpansibleController();
    final bucket = PageStorageBucket();

    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controller,
        key: null,
        bucket: bucket,
        showExpansible: true,
      ),
    );

    controller.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    // Without a PageStorageKey, no expansion state is saved. A new controller
    // starts collapsed.
    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controller,
        key: null,
        bucket: bucket,
        showExpansible: false,
      ),
    );
    await tester.pump();

    final controllerB = SliverExpansibleController();
    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controllerB,
        key: null,
        bucket: bucket,
        showExpansible: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsNothing);
    expect(controllerB.isExpanded, isFalse);
  });

  testWidgets('PageStorage overrides controller initial state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const key = PageStorageKey('precedence-key');
    final bucket = PageStorageBucket();

    final controllerA = SliverExpansibleController();
    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controllerA,
        key: key,
        bucket: bucket,
        showExpansible: true,
      ),
    );
    controllerA.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controllerA,
        key: key,
        bucket: bucket,
        showExpansible: false,
      ),
    );
    await tester.pump();

    // New controller is collapsed, but the widget should restore expanded from
    // PageStorage and update the controller accordingly.
    final controllerB = SliverExpansibleController();
    expect(controllerB.isExpanded, isFalse);

    await tester.pumpWidget(
      _buildRestorationHarness(
        controller: controllerB,
        key: key,
        bucket: bucket,
        showExpansible: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsOneWidget);
    expect(controllerB.isExpanded, isTrue);
  });
}
