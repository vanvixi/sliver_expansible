import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';
import 'package:sliver_expansion/src/sliver_expansion_tile.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _DisposeSpy extends StatefulWidget {
  const _DisposeSpy({this.height = 1});

  static int disposeCount = 0;

  final double height;

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
  Widget build(BuildContext context) => SizedBox(height: widget.height);
}

Widget _buildHarness({
  required List<Widget> slivers,
  ScrollController? scrollController,
  PageStorageBucket? bucket,
  Key? boundaryKey,
  Color? background,
  bool useMaterial3 = true,
}) {
  Widget child = CustomScrollView(
    controller: scrollController,
    slivers: slivers,
  );

  if (background != null) {
    child = ColoredBox(color: background, child: child);
  }

  if (boundaryKey != null) {
    child = RepaintBoundary(key: boundaryKey, child: child);
  }

  if (bucket != null) {
    child = PageStorage(bucket: bucket, child: child);
  }

  return MaterialApp(
    theme: ThemeData(useMaterial3: useMaterial3),
    home: Scaffold(body: child),
  );
}

Future<(ui.Image image, ByteData bytes)> _captureRawRgba(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = (await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1.0),
  ))!;
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return (image, data!);
}

(int r, int g, int b, int a) _sampleRgba(
  ByteData bytes,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    bytes.getUint8(offset + 0),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
    bytes.getUint8(offset + 3),
  );
}

double _listTileDefaultHeight({
  required bool isDense,
  required bool isThreeLine,
  required bool hasSubtitle,
  required VisualDensity visualDensity,
}) {
  final baseDensity = visualDensity.baseSizeAdjustment.dy;
  return baseDensity +
      switch ((isThreeLine, hasSubtitle)) {
        (true, _) => isDense ? 76.0 : 88.0,
        (false, true) => isDense ? 64.0 : 72.0,
        (false, false) => isDense ? 48.0 : 56.0,
      };
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  // -------------------------------------------------------------------------
  // Lazy build (builder)
  // -------------------------------------------------------------------------

  testWidgets('eager children are built even when collapsed (maintainState=true)', (
    tester,
  ) async {
    final controller = SliverExpansibleController();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            maintainState: true,
            title: const Text('Group'),
            children: const [Text('Body')],
          ),
        ],
      ),
    );

    final tileWidget = tester.widget<SliverExpansionTile>(
      find.byType(SliverExpansionTile),
    );
    expect(tileWidget.itemBuilder, isNull);
    expect(tileWidget.children, isNotEmpty);

    final expansibleWidget = tester.widget<SliverExpansible>(
      find.byType(SliverExpansible),
    );
    expect(expansibleWidget.maintainState, isTrue);
    expect(
      expansibleWidget.bodyRevealMode,
      SliverExpansibleBodyRevealMode.builderControlled,
    );

    final group = tester.widget<SliverMainAxisGroup>(
      find.byType(SliverMainAxisGroup),
    );
    expect(group.children[1], isA<SliverOffstage>());
    final bodyOffstage = group.children[1] as SliverOffstage;
    expect(bodyOffstage.offstage, isTrue);
    expect(bodyOffstage.child, isA<TickerMode>());
    expect((bodyOffstage.child! as TickerMode).child, isA<SliverToBoxAdapter>());

    expect(find.text('Body', skipOffstage: false), findsOneWidget);

    controller.expand();
    await tester.pump();

    final groupExpanded = tester.widget<SliverMainAxisGroup>(
      find.byType(SliverMainAxisGroup),
    );
    expect(groupExpanded.children[1], isA<SliverOffstage>());
    expect((groupExpanded.children[1] as SliverOffstage).offstage, isFalse);
  });

  testWidgets('builder children are not built while collapsed', (tester) async {
    final controller = SliverExpansibleController();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            itemCount: 1,
            itemBuilder: (context, index) => const Text('Body'),
          ),
        ],
      ),
    );

    final expansibleWidget = tester.widget<SliverExpansible>(
      find.byType(SliverExpansible),
    );
    expect(
      expansibleWidget.bodyRevealMode,
      SliverExpansibleBodyRevealMode.sliverClipReveal,
    );
    expect(find.byType(SliverToBoxAdapter), findsNothing);
    expect(find.text('Body', skipOffstage: false), findsNothing);
  });

  testWidgets('collapsed is lazy — builder items not built', (tester) async {
    final controller = SliverExpansibleController();
    var buildCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            itemCount: 1000,
            itemBuilder: (context, index) {
              buildCount++;
              return Text('Item $index', textDirection: TextDirection.ltr);
            },
          ),
        ],
      ),
    );

    expect(buildCount, lessThan(10));
    expect(controller.isExpanded, isFalse);
  });

  testWidgets('expand builds items progressively', (tester) async {
    final controller = SliverExpansibleController();
    var buildCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 200),
              curve: Curves.linear,
            ),
            itemCount: 1000,
            itemBuilder: (context, index) {
              buildCount++;
              return ListTile(title: Text('Item $index'));
            },
          ),
        ],
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

  testWidgets('expandedAlignment and expandedCrossAxisAlignment apply to eager children only', (
    tester,
  ) async {
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            title: const Text('Group'),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [Text('Body')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final expandedAlign = tester.widget<Align>(
      find.byWidgetPredicate(
        (w) => w is Align && w.heightFactor == null && w.child is Padding,
      ),
    );
    expect(expandedAlign.alignment, Alignment.centerLeft);

    final expandedColumn = tester.widget<Column>(
      find.descendant(
        of: find.byType(SliverToBoxAdapter),
        matching: find.byType(Column),
      ),
    );
    expect(expandedColumn.crossAxisAlignment, CrossAxisAlignment.start);
  });

  // -------------------------------------------------------------------------
  // Layout
  // -------------------------------------------------------------------------

  testWidgets('scroll extent grows when expanded', (tester) async {
    final controller = SliverExpansibleController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      _buildHarness(
        scrollController: scrollController,
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 100),
            ),
            itemCount: 200,
            itemBuilder: (context, index) =>
                ListTile(title: Text('Item $index')),
          ),
        ],
      ),
    );

    final collapsedMaxExtent = scrollController.position.maxScrollExtent;

    controller.expand();
    await tester.pumpAndSettle();

    final expandedMaxExtent = scrollController.position.maxScrollExtent;
    expect(expandedMaxExtent, greaterThan(collapsedMaxExtent));
  });

  testWidgets('header extent uses ListTile default height (1-line)', (
    tester,
  ) async {
    const visualDensity = VisualDensity.standard;
    const isDense = false;
    const isThreeLine = false;

    final expected = _listTileDefaultHeight(
      isDense: isDense,
      isThreeLine: isThreeLine,
      hasSubtitle: false,
      visualDensity: visualDensity,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(visualDensity: visualDensity),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverExpansionTile.builder(
                title: const Text('Group'),
                dense: isDense,
                isThreeLine: isThreeLine,
                visualDensity: visualDensity,
                itemCount: 0,
                itemBuilder: (context, index) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    final header = tester.renderObject<RenderSliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.geometry!.scrollExtent, expected);
  });

  testWidgets('header extent uses ThemeData.visualDensity fallback', (
    tester,
  ) async {
    const themeVisualDensity = VisualDensity(vertical: 4.0, horizontal: 0.0);
    const isDense = false;
    const isThreeLine = true;
    const subtitle = Text('Subtitle');

    final expected = _listTileDefaultHeight(
      isDense: isDense,
      isThreeLine: isThreeLine,
      hasSubtitle: true,
      visualDensity: themeVisualDensity,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(visualDensity: themeVisualDensity),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverExpansionTile.builder(
                title: const Text('Group'),
                subtitle: subtitle,
                dense: isDense,
                isThreeLine: isThreeLine,
                itemCount: 0,
                itemBuilder: (context, index) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    final header = tester.renderObject<RenderSliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.geometry!.scrollExtent, expected);
  });

  // -------------------------------------------------------------------------
  // maintainState
  // -------------------------------------------------------------------------

  testWidgets('maintainState=false disposes body after collapse', (
    tester,
  ) async {
    _DisposeSpy.disposeCount = 0;
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            maintainState: false,
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 80),
              curve: Curves.linear,
            ),
            title: const Text('Group'),
            children: const [_DisposeSpy(height: 20)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

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
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            maintainState: true,
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 80),
              curve: Curves.linear,
            ),
            title: const Text('Group'),
            children: const [_DisposeSpy(height: 20)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    controller.collapse();
    await tester.pumpAndSettle();

    expect(_DisposeSpy.disposeCount, 0);
  });

  // -------------------------------------------------------------------------
  // Semantics
  // -------------------------------------------------------------------------

  testWidgets('collapsed body excluded from semantics when maintained', (
    tester,
  ) async {
    final controller = SliverExpansibleController()..expand();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 80),
              curve: Curves.linear,
            ),
            maintainState: true,
            title: const Text('Group'),
            children: const [Text('Body')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

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

  // -------------------------------------------------------------------------
  // Hit testing
  // -------------------------------------------------------------------------

  testWidgets('collapsed body does not receive hits; expanded does', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(240, 200));

    final controller = SliverExpansibleController();
    var taps = 0;

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile(
            controller: controller,
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 80),
              curve: Curves.linear,
            ),
            title: const Text('Group'),
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(height: 100, width: double.infinity),
              ),
            ],
          ),
        ],
      ),
    );

    // Tap where the body would appear.
    await tester.tapAt(const Offset(10, 80));
    await tester.pump();
    expect(taps, 0);

    controller.expand();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 80));
    await tester.pump();
    expect(taps, 1);
  });

  // -------------------------------------------------------------------------
  // Controller lifecycle
  // -------------------------------------------------------------------------

  testWidgets('controller can change while animation is running', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(240, 200));

    final controllerA = SliverExpansibleController();
    final controllerB = SliverExpansibleController(); // collapsed

    Widget buildWith(SliverExpansibleController controller) {
      return _buildHarness(
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 200),
              curve: Curves.linear,
            ),
            itemCount: 200,
            itemBuilder: (context, index) => const SizedBox(height: 20),
          ),
        ],
      );
    }

    await tester.pumpWidget(buildWith(controllerA));

    controllerA.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // mid animation

    await tester.pumpWidget(buildWith(controllerB));
    await tester.pumpAndSettle();

    expect(controllerB.isExpanded, isFalse);
  });

  testWidgets('spam expand/collapse does not throw', (tester) async {
    await _setSurfaceSize(tester, const Size(240, 200));

    final controller = SliverExpansibleController();

    await tester.pumpWidget(
      _buildHarness(
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 200),
              curve: Curves.linear,
            ),
            itemCount: 200,
            itemBuilder: (context, index) => const SizedBox(height: 20),
          ),
        ],
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

  // -------------------------------------------------------------------------
  // PageStorage restoration (delegated to SliverExpansible)
  // -------------------------------------------------------------------------

  Widget buildRestorationHarness({
    required SliverExpansibleController controller,
    required Key? key,
    required PageStorageBucket bucket,
    required bool showTile,
  }) {
    return _buildHarness(
      bucket: bucket,
      slivers: [
        if (showTile)
          SliverExpansionTile(
            key: key,
            controller: controller,
            expansionAnimationStyle: const AnimationStyle(
              duration: Duration(milliseconds: 50),
              curve: Curves.linear,
            ),
            title: const Text('Group'),
            children: const [Text('Body content')],
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 1)),
      ],
    );
  }

  testWidgets('restores expanded state with PageStorageKey', (tester) async {
    await _setSurfaceSize(tester, const Size(240, 140));

    final controller = SliverExpansibleController();
    const key = PageStorageKey('tile-key');
    final bucket = PageStorageBucket();

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controller,
        key: key,
        bucket: bucket,
        showTile: true,
      ),
    );

    controller.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controller,
        key: key,
        bucket: bucket,
        showTile: false,
      ),
    );
    await tester.pump();

    final restoredController = SliverExpansibleController();
    await tester.pumpWidget(
      buildRestorationHarness(
        controller: restoredController,
        key: key,
        bucket: bucket,
        showTile: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsOneWidget);
    expect(restoredController.isExpanded, isTrue);
  });

  testWidgets('does not restore expanded state without PageStorageKey', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(240, 140));

    final controller = SliverExpansibleController();
    final bucket = PageStorageBucket();

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controller,
        key: null,
        bucket: bucket,
        showTile: true,
      ),
    );

    controller.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controller,
        key: null,
        bucket: bucket,
        showTile: false,
      ),
    );
    await tester.pump();

    final controllerB = SliverExpansibleController();
    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controllerB,
        key: null,
        bucket: bucket,
        showTile: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsNothing);
    expect(controllerB.isExpanded, isFalse);
  });

  testWidgets('PageStorage overrides controller initial state', (tester) async {
    await _setSurfaceSize(tester, const Size(240, 140));

    const key = PageStorageKey('precedence-key');
    final bucket = PageStorageBucket();

    final controllerA = SliverExpansibleController();
    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controllerA,
        key: key,
        bucket: bucket,
        showTile: true,
      ),
    );
    controllerA.expand();
    await tester.pumpAndSettle();
    expect(find.text('Body content'), findsOneWidget);

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controllerA,
        key: key,
        bucket: bucket,
        showTile: false,
      ),
    );
    await tester.pump();

    final controllerB = SliverExpansibleController();
    expect(controllerB.isExpanded, isFalse);

    await tester.pumpWidget(
      buildRestorationHarness(
        controller: controllerB,
        key: key,
        bucket: bucket,
        showTile: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body content'), findsOneWidget);
    expect(controllerB.isExpanded, isTrue);
  });

  // -------------------------------------------------------------------------
  // Pinned + shape/background behavior (pixel assertions)
  // -------------------------------------------------------------------------

  testWidgets('shape + clip + pinned still pins and toggles', (tester) async {
    await _setSurfaceSize(tester, const Size(240, 240));

    final controller = SliverExpansibleController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      _buildHarness(
        scrollController: scrollController,
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const Text('Group'),
            pinned: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.red,
            collapsedBackgroundColor: Colors.red,
            itemCount: 200,
            itemBuilder: (context, index) =>
                ListTile(title: Text('Item $index')),
          ),
        ],
      ),
    );

    final collapsedMaxExtent = scrollController.position.maxScrollExtent;

    controller.expand();
    await tester.pumpAndSettle();

    final expandedMaxExtent = scrollController.position.maxScrollExtent;
    expect(expandedMaxExtent, greaterThan(collapsedMaxExtent));
    expect(find.text('Item 0'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pump();
    expect(find.text('Group'), findsOneWidget);
  });

  testWidgets('tile background paints under pinned header (shape+clip)', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(200, 200));

    final boundaryKey = GlobalKey();
    final controller = SliverExpansibleController();

    await tester.pumpWidget(
      _buildHarness(
        boundaryKey: boundaryKey,
        background: Colors.green,
        slivers: [
          SliverExpansionTile.builder(
            controller: controller,
            title: const SizedBox.shrink(),
            showTrailingIcon: false,
            tilePadding: EdgeInsets.zero,
            pinned: true,
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.red,
            collapsedBackgroundColor: Colors.red,
            itemCount: 100,
            itemBuilder: (context, index) =>
                const SizedBox(height: 48, width: double.infinity),
          ),
        ],
      ),
    );

    controller.expand();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();

    final headerRect = tester.getRect(find.byType(ListTile).first);
    final (image, bytes) = await _captureRawRgba(tester, boundaryKey);
    final (r, g, b, a) = _sampleRgba(
      bytes,
      image.width,
      headerRect.center.dx.round().clamp(0, image.width - 1),
      headerRect.center.dy.round().clamp(0, image.height - 1),
    );
    image.dispose();

    expect(a, greaterThanOrEqualTo(200));
    expect(r, greaterThanOrEqualTo(200));
    expect(g, lessThanOrEqualTo(120));
    expect(b, lessThanOrEqualTo(120));
  });

  testWidgets(
    'pinned + shape does not paint background beyond header when collapsed',
    (tester) async {
      await _setSurfaceSize(tester, const Size(200, 200));

      final boundaryKey = GlobalKey();
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildHarness(
          boundaryKey: boundaryKey,
          background: Colors.green,
          scrollController: scrollController,
          slivers: [
            SliverExpansionTile.builder(
              title: const SizedBox.shrink(),
              showTrailingIcon: false,
              tilePadding: EdgeInsets.zero,
              pinned: true,
              shape: const RoundedRectangleBorder(),
              collapsedShape: const RoundedRectangleBorder(),
              clipBehavior: Clip.antiAlias,
              backgroundColor: Colors.red,
              collapsedBackgroundColor: Colors.red,
              itemCount: 0,
              itemBuilder: (context, index) => const SizedBox.shrink(),
            ),
            SliverFixedExtentList(
              itemExtent: 48,
              delegate: SliverChildBuilderDelegate(
                (context, index) => const SizedBox.expand(),
                childCount: 200,
              ),
            ),
          ],
        ),
      );

      scrollController.jumpTo(800);
      await tester.pumpAndSettle();
      scrollController.jumpTo(40);
      await tester.pumpAndSettle();

      final (image, bytes) = await _captureRawRgba(tester, boundaryKey);
      final (r, g, b, a) = _sampleRgba(bytes, image.width, 10, 160);
      image.dispose();

      expect(a, greaterThanOrEqualTo(200));
      expect(g, greaterThan(r));
      expect(r, lessThanOrEqualTo(160));
      expect(b, lessThanOrEqualTo(160));
    },
  );

  testWidgets('rounded shape clips bottom corners when collapsed', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(200, 200));

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      _buildHarness(
        boundaryKey: boundaryKey,
        background: Colors.green,
        slivers: [
          SliverExpansionTile(
            title: const SizedBox.shrink(),
            showTrailingIcon: false,
            tilePadding: EdgeInsets.zero,
            pinned: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.red,
            collapsedBackgroundColor: Colors.red,
            children: const [],
          ),
        ],
      ),
    );

    final headerRect = tester.getRect(find.byType(ListTile).first);
    final (image, bytes) = await _captureRawRgba(tester, boundaryKey);
    final (r, g, b, a) = _sampleRgba(
      bytes,
      image.width,
      (headerRect.left + 1).round().clamp(0, image.width - 1),
      (headerRect.bottom - 1).round().clamp(0, image.height - 1),
    );
    image.dispose();

    expect(a, greaterThanOrEqualTo(200));
    expect(g, greaterThan(r));
    expect(r, lessThanOrEqualTo(160));
    expect(b, lessThanOrEqualTo(160));
  });

  testWidgets('rounded shape clips bottom corners when expanded and pinned', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(200, 200));

    final boundaryKey = GlobalKey();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      _buildHarness(
        boundaryKey: boundaryKey,
        background: Colors.green,
        scrollController: scrollController,
        slivers: [
          SliverFixedExtentList(
            itemExtent: 48,
            delegate: SliverChildBuilderDelegate(
              (context, index) => const SizedBox.expand(),
              childCount: 3,
            ),
          ),
          SliverExpansionTile(
            title: const SizedBox.shrink(),
            showTrailingIcon: false,
            tilePadding: EdgeInsets.zero,
            pinned: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.red,
            collapsedBackgroundColor: Colors.red,
            children: const [
              SizedBox(
                key: ValueKey('tile-child'),
                height: 24,
                width: double.infinity,
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    scrollController.jumpTo(48 * 3 + 10);
    await tester.pumpAndSettle();

    final childRect = tester.getRect(find.byKey(const ValueKey('tile-child')));
    final (image, bytes) = await _captureRawRgba(tester, boundaryKey);
    final (r, g, b, a) = _sampleRgba(
      bytes,
      image.width,
      (childRect.left + 1).round().clamp(0, image.width - 1),
      (childRect.bottom - 1).round().clamp(0, image.height - 1),
    );
    image.dispose();

    expect(a, greaterThanOrEqualTo(200));
    expect(g, greaterThan(r));
    expect(r, lessThanOrEqualTo(160));
    expect(b, lessThanOrEqualTo(160));
  });
}
