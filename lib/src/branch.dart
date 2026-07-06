import 'package:flutter/widgets.dart';

import 'page.dart';
import 'route.dart';
import 'stack.dart';
import 'stack_view.dart';

/// One branch of a [BranchedRouteStack] — e.g. a single bottom-navigation tab.
///
/// Each branch owns an independent [RouteStack], so switching branches
/// preserves each one's back history (the "persistent tab stack" behaviour you
/// get from `StatefulShellRoute`, but built in).
class RouteBranch {
  /// Creates a branch whose stack starts at [initial].
  RouteBranch({required this.id, required RakuRoute initial})
      : stack = RouteStack(initial);

  /// Creates a branch around an existing [stack].
  RouteBranch.withStack({required this.id, required this.stack});

  /// Stable identifier for this branch.
  final String id;

  /// This branch's independent navigation stack.
  final RouteStack stack;
}

/// Coordinates several [RouteBranch]es and tracks the active one.
///
/// Notifies listeners when the active index changes *or* when any branch's
/// stack changes, so a single listener can drive the whole shell.
class BranchedRouteStack extends ChangeNotifier {
  /// Creates a controller over [branches], starting on [initialIndex].
  BranchedRouteStack({
    required List<RouteBranch> branches,
    int initialIndex = 0,
  })  : assert(
          branches.isNotEmpty,
          'Raku: BranchedRouteStack needs at least one branch.',
        ),
        assert(
          initialIndex >= 0 && initialIndex < branches.length,
          'Raku: initialIndex $initialIndex is out of range for '
          '${branches.length} branch(es).',
        ),
        _branches = branches,
        _index = initialIndex {
    for (final branch in _branches) {
      branch.stack.addListener(notifyListeners);
    }
  }

  final List<RouteBranch> _branches;
  int _index;

  /// All branches, in order.
  List<RouteBranch> get branches => List<RouteBranch>.unmodifiable(_branches);

  /// Index of the active branch.
  int get index => _index;

  /// The active branch.
  RouteBranch get activeBranch => _branches[_index];

  /// The active branch's stack.
  RouteStack get activeStack => _branches[_index].stack;

  /// Switches the active branch.
  set index(int value) {
    assert(
      value >= 0 && value < _branches.length,
      'Raku: branch index $value is out of range for '
      '${_branches.length} branch(es).',
    );
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }

  /// Switches to the branch at [index] — a tear-off-friendly alias for the
  /// `index` setter (e.g. `onDestinationSelected: tabs.go`).
  void go(int index) => this.index = index;

  /// Returns the stack for the branch with [id].
  RouteStack stackOf(String id) =>
      _branches.firstWhere((b) => b.id == id).stack;

  @override
  void dispose() {
    for (final branch in _branches) {
      branch.stack.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

/// Renders a [BranchedRouteStack] as an [IndexedStack] of [RouteStackView]s.
///
/// Each branch keeps its own [Navigator] alive (so state and scroll positions
/// survive tab switches). Every branch handles the system back gesture for its
/// own stack via the [RouteStackView]'s built-in `NavigatorPopHandler`.
///
/// Branches are built **lazily**: a branch's view (and its `Navigator`) is
/// created the first time that tab is shown, not up front — so an app with many
/// tabs doesn't spin up every tab's stack at launch. Once built, a branch is
/// cached and kept alive, so its state survives later tab switches and it is
/// never rebuilt by navigation elsewhere.
///
/// Switching branches is an **instant** [IndexedStack] swap, not an animated
/// transition — deliberately, so each branch's `Navigator` (and its stack,
/// scroll, and state) is preserved. `transitionsBuilder` animates pushes
/// *within* a branch; to animate the tab switch itself, wrap the active [child]
/// in your shell builder with an `AnimatedSwitcher`.
class BranchedStackView extends StatefulWidget {
  /// Creates a view that renders [controller]'s active branch.
  const BranchedStackView({
    super.key,
    required this.controller,
    required this.builder,
    this.pageBuilder,
    this.observers,
    this.transitionsBuilder = RakuTransitions.fade,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.resolveTransition,
    this.handleSystemBack = true,
  });

  /// The branched controller to render.
  final BranchedRouteStack controller;

  /// Maps each route to its screen widget (shared across branches).
  final RakuWidgetBuilder builder;

  /// Optional custom default page factory.
  final RakuPageBuilder? pageBuilder;

  /// Builds the [NavigatorObserver]s for a branch's [Navigator]. Called **once
  /// per branch** (on that branch's first build), so every branch gets its own
  /// fresh observer instances — a single [NavigatorObserver] can only be
  /// attached to one [Navigator], so the same instance can't be shared across
  /// branches. Return the observers you want on each tab's navigator (e.g. a
  /// fresh `FirebaseAnalyticsObserver`).
  final List<NavigatorObserver> Function()? observers;

  /// Default transition for branches that don't use `RouteTransition`.
  final RouteTransitionsBuilder transitionsBuilder;

  /// Default forward/reverse transition duration for each branch.
  final Duration transitionDuration;

  /// Optional per-route transition lookup, forwarded to each branch's view.
  final RouteTransitionsBuilder? Function(RakuRoute route)? resolveTransition;

  /// Whether each branch handles the system back gesture itself. Set to `false`
  /// when an outer Router owns back handling (deep-link mode).
  final bool handleSystemBack;

  @override
  State<BranchedStackView> createState() => _BranchedStackViewState();
}

class _BranchedStackViewState extends State<BranchedStackView> {
  // One HeroController per branch: nested Navigators may not share a single
  // HeroController (the one an enclosing MaterialApp provides), so each branch
  // gets its own — heroes keep working within a tab. (Cheap; created up front.)
  late final List<HeroController> _heroControllers = <HeroController>[
    for (var i = 0; i < widget.controller.branches.length; i++)
      HeroController(),
  ];

  // A branch's view is built on first visit and cached here, so it is created
  // lazily, kept alive afterwards, and never rebuilt when only the index
  // changes (the cached instance lets Flutter skip its subtree).
  late final List<Widget?> _branchViews =
      List<Widget?>.filled(widget.controller.branches.length, null);

  @override
  void dispose() {
    for (final controller in _heroControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // The (cached) view for branch [i] — built the first time it is requested.
  Widget _branchAt(int i) {
    return _branchViews[i] ??= HeroControllerScope(
      controller: _heroControllers[i],
      child: RouteStackView(
        stack: widget.controller.branches[i].stack,
        builder: widget.builder,
        pageBuilder: widget.pageBuilder,
        observers: widget.observers?.call() ?? const <NavigatorObserver>[],
        transitionsBuilder: widget.transitionsBuilder,
        transitionDuration: widget.transitionDuration,
        resolveTransition: widget.resolveTransition,
        handleSystemBack: widget.handleSystemBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final active = widget.controller.index;
        return IndexedStack(
          index: active,
          children: <Widget>[
            for (var i = 0; i < widget.controller.branches.length; i++)
              // Build the active branch and any already-visited branch; the rest
              // stay a cheap placeholder until their tab is first shown.
              if (i == active || _branchViews[i] != null)
                _branchAt(i)
              else
                const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}
