import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const Duration _kDefaultDuration = Duration(milliseconds: 200);
const Curve _kDefaultCurve = Curves.ease;

/// The type of the callback that returns the header or body of a
/// [SliverExpansible].
///
/// The `animation` property exposes the underlying expanding or collapsing
/// animation, which has a value of 0 when the [SliverExpansible] is completely
/// collapsed and 1 when it is completely expanded.
///
/// The widget returned from this callback must be a sliver widget (for example
/// [SliverToBoxAdapter], [SliverList], or [SliverPadding]).
///
/// See also:
///
///  * [SliverExpansible.headerBuilder], which is of this type.
///  * [SliverExpansible.bodyBuilder], which is also of this type.
typedef SliverExpansibleComponentBuilder =
    Widget Function(BuildContext context, Animation<double> animation);

/// The type of the callback that uses the header and body of a
/// [SliverExpansible] widget to build the sliver.
///
/// The `header` property is the header returned by
/// [SliverExpansible.headerBuilder].
///
/// The `body` property is the body returned by [SliverExpansible.bodyBuilder]
/// optionally wrapped in an internal sliver that expands and collapses it,
/// depending on [SliverExpansible.bodyRevealMode].
///
/// In [SliverExpansibleBodyRevealMode.builderControlled], the body may also be
/// wrapped in a [SliverOffstage] and [TickerMode] when the widget is fully
/// collapsed, mirroring the behavior of [Expansible].
///
/// The `animation` property exposes the underlying expanding or collapsing
/// animation, which has a value of 0 when the [SliverExpansible] is completely
/// collapsed and 1 when it is completely expanded.
///
/// See also:
///
///  * [SliverExpansible.expansibleBuilder], which is of this type.
typedef SliverExpansibleBuilder =
    Widget Function(
      BuildContext context,
      Widget header,
      Widget body,
      Animation<double> animation,
    );

/// Controls how the collapsible body of a [SliverExpansible] is revealed.
enum SliverExpansibleBodyRevealMode {
  /// Wraps the body sliver in an internal sliver that animates its main axis
  /// extent from zero to its fully expanded extent.
  ///
  /// This mode keeps sliver bodies lazy (for example, only visible list items
  /// are built).
  sliverClipReveal,

  /// Leaves the body sliver as built by [SliverExpansible.bodyBuilder].
  ///
  /// In this mode, the [SliverExpansible] does not apply any reveal/collapse
  /// wrapper. The builder is responsible for revealing the content.
  ///
  /// When the [SliverExpansible] is fully collapsed (the animation is
  /// dismissed), the body is wrapped in a [SliverOffstage] and [TickerMode] to
  /// hide it from paint, hit testing, and semantics, and to disable tickers in
  /// the body subtree.
  builderControlled,
}

/// A controller for managing the expansion state of a [SliverExpansible].
///
/// This class is a [ChangeNotifier] that notifies its listeners if the value of
/// [isExpanded] changes.
///
/// The controller's [expand] and [collapse] methods cause the
/// [SliverExpansible] to rebuild, so they may not be called from
/// a build method.
///
/// Remember to [dispose] of the [SliverExpansibleController] when it is no
/// longer needed. This will ensure all resources used by the object are
/// discarded.
class SliverExpansibleController extends ChangeNotifier {
  /// Creates a controller to be used with [SliverExpansible.controller].
  SliverExpansibleController();

  bool _isExpanded = false;

  void _setExpansionState(bool newValue) {
    if (newValue != _isExpanded) {
      _isExpanded = newValue;
      notifyListeners();
    }
  }

  /// Whether the expansible sliver built with this controller is in expanded
  /// state.
  ///
  /// This property doesn't take the animation into account. It reports `true`
  /// even if the expansion animation is not completed.
  bool get isExpanded => _isExpanded;

  /// Expands the [SliverExpansible] that was built with this controller.
  ///
  /// If the widget is already in the expanded state (see [isExpanded]), calling
  /// this method has no effect.
  void expand() {
    _setExpansionState(true);
  }

  /// Collapses the [SliverExpansible] that was built with this controller.
  ///
  /// If the widget is already in the collapsed state (see [isExpanded]),
  /// calling this method has no effect.
  void collapse() {
    _setExpansionState(false);
  }

  /// Toggles the expansion state of the [SliverExpansible].
  void toggle() {
    if (isExpanded) {
      collapse();
    } else {
      expand();
    }
  }

  /// Finds the [SliverExpansibleController] for the closest [SliverExpansible]
  /// instance that encloses the given context.
  ///
  /// If no [SliverExpansible] encloses the given context, calling this method
  /// will cause an assert in debug mode, and throw an exception in release
  /// mode.
  ///
  /// To return null if there is no [SliverExpansible] use [maybeOf] instead.
  ///
  /// Typical usage of the [SliverExpansibleController.of] function is to call
  /// it from within the `build` method of a descendant of a [SliverExpansible].
  static SliverExpansibleController of(BuildContext context) {
    final result = context.findAncestorStateOfType<_SliverExpansibleState>();
    assert(
      () {
        if (result == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'SliverExpansibleController.of() called with a context that '
              'does not contain a SliverExpansible.',
            ),
            ErrorDescription(
              'No SliverExpansible ancestor could be found starting from the '
              'context that was passed to SliverExpansibleController.of(). '
              'This usually happens when the context provided is from the '
              'same StatefulWidget as that whose build function actually '
              'creates the SliverExpansible widget being sought.',
            ),
            ErrorHint(
              'There are several ways to avoid this problem. The simplest is '
              'to use a Builder to get a context that is "under" the '
              'SliverExpansible.',
            ),
            ErrorHint(
              'A more efficient solution is to split your build function into '
              'several widgets. This introduces a new context from which you '
              'can obtain the SliverExpansible. In this solution, you would '
              'have an outer widget that creates the SliverExpansible '
              'populated by instances of your new inner widgets, and then in '
              'these inner widgets you would use '
              'SliverExpansibleController.of().\n'
              'An other solution is assign a GlobalKey to the '
              'SliverExpansible, then use the key.currentState property to '
              'obtain the SliverExpansible rather than using the '
              'SliverExpansibleController.of() function.',
            ),
            context.describeElement('The context used was'),
          ]);
        }
        return true;
      }(),
      'SliverExpansibleController.of() called with a context that does not '
      'contain a SliverExpansible.',
    );
    return result!.widget.controller;
  }

  /// Finds the [SliverExpansibleController] for the closest [SliverExpansible]
  /// instance that encloses the given context.
  ///
  /// If no [SliverExpansible] encloses the given context then return null.
  /// To throw an exception instead, use [of] instead of this function.
  static SliverExpansibleController? maybeOf(BuildContext context) {
    return context
        .findAncestorStateOfType<_SliverExpansibleState>()
        ?.widget
        .controller;
  }
}

/// A sliver that expands and collapses.
///
/// A [SliverExpansible] consists of a header, which is always shown, and a
/// body, which is hidden in its collapsed state and shown in its expanded
/// state.
///
/// The [SliverExpansible] is expanded or collapsed with an animation driven by
/// an [AnimationController]. When the widget is expanded, the main axis extent
/// of its body animates from 0 to its fully expanded extent.
///
/// When used with scrolling widgets like [CustomScrollView], a unique
/// [PageStorageKey] must be specified as the [key], to enable the
/// [SliverExpansible] to save and restore its expanded state when it is
/// scrolled in and out of view.
///
/// Provide [headerBuilder] and [bodyBuilder] callbacks to build the header and
/// body slivers. An additional [expansibleBuilder] callback can be provided to
/// further customize the layout of the sliver.
///
/// The [SliverExpansible] does not inherently toggle the expansion state. To
/// toggle the expansion state, call [SliverExpansibleController.expand] and
/// [SliverExpansibleController.collapse] as needed, most typically in response
/// to a user gesture on the header.
///
/// See also:
///
///  * [Expansible], the box equivalent widget.
class SliverExpansible extends StatefulWidget {
  /// Creates an instance of [SliverExpansible].
  const SliverExpansible({
    required this.headerBuilder,
    required this.bodyBuilder,
    required this.controller,
    super.key,
    this.expansibleBuilder = _defaultExpansibleBuilder,
    this.animationStyle,
    this.bodyRevealMode = SliverExpansibleBodyRevealMode.sliverClipReveal,
    this.maintainState = true,
  });

  /// Expands and collapses the sliver.
  ///
  /// The controller manages the expansion state and toggles the expansion.
  final SliverExpansibleController controller;

  /// Builds the always-displayed header sliver.
  final SliverExpansibleComponentBuilder headerBuilder;

  /// Builds the collapsible body sliver.
  final SliverExpansibleComponentBuilder bodyBuilder;

  /// Controls how the body sliver is revealed when expanding/collapsing.
  ///
  /// Defaults to [SliverExpansibleBodyRevealMode.sliverClipReveal].
  final SliverExpansibleBodyRevealMode bodyRevealMode;

  /// Used to override the expansion animation curve and duration.
  ///
  /// If [AnimationStyle.duration] is provided, it will be used for the
  /// expansion animation. If not provided, the default duration is 200ms.
  ///
  /// If [AnimationStyle.curve] is provided, it will be used for the expansion
  /// and collapse animation curve. If not provided, the default curve is
  /// [Curves.ease].
  ///
  /// If [AnimationStyle.reverseCurve] is provided, it will be used for the
  /// collapse animation curve. If null, the forward [AnimationStyle.curve] is
  /// used in both directions.
  ///
  /// To disable the animation, use [AnimationStyle.noAnimation].
  final AnimationStyle? animationStyle;

  /// Whether the state of the body is maintained when the widget expands or
  /// collapses.
  ///
  /// If true, the body is kept in the tree while the widget is collapsed.
  /// Otherwise, the body is removed from the tree when the widget is collapsed
  /// and recreated upon expansion.
  ///
  /// Defaults to true.
  final bool maintainState;

  /// Builds the sliver with the results of [headerBuilder] and [bodyBuilder].
  ///
  /// Defaults to placing the header and body in a [SliverMainAxisGroup].
  final SliverExpansibleBuilder expansibleBuilder;

  static Widget _defaultExpansibleBuilder(
    BuildContext context,
    Widget header,
    Widget body,
    Animation<double> animation,
  ) {
    return SliverMainAxisGroup(slivers: <Widget>[header, body]);
  }

  @override
  State<StatefulWidget> createState() => _SliverExpansibleState();
}

class _SliverExpansibleState extends State<SliverExpansible>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  CurvedAnimation? _mainAxisFactor;

  Duration get _duration {
    return widget.animationStyle?.duration ?? _kDefaultDuration;
  }

  Curve get _curve {
    return widget.animationStyle?.curve ?? _kDefaultCurve;
  }

  Curve? get _reverseCurve {
    return widget.animationStyle?.reverseCurve;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _duration,
      vsync: this,
    );

    final initiallyExpanded =
        PageStorage.maybeOf(context)?.readState(context) as bool? ??
        widget.controller.isExpanded;

    if (initiallyExpanded) {
      _animationController.value = 1;
      widget.controller.expand();
    } else {
      widget.controller.collapse();
    }

    if (widget.bodyRevealMode == .sliverClipReveal) {
      final factorTween = Tween<double>(begin: 0, end: 1);
      _mainAxisFactor = CurvedAnimation(
        parent: _animationController.drive(factorTween),
        curve: _curve,
        reverseCurve: _reverseCurve,
      );
    }

    widget.controller.addListener(_toggleExpansion);
  }

  @override
  void didUpdateWidget(covariant SliverExpansible oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldDuration = oldWidget.animationStyle?.duration ?? _kDefaultDuration;
    final oldCurve = oldWidget.animationStyle?.curve ?? _kDefaultCurve;
    final oldReverseCurve = oldWidget.animationStyle?.reverseCurve;

    if (_curve != oldCurve) {
      _mainAxisFactor?.curve = _curve;
    }
    if (_reverseCurve != oldReverseCurve) {
      _mainAxisFactor?.reverseCurve = _reverseCurve;
    }
    if (_duration != oldDuration) {
      _animationController.duration = _duration;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_toggleExpansion);
      widget.controller.addListener(_toggleExpansion);
      if (oldWidget.controller.isExpanded != widget.controller.isExpanded) {
        _toggleExpansion();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_toggleExpansion);
    _animationController.dispose();
    _mainAxisFactor?.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      // Rebuild with the header and the animating body.
      if (widget.controller.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse().then((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            // Rebuild without the body, if maintainState is false.
          });
        });
      }
      PageStorage.maybeOf(
        context,
      )?.writeState(context, widget.controller.isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !_animationController.isDismissed || !widget.controller.isExpanded,
      'A SliverExpansible cannot be marked as expanded when its animation is '
      'dismissed.',
    );

    final closed =
        !widget.controller.isExpanded && _animationController.isDismissed;
    final shouldRemoveBody = closed && !widget.maintainState;

    final Widget result = switch (widget.bodyRevealMode) {
      .sliverClipReveal => TickerMode(
        enabled: !closed,
        child: widget.bodyBuilder(context, _animationController),
      ),
      .builderControlled => SliverOffstage(
        offstage: closed,
        sliver: TickerMode(
          enabled: !closed,
          child: widget.bodyBuilder(context, _animationController),
        ),
      ),
    };

    return AnimatedBuilder(
      animation: _animationController.view,
      builder: (context, child) {
        final header = widget.headerBuilder(context, _animationController);
        final factor = _mainAxisFactor;

        final Widget body = switch (widget.bodyRevealMode) {
          .sliverClipReveal when factor != null => _SliverExpansibleBody(
            factor: factor,
            sliver: child,
          ),
          .builderControlled =>
            child ?? const SliverToBoxAdapter(child: SizedBox.shrink()),
          _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
        };
        return widget.expansibleBuilder(
          context,
          header,
          body,
          _animationController,
        );
      },
      child: shouldRemoveBody ? null : result,
    );
  }
}

class _SliverExpansibleBody extends SingleChildRenderObjectWidget {
  const _SliverExpansibleBody({required this.factor, Widget? sliver})
    : super(child: sliver);

  final Animation<double> factor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverExpansibleBody(factor: factor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSliverExpansibleBody renderObject,
  ) {
    renderObject.factor = factor;
  }
}

class _RenderSliverExpansibleBody extends RenderProxySliver
    with RenderSliverHelpers {
  _RenderSliverExpansibleBody({required Animation<double> factor})
    : _factor = factor {
    _wasOffstage = _isOffstage;
    _factor.addListener(_handleFactorChanged);
  }

  Animation<double> _factor;
  late bool _wasOffstage;

  bool get _isOffstage => _factor.value == 0;

  void _handleFactorChanged() {
    final isOffstage = _isOffstage;
    if (isOffstage != _wasOffstage) {
      _wasOffstage = isOffstage;
      markNeedsSemanticsUpdate();
    }
    markNeedsLayout();
  }

  Animation<double> get factor => _factor;

  set factor(Animation<double> value) {
    if (_factor == value) return;
    _factor.removeListener(_handleFactorChanged);
    _factor = value;
    _wasOffstage = _isOffstage;
    _factor.addListener(_handleFactorChanged);
    markNeedsLayout();
  }

  @override
  void dispose() {
    _factor.removeListener(_handleFactorChanged);
    super.dispose();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_isOffstage) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  bool hitTest(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (_isOffstage) {
      return false;
    }
    return super.hitTest(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    );
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (_isOffstage) {
      return false;
    }
    return super.hitTestChildren(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    );
  }

  @override
  void performLayout() {
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }

    final f = _factor.value.clamp(0.0, 1.0);

    if (f == 0) {
      geometry = SliverGeometry.zero;
      return;
    }

    // Layout child with full constraints first. Many slivers (SliverList, SliverGrid...)
    // report a stable full scrollExtent only when given unconstrained remaining extent.
    // Scaling constraints here can cause unstable estimates during animation.
    child!.layout(constraints, parentUsesSize: true);

    final fullGeometry = child!.geometry!;
    final revealedScrollExtent = fullGeometry.scrollExtent * f;

    final paintExtent = calculatePaintOffset(
      constraints,
      from: 0,
      to: revealedScrollExtent,
    );
    final desiredRemainingCacheExtent = _clampRemainingCacheExtent(
      constraints,
      revealedScrollExtent,
    );

    // Optional second pass: clamp child to visible + cache window to avoid
    // unnecessary layout/build of offscreen content.
    final SliverConstraints desiredConstraints = constraints.copyWith(
      remainingPaintExtent: paintExtent,
      remainingCacheExtent: desiredRemainingCacheExtent,
    );

    if (desiredConstraints.remainingPaintExtent !=
            constraints.remainingPaintExtent ||
        desiredConstraints.remainingCacheExtent !=
            constraints.remainingCacheExtent) {
      child!.layout(desiredConstraints, parentUsesSize: true);
    }

    final cacheExtent = calculateCacheOffset(
      constraints,
      from: 0,
      to: revealedScrollExtent,
    );

    geometry = SliverGeometry(
      scrollExtent: revealedScrollExtent,
      paintExtent: paintExtent,
      layoutExtent: paintExtent,
      // Use revealed extent for maxPaintExtent to keep geometry stable across
      // different sliver implementations.
      maxPaintExtent: revealedScrollExtent,
      cacheExtent: cacheExtent,
      hitTestExtent: paintExtent,
      hasVisualOverflow: f < 1.0,
    );
  }

  double _clampRemainingCacheExtent(
    SliverConstraints constraints,
    double revealedScrollExtent,
  ) {
    final cacheStart = constraints.scrollOffset + constraints.cacheOrigin;
    final cacheEndOriginal =
        constraints.scrollOffset + constraints.remainingCacheExtent;
    final cacheEnd = math.min(cacheEndOriginal, revealedScrollExtent);
    return math.max(0, cacheEnd - cacheStart);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || geometry == null || !geometry!.visible) return;

    final axis = constraints.axis;
    final clipSize = axis == Axis.vertical
        ? Size(constraints.crossAxisExtent, geometry!.paintExtent)
        : Size(geometry!.paintExtent, constraints.crossAxisExtent);

    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & clipSize,
      (ctx, innerOffset) => ctx.paintChild(child!, innerOffset),
    );
  }
}
