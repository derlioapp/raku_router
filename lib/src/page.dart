import 'package:flutter/widgets.dart';

/// Signature for building the [Page] that presents a route's [child].
///
/// [key] is the stable key the stack uses to track this entry — it must be
/// forwarded to the returned page. [name] is the route's debug name.
typedef RakuPageBuilder = Page<Object?> Function(
  Widget child,
  LocalKey key,
  String name,
);

/// A UI-agnostic [Page] with a configurable transition.
///
/// Deliberately does **not** depend on Material or Cupertino, so the package
/// stays usable from any design system. Pick a transition from
/// [RakuTransitions] or supply your own [RouteTransitionsBuilder].
class RakuPage<T> extends Page<T> {
  /// Creates a page presenting [child] with the given transition and durations.
  const RakuPage({
    required this.child,
    this.transitionsBuilder = RakuTransitions.fade,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.reverseTransitionDuration = const Duration(milliseconds: 200),
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The screen content.
  final Widget child;

  /// How the page animates in and out.
  final RouteTransitionsBuilder transitionsBuilder;

  /// Forward transition duration.
  final Duration transitionDuration;

  /// Reverse (pop) transition duration.
  final Duration reverseTransitionDuration;

  @override
  Route<T> createRoute(BuildContext context) => _RakuPageRoute<T>(this);
}

class _RakuPageRoute<T> extends PageRoute<T> {
  _RakuPageRoute(RakuPage<T> page) : super(settings: page);

  RakuPage<T> get _page => settings as RakuPage<T>;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _page.transitionsBuilder(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// A small set of Material/Cupertino-free transition builders.
abstract final class RakuTransitions {
  /// No animation — the new page appears instantly.
  static Widget none(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;

  /// Cross-fade.
  static Widget fade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(opacity: animation, child: child);

  /// Horizontal slide-in from the trailing edge (iOS-like, but framework-free).
  static Widget slide(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

    final outgoing = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(secondaryAnimation);

    return SlideTransition(
      position: outgoing,
      child: SlideTransition(position: incoming, child: child),
    );
  }

  /// A short **rise-up** reveal: the entering page slides up [riseUpDistance]
  /// logical pixels into place on the [riseUpCurve]. Transform-only (no fade).
  ///
  /// Unlike [fade]/[slide], only **one** page is ever painted during the
  /// transition: the page entering on top rises, while any page leaving or being
  /// covered is hidden immediately. This avoids the "two pages briefly overlap"
  /// flash you get when the outgoing page shows through a transparent incoming
  /// one. Behind the rising page you see whatever hosts the navigator (e.g. a
  /// shell's background), never the previous page.
  static const double riseUpDistance = 12;

  /// The easing for [riseUp] — an emphasized decelerate (`cubic-bezier(.2,0,0,1)`).
  static const Curve riseUpCurve = Cubic(0.2, 0, 0, 1);

  /// The rise-up transition builder; see [riseUpDistance] and [riseUpCurve].
  static Widget riseUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      builder: (BuildContext context, Widget? child) {
        // Hide the page that's leaving (popping) or being covered, so two pages
        // never paint at once.
        final bool leaving = animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed ||
            secondaryAnimation.value > 0;
        if (leaving) return const SizedBox.shrink();
        final double t = riseUpCurve.transform(animation.value);
        return Transform.translate(
          offset: Offset(0, (1 - t) * riseUpDistance),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Material 3 emphasized-decelerate easing — for elements *entering* the
  /// screen (`cubic-bezier(0.05, 0.7, 0.1, 1.0)`).
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 emphasized-accelerate easing — for elements *leaving* the
  /// screen (`cubic-bezier(0.3, 0.0, 0.8, 0.15)`).
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Recommended forward duration for [slideIn].
  static const Duration slideInDuration = Duration(milliseconds: 320);

  /// Recommended reverse (pop) duration for [slideIn].
  static const Duration slideInReverseDuration = Duration(milliseconds: 280);

  /// A premium, direction-parametric page slide.
  ///
  /// Synthesised from platform best practices: the incoming page slides in from
  /// [from] on Material 3 emphasized-decelerate easing and fades through, while
  /// the outgoing page recedes a [parallax] fraction in the travel direction
  /// (iOS-style depth) under a subtle [dim] scrim. The reverse is symmetric.
  ///
  /// Pair it with [slideInDuration] / [slideInReverseDuration] for the intended
  /// feel; set [fade] or [dim] to `false` for a plainer slide.
  static RouteTransitionsBuilder slideIn({
    SlideFrom from = SlideFrom.right,
    double parallax = 0.25,
    bool fade = true,
    bool dim = true,
  }) {
    return (context, animation, secondaryAnimation, child) => _PremiumSlide(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          from: from,
          parallax: parallax,
          fade: fade,
          dim: dim,
          child: child,
        );
  }

  static Offset _slideBegin(SlideFrom from) => switch (from) {
        SlideFrom.left => const Offset(-1, 0),
        SlideFrom.right => const Offset(1, 0),
        SlideFrom.top => const Offset(0, -1),
        SlideFrom.bottom => const Offset(0, 1),
      };
}

/// The widget behind [RakuTransitions.slideIn]. Owns its [CurvedAnimation]s
/// so they are created once and disposed (like the framework's own page
/// transitions), instead of being re-created on every transition rebuild.
class _PremiumSlide extends StatefulWidget {
  const _PremiumSlide({
    required this.animation,
    required this.secondaryAnimation,
    required this.from,
    required this.parallax,
    required this.fade,
    required this.dim,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final SlideFrom from;
  final double parallax;
  final bool fade;
  final bool dim;
  final Widget child;

  @override
  State<_PremiumSlide> createState() => _PremiumSlideState();
}

class _PremiumSlideState extends State<_PremiumSlide> {
  late CurvedAnimation _enter;
  late CurvedAnimation _exit;
  late CurvedAnimation _fadeIn;

  @override
  void initState() {
    super.initState();
    _createCurves();
  }

  void _createCurves() {
    _enter = CurvedAnimation(
      parent: widget.animation,
      curve: RakuTransitions.emphasizedDecelerate,
      reverseCurve: RakuTransitions.emphasizedAccelerate,
    );
    _exit = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: RakuTransitions.emphasizedAccelerate,
      reverseCurve: RakuTransitions.emphasizedDecelerate,
    );
    _fadeIn = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0, 0.6),
    );
  }

  void _disposeCurves() {
    _enter.dispose();
    _exit.dispose();
    _fadeIn.dispose();
  }

  @override
  void didUpdateWidget(_PremiumSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _disposeCurves();
      _createCurves();
    }
  }

  @override
  void dispose() {
    _disposeCurves();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enterBegin = RakuTransitions._slideBegin(widget.from);
    var content = widget.child;
    if (widget.fade) {
      content = FadeTransition(opacity: _fadeIn, child: content);
    }
    content = SlideTransition(
      position:
          Tween<Offset>(begin: enterBegin, end: Offset.zero).animate(_enter),
      child: content,
    );
    if (widget.dim) {
      content = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 0.08).animate(_exit),
                child: const ColoredBox(color: Color(0xFF000000)),
              ),
            ),
          ),
        ],
      );
    }
    return SlideTransition(
      position:
          Tween<Offset>(begin: Offset.zero, end: enterBegin * -widget.parallax)
              .animate(_exit),
      child: content,
    );
  }
}

/// The edge a page enters from for [RakuTransitions.slideIn].
enum SlideFrom {
  /// Enter from the left edge.
  left,

  /// Enter from the right edge — the usual forward push.
  right,

  /// Enter from the top edge.
  top,

  /// Enter from the bottom edge — sheet-like.
  bottom,
}
