import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sliver_expansion/src/sliver_expansible.dart';

part 'decorations/sliver_shape_decorated_clipper.dart';

const Duration _kExpand = Duration(milliseconds: 200);

/// A sliver that shows a pinnable header and an animatable list of children.
///
/// Shows a [ListTile]-style header that the user can tap to expand or collapse
/// the tile, revealing or hiding [children]. Unlike [ExpansionTile], this
/// widget is a sliver and must be placed inside a [CustomScrollView] or
/// another sliver parent. The header can optionally pin to the top of the
/// viewport via [pinned].
///
/// ## Theming
///
/// This widget reads [ExpansionTileThemeData] from the nearest
/// [ExpansionTileTheme] ancestor. Properties set directly on the widget take
/// precedence over the theme. When neither the widget nor the theme provides a
/// value, Material 3 defaults apply:
///
///  * [iconColor] defaults to [ColorScheme.primary].
///  * [collapsedIconColor] defaults to [ColorScheme.onSurfaceVariant].
///  * [textColor] and [collapsedTextColor] default to [ColorScheme.onSurface].
///  * [backgroundColor] and [collapsedBackgroundColor] default to
///    [Colors.transparent].
///
/// The icon color, text color, and background color all animate between their
/// collapsed and expanded values during the expand/collapse transition.
///
/// ## Expand/collapse animation
///
/// The expand/collapse animation is controlled by [expansionAnimationStyle].
/// Pass a custom [AnimationStyle] to override the default duration
/// (200 milliseconds) and curve ([Curves.easeIn]).
///
/// ## Lazy building
///
/// The default [SliverExpansionTile] constructor takes an eager list of
/// [children] and reveals them with a box-based expand/collapse animation.
///
/// Use the [SliverExpansionTile.builder] constructor to lazily build children,
/// avoiding unnecessary widget creation when the tile is collapsed.
///
/// ## Programmatic control
///
/// To expand or collapse the tile programmatically, provide a
/// [SliverExpansibleController] via [controller]. An internal controller is
/// created automatically when none is provided, and can be retrieved with
/// [SliverExpansibleController.of].
///
/// See also:
///
///  * [ExpansionTile], the non-sliver equivalent from the Material library.
///  * [ExpansionTileTheme], for applying shared styles to multiple tiles.
///  * [SliverExpansible], the lower-level primitive this widget wraps.
///  * [SliverExpansibleController], for programmatic control.
class SliverExpansionTile extends StatefulWidget {
  /// Creates a [SliverExpansionTile] from an eager list of children.
  const SliverExpansionTile({
    super.key,
    this.subtitle,
    this.controller,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.pinned = false,
    this.expansionAnimationStyle,
    this.leading,
    this.trailing,
    this.showTrailingIcon = true,
    this.tilePadding,
    this.expandedCrossAxisAlignment,
    this.expandedAlignment,
    this.controlAffinity,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.pinnedHeaderColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
    this.childrenPadding,
    this.isThreeLine,
    this.dense,
    this.splashColor,
    this.visualDensity,
    this.minTileHeight,
    this.enableFeedback = true,
    this.enabled = true,
    this.onExpansionChanged,
    this.internalAddSemanticForOnTap = false,
    required this.title,
    this.children = const <Widget>[],
  }) : itemBuilder = null,
       itemCount = null,
       assert(
         expandedCrossAxisAlignment != CrossAxisAlignment.baseline,
         'CrossAxisAlignment.baseline is not supported since the expanded children '
         'are aligned in a column, not a row. Try to use another constant.',
       );

  /// Creates a [SliverExpansionTile] that lazily builds its children.
  ///
  /// Only children that are visible (or within the cache extent) are built.
  /// This is ideal when the tile contains many children.
  const SliverExpansionTile.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    this.subtitle,
    this.controller,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.pinned = false,
    this.expansionAnimationStyle,
    this.leading,
    this.trailing,
    this.showTrailingIcon = true,
    this.tilePadding,
    this.controlAffinity,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.pinnedHeaderColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
    this.childrenPadding,
    this.isThreeLine,
    this.dense,
    this.splashColor,
    this.visualDensity,
    this.minTileHeight,
    this.enableFeedback = true,
    this.enabled = true,
    this.onExpansionChanged,
    this.internalAddSemanticForOnTap = false,
    required this.title,
  }) : children = const <Widget>[],
       expandedAlignment = null,
       expandedCrossAxisAlignment = null;

  /// The primary content of the header row.
  ///
  /// Typically a [Text] widget.
  final Widget title;

  /// Additional content displayed below the [title].
  ///
  /// Typically a [Text] widget.
  final Widget? subtitle;

  /// Eager children shown below the header when the tile is expanded.
  ///
  /// Mutually exclusive with [itemBuilder]. Typically [ListTile] widgets.
  final List<Widget> children;

  /// Builder for lazy children (used with [SliverExpansionTile.builder]).
  ///
  /// Called on demand for items that are visible or within the cache extent.
  final IndexedWidgetBuilder? itemBuilder;

  /// Item count for [itemBuilder].
  final int? itemCount;

  /// An optional controller to expand or collapse the tile programmatically.
  ///
  /// If null, an internal controller is created automatically. It can be
  /// retrieved from a descendant widget via [SliverExpansibleController.of].
  ///
  /// The [SliverExpansibleController.expand] and
  /// [SliverExpansibleController.collapse] methods cause the tile to rebuild,
  /// so they may not be called from a build method.
  final SliverExpansibleController? controller;

  /// Specifies if the tile is initially expanded (true) or collapsed (false).
  ///
  /// Alternatively, a provided [controller] can be used to initially expand
  /// the tile if [SliverExpansibleController.expand] is called before this
  /// widget is built.
  ///
  /// Defaults to false.
  final bool initiallyExpanded;

  /// Specifies whether the state of the children is maintained when the tile
  /// expands and collapses.
  ///
  /// When true, the children are kept in the tree while the tile is collapsed.
  /// When false (default), the children are removed from the tree when the
  /// tile is collapsed and recreated upon expansion.
  final bool maintainState;

  /// Whether the header sticks to the top of the viewport when scrolled past.
  ///
  /// Defaults to false.
  final bool pinned;

  /// Defines the animation style for the expand/collapse animation.
  ///
  /// By default, the animation uses a duration of 150 milliseconds with
  /// [Curves.easeInOut]. To customize, provide an [AnimationStyle] with the
  /// desired [AnimationStyle.duration] and [AnimationStyle.curve].
  ///
  /// To disable the animation entirely, use [AnimationStyle.noAnimation].
  ///
  /// If null, [ExpansionTileThemeData.expansionAnimationStyle] is used.
  final AnimationStyle? expansionAnimationStyle;

  /// A widget to display before the [title].
  ///
  /// Typically a [CircleAvatar] widget.
  ///
  /// Depending on the value of [controlAffinity], the [leading] widget may
  /// replace the rotating expansion arrow icon.
  final Widget? leading;

  /// A widget to display after the [title].
  ///
  /// Depending on the value of [controlAffinity], the [trailing] widget may
  /// replace the rotating expansion arrow icon.
  final Widget? trailing;

  /// Defines insets for the header [ListTile]'s content.
  ///
  /// Analogous to [ListTile.contentPadding], this property defines the insets
  /// for the [leading], [title], [subtitle] and [trailing] widgets. It does
  /// not inset the expanded children widgets.
  ///
  /// If this property is null then [ExpansionTileThemeData.tilePadding] is
  /// used.
  final EdgeInsetsGeometry? tilePadding;

  /// The alignment of the expanded children within the available space.
  ///
  /// If null, defaults to [ExpansionTileThemeData.expandedAlignment], and then
  /// to [Alignment.center].
  ///
  /// This property only affects the expanded body when using the default
  /// constructor with [children]. It is ignored by
  /// [SliverExpansionTile.builder], since lazy children are built as slivers.
  final AlignmentGeometry? expandedAlignment;

  /// The cross-axis alignment of the expanded children.
  ///
  /// If null, defaults to [CrossAxisAlignment.center].
  ///
  /// This property only affects the expanded body when using the default
  /// constructor with [children]. It is ignored by
  /// [SliverExpansionTile.builder], since lazy children are built as slivers.
  final CrossAxisAlignment? expandedCrossAxisAlignment;

  /// Typically used to force the expansion arrow icon to the tile's leading or
  /// trailing edge.
  ///
  /// By default, the expansion arrow icon appears on the trailing edge.
  final ListTileControlAffinity? controlAffinity;

  /// The color to display behind the header when the tile is expanded.
  ///
  /// Animates between [collapsedBackgroundColor] and this value during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.backgroundColor] is used. If that is
  /// also null, [Colors.transparent] is used.
  final Color? backgroundColor;

  /// The color to display behind the header when the tile is collapsed.
  ///
  /// Animates between this value and [backgroundColor] during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.collapsedBackgroundColor] is used.
  /// If that is also null, [Colors.transparent] is used.
  final Color? collapsedBackgroundColor;

  /// The background color of the header when it is pinned and the body is
  /// scrolled underneath it.
  ///
  /// This property is unique to [SliverExpansionTile] and has no equivalent in
  /// [ExpansionTile]. It overrides [backgroundColor] when the pinned header
  /// overlaps scrolled content.
  ///
  /// If null, [backgroundColor] (the current animated value) is used.
  final Color? pinnedHeaderColor;

  /// The color of the tile's title and subtitle when the tile is expanded.
  ///
  /// Animates between [collapsedTextColor] and this value during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.textColor] is used. If that is also
  /// null, defaults to [ColorScheme.primary] (Material 2) or
  /// [ColorScheme.onSurface] (Material 3).
  final Color? textColor;

  /// The color of the tile's title and subtitle when the tile is collapsed.
  ///
  /// Animates between this value and [textColor] during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.collapsedTextColor] is used. If that is
  /// also null, defaults to [TextTheme.titleMedium] color (Material 2) or
  /// [ColorScheme.onSurface] (Material 3).
  final Color? collapsedTextColor;

  /// The color of the icon shown in the header when the tile is expanded.
  ///
  /// Animates between [collapsedIconColor] and this value during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.iconColor] is used. If that is also
  /// null, defaults to [ColorScheme.primary] in both Material 2 and 3.
  final Color? iconColor;

  /// The color of the icon shown in the header when the tile is collapsed.
  ///
  /// Animates between this value and [iconColor] during the
  /// expand/collapse transition.
  ///
  /// If null, [ExpansionTileThemeData.collapsedIconColor] is used. If that is
  /// also null, defaults to [ThemeData.unselectedWidgetColor] (Material 2) or
  /// [ColorScheme.onSurfaceVariant] (Material 3).
  final Color? collapsedIconColor;

  /// The tile's border shape when the sublist is expanded.
  ///
  /// If this property is null, the [ExpansionTileThemeData.shape] is used. If
  /// that is also null, a [Border] with vertical sides default to
  /// [ThemeData.dividerColor] is used.
  final ShapeBorder? shape;

  /// The tile's border shape when the sublist is collapsed.
  ///
  /// If this property is null, the [ExpansionTileThemeData.collapsedShape] is
  /// used. If that is also null, a [Border] with vertical sides default to
  /// [Colors.transparent] is used.
  final ShapeBorder? collapsedShape;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// If this is not null and a custom collapsed or expanded shape is provided,
  /// the value of [clipBehavior] will be used to clip the expansion tile.
  ///
  /// If this property is null, the [ExpansionTileThemeData.clipBehavior] is
  /// used. If that is also null, defaults to [Clip.antiAlias].
  final Clip? clipBehavior;

  /// Specifies padding for [children].
  ///
  /// When non-null, the children are wrapped in a [SliverPadding] with this
  /// value.
  ///
  /// If null, [ExpansionTileThemeData.childrenPadding] is used. If that is
  /// also null, no extra padding is applied.
  final EdgeInsetsGeometry? childrenPadding;

  /// Whether this expansion tile is intended to display three lines of text.
  ///
  /// Mirrors [ListTile.isThreeLine]. When true, [subtitle] must be non-null.
  final bool? isThreeLine;

  /// {@macro flutter.material.ListTile.dense}
  final bool? dense;

  /// The splash color of the ink response when the tile is tapped.
  ///
  /// Mirrors [ListTile.splashColor].
  final Color? splashColor;

  /// Defines how compact the expansion tile's layout will be.
  ///
  /// Mirrors [ListTile.visualDensity].
  final VisualDensity? visualDensity;

  /// {@macro flutter.material.ListTile.minTileHeight}
  final double? minTileHeight;

  /// {@macro flutter.material.ListTile.enableFeedback}
  final bool? enableFeedback;

  /// Whether the tile is interactive.
  ///
  /// When false, the header cannot be tapped and the tile will not expand or
  /// collapse. Even when disabled, the tile can still be toggled
  /// programmatically through a [SliverExpansibleController].
  ///
  /// Defaults to true.
  final bool enabled;

  /// Called whenever the tile expands or collapses.
  ///
  /// When the tile starts expanding, this function is called with the value
  /// `true`. When the tile starts collapsing, this function is called with
  /// the value `false`.
  ///
  /// Instead of providing this property, consider adding a listener to a
  /// provided [controller].
  final ValueChanged<bool>? onExpansionChanged;

  /// Whether to add button:true to the semantics if onTap is provided.
  ///
  /// Mirrors [ExpansionTile.internalAddSemanticForOnTap].
  final bool internalAddSemanticForOnTap;

  /// Specifies if the [SliverExpansionTile] should build a default trailing icon
  /// if [trailing] is null.
  final bool showTrailingIcon;

  @override
  State<SliverExpansionTile> createState() => _SliverExpansionTileState();
}

class _SliverExpansionTileState extends State<SliverExpansionTile> {
  static final Animatable<double> _easeInTween = CurveTween(
    curve: Curves.easeIn,
  );
  static final Animatable<double> _easeOutTween = CurveTween(
    curve: Curves.easeOut,
  );
  static final Animatable<double> _halfTween = Tween<double>(
    begin: 0.0,
    end: 0.5,
  );

  final ColorTween _headerColorTween = ColorTween();
  final ColorTween _iconColorTween = ColorTween();
  final ColorTween _backgroundColorTween = ColorTween();
  final ShapeBorderTween _borderTween = ShapeBorderTween();

  late Animation<double> _iconTurns;
  late Animation<Color?> _headerColor;
  late Animation<Color?> _iconColor;
  late Animation<Color?> _backgroundColor;
  late Animation<ShapeBorder?> _border;

  late ExpansionTileThemeData _expansionTileTheme;
  late SliverExpansibleController _tileController;
  double _headerExtent = 0.0;
  Timer? _timer;
  late Curve _curve;
  late Curve? _reverseCurve;
  late Duration _duration;

  SliverChildDelegate get _childrenDelegate {
    if (widget.itemBuilder != null) {
      return SliverChildBuilderDelegate(
        widget.itemBuilder!,
        childCount: widget.itemCount,
      );
    }
    return SliverChildListDelegate(widget.children);
  }

  // Platform or null affinity defaults to trailing.
  ListTileControlAffinity _effectiveAffinity(ListTileThemeData listTileTheme) {
    final ListTileControlAffinity affinity =
        widget.controlAffinity ??
        listTileTheme.controlAffinity ??
        ListTileControlAffinity.trailing;
    switch (affinity) {
      case ListTileControlAffinity.leading:
        return ListTileControlAffinity.leading;
      case ListTileControlAffinity.trailing:
      case ListTileControlAffinity.platform:
        return ListTileControlAffinity.trailing;
    }
  }

  Widget _buildIcon(BuildContext context, Animation<double> animation) {
    _iconTurns = animation.drive(_halfTween.chain(_easeInTween));
    return RotationTransition(
      turns: _iconTurns,
      child: const Icon(Icons.expand_more),
    );
  }

  Widget? _buildLeadingIcon(
    BuildContext context,
    Animation<double> animation,
    ListTileThemeData listTileTheme,
  ) {
    if (_effectiveAffinity(listTileTheme) != ListTileControlAffinity.leading) {
      return null;
    }
    return _buildIcon(context, animation);
  }

  Widget? _buildTrailingIcon(
    BuildContext context,
    Animation<double> animation,
    ListTileThemeData listTileTheme,
  ) {
    if (_effectiveAffinity(listTileTheme) != ListTileControlAffinity.trailing) {
      return null;
    }
    return _buildIcon(context, animation);
  }

  Widget _buildHeader(
    BuildContext context,
    Animation<double> animation,
    ThemeData theme,
    ListTileThemeData listTileTheme,
    bool isThreeLine,
    bool isDense,
    VisualDensity visualDensity,
  ) {
    _iconColor = animation.drive(_iconColorTween.chain(_easeInTween));
    _headerColor = animation.drive(_headerColorTween.chain(_easeInTween));
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String onTapHint = _tileController.isExpanded
        ? localizations.expansionTileExpandedTapHint
        : localizations.expansionTileCollapsedTapHint;
    final String semanticsHint = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        _tileController.isExpanded
            ? '${localizations.collapsedHint}\n ${localizations.expansionTileExpandedHint}'
            : '${localizations.expandedHint}\n ${localizations.expansionTileCollapsedHint}',
      _ =>
        _tileController.isExpanded
            ? localizations.collapsedHint
            : localizations.expandedHint,
    };

    final Widget child = ListTileTheme.merge(
      iconColor: _iconColor.value ?? _expansionTileTheme.iconColor,
      textColor: _headerColor.value,
      child: ListTile(
        enabled: widget.enabled,
        onTap: _tileController.isExpanded
            ? _tileController.collapse
            : _tileController.expand,
        isThreeLine: isThreeLine,
        dense: isDense,
        splashColor: widget.splashColor,
        visualDensity: visualDensity,
        enableFeedback: widget.enableFeedback,
        contentPadding: widget.tilePadding ?? _expansionTileTheme.tilePadding,
        leading:
            widget.leading ??
            _buildLeadingIcon(context, animation, listTileTheme),
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: widget.showTrailingIcon
            ? widget.trailing ??
                  _buildTrailingIcon(context, animation, listTileTheme)
            : null,
        minTileHeight: widget.minTileHeight,
        internalAddSemanticForOnTap: widget.internalAddSemanticForOnTap,
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      return Semantics(
        label: semanticsHint,
        liveRegion: true,
        child: Semantics(
          hint: semanticsHint,
          onTapHint: onTapHint,
          child: child,
        ),
      );
    }
    return Semantics(hint: semanticsHint, onTapHint: onTapHint, child: child);
  }

  Widget _buildSliverBody(BuildContext context, Animation<double> animation) {
    final body = SliverList(delegate: _childrenDelegate);
    final padding =
        widget.childrenPadding ?? _expansionTileTheme.childrenPadding;
    if (padding != null) {
      return SliverPadding(padding: padding, sliver: body);
    }
    return body;
  }

  // ExpansionTile-like box reveal for eager `children`.
  Widget _buildBody(BuildContext context, Animation<double> animation) {
    final CurvedAnimation heightFactor = CurvedAnimation(
      parent: animation,
      curve: _curve,
      reverseCurve: _reverseCurve,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ClipRect(
          child: Align(heightFactor: heightFactor.value, child: child),
        );
      },
      child: Align(
        alignment:
            widget.expandedAlignment ??
            _expansionTileTheme.expandedAlignment ??
            Alignment.center,
        child: Padding(
          padding:
              widget.childrenPadding ??
              _expansionTileTheme.childrenPadding ??
              EdgeInsets.zero,
          child: Column(
            crossAxisAlignment:
                widget.expandedCrossAxisAlignment ?? CrossAxisAlignment.center,
            children: widget.children,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _curve = Curves.easeIn;
    _duration = _kExpand;
    _tileController = widget.controller ?? SliverExpansibleController();
    if (widget.initiallyExpanded) {
      _tileController.expand();
    }
    _tileController.addListener(_onExpansionChanged);
  }

  @override
  void didChangeDependencies() {
    final ThemeData theme = Theme.of(context);
    _expansionTileTheme = ExpansionTileTheme.of(context);
    final ExpansionTileThemeData defaults = theme.useMaterial3
        ? _ExpansionTileDefaultsM3(context)
        : _ExpansionTileDefaultsM2(context);
    _updateAnimationDuration();
    _updateShapeBorder(theme);
    _updateHeaderColor(defaults);
    _updateIconColor(defaults);
    _updateBackgroundColor();
    _updateHeightFactorCurve();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant SliverExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ThemeData theme = Theme.of(context);
    _expansionTileTheme = ExpansionTileTheme.of(context);
    final ExpansionTileThemeData defaults = theme.useMaterial3
        ? _ExpansionTileDefaultsM3(context)
        : _ExpansionTileDefaultsM2(context);

    if (widget.collapsedShape != oldWidget.collapsedShape ||
        widget.shape != oldWidget.shape) {
      _updateShapeBorder(theme);
    }
    if (widget.collapsedTextColor != oldWidget.collapsedTextColor ||
        widget.textColor != oldWidget.textColor) {
      _updateHeaderColor(defaults);
    }
    if (widget.collapsedIconColor != oldWidget.collapsedIconColor ||
        widget.iconColor != oldWidget.iconColor) {
      _updateIconColor(defaults);
    }
    if (widget.backgroundColor != oldWidget.backgroundColor ||
        widget.collapsedBackgroundColor != oldWidget.collapsedBackgroundColor) {
      _updateBackgroundColor();
    }
    if (widget.expansionAnimationStyle != oldWidget.expansionAnimationStyle) {
      _updateAnimationDuration();
      _updateHeightFactorCurve();
    }
    if (widget.controller != oldWidget.controller) {
      _tileController.removeListener(_onExpansionChanged);
      if (oldWidget.controller == null) {
        _tileController.dispose();
      }

      _tileController = widget.controller ?? SliverExpansibleController();
      _tileController.addListener(_onExpansionChanged);
    }
  }

  @override
  void dispose() {
    _tileController.removeListener(_onExpansionChanged);
    if (widget.controller == null) {
      _tileController.dispose();
    }
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _onExpansionChanged() {
    final TextDirection textDirection = WidgetsLocalizations.of(
      context,
    ).textDirection;
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String stateHint = _tileController.isExpanded
        ? localizations.collapsedHint
        : localizations.expandedHint;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Workaround for VoiceOver interrupting semantic announcements on iOS.
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), () {
        SemanticsService.sendAnnouncement(
          View.of(context),
          stateHint,
          textDirection,
        );
        _timer?.cancel();
        _timer = null;
      });
    } else if (defaultTargetPlatform != TargetPlatform.android) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        stateHint,
        textDirection,
      );
    }
    widget.onExpansionChanged?.call(_tileController.isExpanded);
  }

  void _updateAnimationDuration() {
    _duration =
        widget.expansionAnimationStyle?.duration ??
        _expansionTileTheme.expansionAnimationStyle?.duration ??
        _kExpand;
  }

  void _updateHeaderColor(ExpansionTileThemeData defaults) {
    _headerColorTween
      ..begin =
          widget.collapsedTextColor ??
          _expansionTileTheme.collapsedTextColor ??
          defaults.collapsedTextColor
      ..end =
          widget.textColor ??
          _expansionTileTheme.textColor ??
          defaults.textColor;
  }

  void _updateIconColor(ExpansionTileThemeData defaults) {
    _iconColorTween
      ..begin =
          widget.collapsedIconColor ??
          _expansionTileTheme.collapsedIconColor ??
          defaults.collapsedIconColor
      ..end =
          widget.iconColor ??
          _expansionTileTheme.iconColor ??
          defaults.iconColor;
  }

  void _updateBackgroundColor() {
    _backgroundColorTween
      ..begin =
          widget.collapsedBackgroundColor ??
          _expansionTileTheme.collapsedBackgroundColor
      ..end = widget.backgroundColor ?? _expansionTileTheme.backgroundColor;
  }

  void _updateHeightFactorCurve() {
    _curve =
        widget.expansionAnimationStyle?.curve ??
        _expansionTileTheme.expansionAnimationStyle?.curve ??
        Curves.easeIn;
    _reverseCurve =
        widget.expansionAnimationStyle?.reverseCurve ??
        _expansionTileTheme.expansionAnimationStyle?.reverseCurve;
  }

  void _updateShapeBorder(ThemeData theme) {
    _borderTween
      ..begin =
          widget.collapsedShape ??
          _expansionTileTheme.collapsedShape ??
          const Border(
            top: BorderSide(color: Colors.transparent),
            bottom: BorderSide(color: Colors.transparent),
          )
      ..end =
          widget.shape ??
          _expansionTileTheme.shape ??
          Border(
            top: BorderSide(color: theme.dividerColor),
            bottom: BorderSide(color: theme.dividerColor),
          );
  }

  /// Returns whether the tile uses a dense layout.
  ///
  /// Mirrors the effective [ListTile.dense] resolution used by Flutter's
  /// [ListTile] implementation when [SliverExpansionTile.dense] is null:
  /// the widget property takes precedence, then the nearest [ListTileTheme],
  /// then [ThemeData.listTileTheme]. Defaults to false.
  bool _isDenseLayout(ThemeData theme, ListTileThemeData tileTheme) {
    return widget.dense ??
        tileTheme.dense ??
        theme.listTileTheme.dense ??
        false;
  }

  /// Returns the default tile height used by Flutter's [ListTile] when
  /// [ListTile.minTileHeight] is not specified.
  ///
  /// Mirrors the private `_defaultTileHeight` logic in Flutter's ListTile
  /// implementation. The result depends on whether the tile is dense, whether
  /// it is three-line, whether a subtitle is provided, and the current visual
  /// density adjustment.
  double _defaultTileHeight({
    required bool isDense,
    required bool isThreeLine,
    required Widget? subtitle,
    required VisualDensity visualDensity,
  }) {
    final Offset baseDensity = visualDensity.baseSizeAdjustment;
    return baseDensity.dy +
        switch ((isThreeLine, subtitle != null)) {
          (true, _) => isDense ? 76.0 : 88.0,
          (false, true) => isDense ? 64.0 : 72.0,
          (false, false) => isDense ? 48.0 : 56.0,
        };
  }

  double _effectiveHeaderExtent(ThemeData theme, ListTileThemeData tileTheme) {
    final VisualDensity effectiveVisualDensity =
        widget.visualDensity ??
        tileTheme.visualDensity ??
        theme.listTileTheme.visualDensity ??
        theme.visualDensity;

    final bool isDense = _isDenseLayout(theme, tileTheme);
    final bool isThreeLine =
        widget.isThreeLine ??
        tileTheme.isThreeLine ??
        theme.listTileTheme.isThreeLine ??
        false;

    assert(!isThreeLine || widget.subtitle != null);

    // Mirrors ListTile's internal default height selection logic when
    // minTileHeight is not specified.
    final double defaultHeight = _defaultTileHeight(
      isDense: isDense,
      isThreeLine: isThreeLine,
      subtitle: widget.subtitle,
      visualDensity: effectiveVisualDensity,
    );

    // Mirrors ListTile's minTileHeight resolution: widget, then theme, then
    // fallback to computed default height.
    return widget.minTileHeight ??
        tileTheme.minTileHeight ??
        theme.listTileTheme.minTileHeight ??
        defaultHeight;
  }

  Widget _buildSliverExpansible(
    BuildContext context,
    Widget header,
    Widget body,
    Animation<double> animation,
  ) {
    _backgroundColor = animation.drive(
      _backgroundColorTween.chain(_easeOutTween),
    );
    _border = animation.drive(_borderTween.chain(_easeOutTween));
    final Color backgroundColor =
        _backgroundColor.value ??
        _expansionTileTheme.backgroundColor ??
        Colors.transparent;
    final ShapeBorder expansionTileBorder =
        _border.value ??
        const Border(
          top: BorderSide(color: Colors.transparent),
          bottom: BorderSide(color: Colors.transparent),
        );
    final Clip clipBehavior =
        widget.clipBehavior ??
        _expansionTileTheme.clipBehavior ??
        Clip.antiAlias;

    final ShapeDecoration decoration = ShapeDecoration(
      color: backgroundColor,
      shape: expansionTileBorder,
    );

    final Widget tileSliver = SliverPadding(
      padding: decoration.padding,
      sliver: SliverMainAxisGroup(slivers: <Widget>[header, body]),
    );

    final bool isShapeProvided =
        widget.shape != null ||
        _expansionTileTheme.shape != null ||
        widget.collapsedShape != null ||
        _expansionTileTheme.collapsedShape != null;

    if (isShapeProvided) {
      return _SliverShapeDecoratedClipper(
        decoration: decoration,
        clipBehavior: clipBehavior,
        isPinned: widget.pinned,
        headerExtent: _headerExtent,
        configuration: createLocalImageConfiguration(context),
        sliver: tileSliver,
      );
    }

    return DecoratedSliver(decoration: decoration, sliver: tileSliver);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ListTileThemeData listTileTheme = ListTileTheme.of(context);
    _headerExtent = _effectiveHeaderExtent(theme, listTileTheme);

    return SliverExpansible(
      controller: _tileController,
      bodyRevealMode: widget.itemBuilder != null
          ? SliverExpansibleBodyRevealMode.sliverClipReveal
          : SliverExpansibleBodyRevealMode.builderControlled,
      animationStyle: AnimationStyle(
        duration: _duration,
        curve: _curve,
        reverseCurve: _reverseCurve,
      ),
      maintainState: widget.maintainState,

      sliverHeaderBuilder: (context, animation) {
        final bool isDense = _isDenseLayout(theme, listTileTheme);
        final VisualDensity effectiveVisualDensity =
            widget.visualDensity ??
            listTileTheme.visualDensity ??
            theme.listTileTheme.visualDensity ??
            theme.visualDensity;
        final bool isThreeLine =
            widget.isThreeLine ??
            listTileTheme.isThreeLine ??
            theme.listTileTheme.isThreeLine ??
            false;

        return SliverPersistentHeader(
          pinned: widget.pinned,
          delegate: _SliverExpansionTileHeaderDelegate(
            extent: _headerExtent,
            backgroundColor: Colors.transparent,
            pinnedHeaderColor: widget.pinnedHeaderColor,
            child: _buildHeader(
              context,
              animation,
              theme,
              listTileTheme,
              isThreeLine,
              isDense,
              effectiveVisualDensity,
            ),
          ),
        );
      },
      sliverBodyBuilder: (context, animation) {
        // Lazy sliver body for `.builder`.
        if (widget.itemBuilder != null) {
          return _buildSliverBody(context, animation);
        }

        return SliverToBoxAdapter(child: _buildBody(context, animation));
      },
      sliverExpansibleBuilder: _buildSliverExpansible,
    );
  }
}

class _SliverExpansionTileHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  const _SliverExpansionTileHeaderDelegate({
    required this.extent,
    required this.backgroundColor,
    required this.child,
    this.pinnedHeaderColor,
  });

  final double extent;
  final Color backgroundColor;
  final Color? pinnedHeaderColor;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isScrolledUnder = overlapsContent || shrinkOffset > 0;
    final Color effectiveBackground = isScrolledUnder
        ? (pinnedHeaderColor ?? backgroundColor)
        : backgroundColor;
    return ColoredBox(color: effectiveBackground, child: child);
  }

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  bool shouldRebuild(covariant _SliverExpansionTileHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.pinnedHeaderColor != pinnedHeaderColor ||
        oldDelegate.child != child;
  }
}

// Default theme values for Material 2.
class _ExpansionTileDefaultsM2 extends ExpansionTileThemeData {
  _ExpansionTileDefaultsM2(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colorScheme = _theme.colorScheme;

  @override
  Color? get textColor => _colorScheme.primary;

  @override
  Color? get iconColor => _colorScheme.primary;

  @override
  Color? get collapsedTextColor => _theme.textTheme.titleMedium!.color;

  @override
  Color? get collapsedIconColor => _theme.unselectedWidgetColor;
}

// Default theme values for Material 3.
class _ExpansionTileDefaultsM3 extends ExpansionTileThemeData {
  _ExpansionTileDefaultsM3(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;

  @override
  Color? get textColor => _colors.onSurface;

  @override
  Color? get iconColor => _colors.primary;

  @override
  Color? get collapsedTextColor => _colors.onSurface;

  @override
  Color? get collapsedIconColor => _colors.onSurfaceVariant;
}
