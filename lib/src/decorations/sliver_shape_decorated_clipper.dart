part of '../sliver_expansion_tile.dart';

/// Paints a [ShapeDecoration] behind a sliver child and clips the painted
/// output to the decoration's shape.
///
/// This is an internal helper used by [SliverExpansionTile] to support
/// animated `shape` + `backgroundColor` while keeping pinned header behavior
/// correct.
class _SliverShapeDecoratedClipper extends SingleChildRenderObjectWidget {
  const _SliverShapeDecoratedClipper({
    required this.decoration,
    required this.clipBehavior,
    required this.isPinned,
    required this.headerExtent,
    required this.configuration,
    required Widget sliver,
  }) : super(child: sliver);

  final ShapeDecoration decoration;
  final Clip clipBehavior;
  final bool isPinned;
  final double headerExtent;
  final ImageConfiguration configuration;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverShapeDecoratedClipper(
      decoration: decoration,
      clipBehavior: clipBehavior,
      isPinned: isPinned,
      headerExtent: headerExtent,
      configuration: configuration,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSliverShapeDecoratedClipper renderObject,
  ) {
    renderObject
      ..decoration = decoration
      ..clipBehavior = clipBehavior
      ..isPinned = isPinned
      ..headerExtent = headerExtent
      ..configuration = configuration;
  }
}

class _RenderSliverShapeDecoratedClipper extends RenderProxySliver {
  _RenderSliverShapeDecoratedClipper({
    required ShapeDecoration decoration,
    required Clip clipBehavior,
    required bool isPinned,
    required double headerExtent,
    required ImageConfiguration configuration,
  })  : _decoration = decoration,
        _clipBehavior = clipBehavior,
        _isPinned = isPinned,
        _headerExtent = headerExtent,
        _configuration = configuration;

  ShapeDecoration get decoration => _decoration;
  ShapeDecoration _decoration;
  set decoration(ShapeDecoration value) {
    if (value == decoration) {
      return;
    }
    _decoration = value;
    _painter?.dispose();
    _painter = decoration.createBoxPainter(markNeedsPaint);
    markNeedsPaint();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (value == clipBehavior) {
      return;
    }
    _clipBehavior = value;
    markNeedsPaint();
  }

  bool get isPinned => _isPinned;
  bool _isPinned;
  set isPinned(bool value) {
    if (value == isPinned) {
      return;
    }
    _isPinned = value;
    markNeedsPaint();
  }

  double get headerExtent => _headerExtent;
  double _headerExtent;
  set headerExtent(double value) {
    if (value == headerExtent) {
      return;
    }
    _headerExtent = value;
    markNeedsPaint();
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == configuration) {
      return;
    }
    _configuration = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  @override
  void attach(covariant PipelineOwner owner) {
    _painter = decoration.createBoxPainter(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    layer = null;
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !child!.geometry!.visible) {
      layer = null;
      return;
    }

    _painter ??= decoration.createBoxPainter(markNeedsPaint);

    final Offset childOffset =
        offset + (child!.parentData! as SliverPhysicalParentData).paintOffset;

    // Clip decoration/shape to the sliver's current paint extent.
    final AxisDirection axisDirection = applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    );
    final Rect paintRect = switch (axisDirection) {
      AxisDirection.up => Rect.fromLTWH(
          0.0,
          0.0,
          constraints.crossAxisExtent,
          math.max(0.0, child!.geometry!.paintExtent),
        ),
      AxisDirection.right => Rect.fromLTWH(
          child!.geometry!.paintOrigin,
          0.0,
          math.max(0.0, child!.geometry!.paintExtent),
          constraints.crossAxisExtent,
        ),
      AxisDirection.down => Rect.fromLTWH(
          0.0,
          child!.geometry!.paintOrigin,
          constraints.crossAxisExtent,
          math.max(0.0, child!.geometry!.paintExtent),
        ),
      AxisDirection.left => Rect.fromLTWH(
          0.0,
          0.0,
          math.max(0.0, child!.geometry!.paintExtent),
          constraints.crossAxisExtent,
        ),
    };

    // Cap to the cache window to avoid huge clip layers.
    final double maxCachedMainAxisExtent = constraints.scrollOffset +
        child!.geometry!.cacheExtent +
        constraints.cacheOrigin;
    final double cappedMainAxisExtent = math.min(
      child!.geometry!.scrollExtent,
      maxCachedMainAxisExtent,
    );

    final (Size childSize, Offset scrollOffset) = switch (constraints.axis) {
      Axis.horizontal => (
          Size(cappedMainAxisExtent, constraints.crossAxisExtent),
          Offset(-constraints.scrollOffset, 0.0),
        ),
      Axis.vertical => (
          Size(constraints.crossAxisExtent, cappedMainAxisExtent),
          Offset(0.0, -constraints.scrollOffset),
        ),
    };

    final bool pinnedActive = isPinned && constraints.scrollOffset > 0.0;
    final Offset decorationScrollOffset =
        pinnedActive ? Offset.zero : scrollOffset;

    // When pinned, model the remaining tile portion so bottom corners appear
    // at the correct position when they become visible.
    final Size decorationSize = pinnedActive
        ? () {
            final double remainingScrollExtent = math.max(
              0.0,
              child!.geometry!.scrollExtent - constraints.scrollOffset,
            );
            final double minPinnedExtent = math.max(0.0, headerExtent);
            final double unclamped =
                math.max(minPinnedExtent, remainingScrollExtent);
            final double maxCachedRelativeExtent = math.max(
              0.0,
              child!.geometry!.cacheExtent + constraints.cacheOrigin,
            );
            final double pinnedExtent = maxCachedRelativeExtent == 0.0
                ? unclamped
                : math.min(unclamped, maxCachedRelativeExtent);
            return switch (constraints.axis) {
              Axis.horizontal =>
                Size(pinnedExtent, constraints.crossAxisExtent),
              Axis.vertical => Size(constraints.crossAxisExtent, pinnedExtent),
            };
          }()
        : childSize;

    void paintAll(PaintingContext ctx, Offset off) {
      _painter!.paint(
        ctx.canvas,
        off + decorationScrollOffset,
        configuration.copyWith(size: decorationSize),
      );
      ctx.paintChild(child!, off);
    }

    if (clipBehavior == Clip.none) {
      context.canvas.save();
      context.canvas.clipRect(paintRect.shift(childOffset));
      _painter!.paint(
        context.canvas,
        childOffset + decorationScrollOffset,
        configuration.copyWith(size: decorationSize),
      );
      context.canvas.restore();
      context.paintChild(child!, childOffset);
      layer = null;
      return;
    }

    final Rect fullBounds = decorationScrollOffset & decorationSize;
    final Path shapePath = decoration.shape.getOuterPath(
      fullBounds,
      textDirection: configuration.textDirection,
    );
    final Path clipPath = Path.combine(
      PathOperation.intersect,
      shapePath,
      Path()..addRect(paintRect),
    );

    layer = context.pushClipPath(
      needsCompositing,
      childOffset,
      paintRect,
      clipPath,
      paintAll,
      clipBehavior: clipBehavior,
      oldLayer: layer as ClipPathLayer?,
    );
    assert(() {
      layer?.debugCreator = debugCreator;
      return true;
    }());
  }
}
