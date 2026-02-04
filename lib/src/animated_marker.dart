import 'dart:async';
import 'dart:math' as math;

import 'package:animated_marker/src/extensions.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A widget that animates a set of [Marker]s on a [GoogleMap].
///
/// This widget takes a set of animated markers and interpolates their positions
/// from old to new locations automatically over a given duration and frame rate.
///
/// Supply a [GoogleMap] in the [builder] function and pass the animated markers
/// from the stream for seamless integration with your map.
///
/// Markers that do not change positions can be provided as static markers,
/// which are not animated for efficiency.
class AnimatedMarker extends StatefulWidget {
  /// Creates an [AnimatedMarkers] widget.
  ///
  /// [animatedMarkers] contains the set of [Marker]s to animate.
  /// [staticMarkers] are markers that do not require animation.
  /// The [builder] function provides the [GoogleMap] with updated markers.
  /// [duration] sets the animation duration.
  /// [curve] defines the interpolation curve.
  /// [fps] controls the frames per second for marker updates.
  /// [viewportAnimationBounds], when provided, skips interpolation for marker
  /// updates fully outside those bounds.
  /// [viewportAnimationBoundsListenable] provides dynamic bounds updates
  /// without requiring parent widget rebuilds for every camera movement.
  AnimatedMarker({
    super.key,

    /// The set of [Marker]s that will be animated based on position changes.
    required this.animatedMarkers,

    /// The set of [Marker]s that will remain static, improving performance.
    this.staticMarkers = const {},

    /// The builder function where the [GoogleMap] widget is provided
    /// with the [animatedMarkers] to render.
    required this.builder,

    /// The duration over which the marker animation occurs.
    this.duration = const Duration(seconds: 1),

    /// The curve used for animating marker transitions.
    this.curve = Curves.ease,

    /// The frames per second (FPS) rate for updating animated markers.
    this.fps = 30,

    /// Optional viewport bounds to guard interpolation.
    this.viewportAnimationBounds,

    /// Optional dynamic viewport bounds source for guard interpolation.
    this.viewportAnimationBoundsListenable,
  }) : staticMarkersMap = {
         for (var marker in staticMarkers) marker.markerId: marker,
       },
       animatedMarkersMap = {
         for (var marker in animatedMarkers) marker.markerId: marker,
       },
       assert(fps > 0, 'fps must be greater than 0'),
       assert(duration > Duration.zero, 'duration must be greater than zero');

  /// The set of animated markers passed for interpolation.
  final Set<Marker> animatedMarkers;

  /// The set of static markers which do not need animation.
  final Set<Marker> staticMarkers;

  /// The builder function where the map widget is built.
  final Widget Function(BuildContext context, Set<Marker> animatedMarkers)
  builder;

  /// The duration for the animation.
  final Duration duration;

  /// The curve that controls the animation's progress.
  final Curve curve;

  /// The frames per second (FPS) for the animation.
  final int fps;

  /// Optional bounds used to guard interpolation.
  ///
  /// If null, all changed animated markers are interpolated.
  /// If non-null, interpolation runs only for markers where either the current
  /// or target position is inside these bounds.
  final LatLngBounds? viewportAnimationBounds;

  /// Optional dynamic viewport bounds source.
  ///
  /// If provided, this takes precedence over [viewportAnimationBounds] and is
  /// listened to at runtime without needing parent rebuilds.
  final ValueListenable<LatLngBounds?>? viewportAnimationBoundsListenable;

  /// Internal map for fast lookup of static markers by [MarkerId].
  final Map<MarkerId, Marker> staticMarkersMap;

  /// Internal map for fast lookup of animated markers by [MarkerId].
  final Map<MarkerId, Marker> animatedMarkersMap;

  @override
  State<AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _MarkerTransition {
  const _MarkerTransition({required this.from, required this.to});

  final Marker from;
  final Marker to;
}

class _AnimatedMarkerState extends State<AnimatedMarker> {
  late final StreamController<Set<Marker>> _markersStreamController;
  late final Map<MarkerId, Marker> _staticMarkers;
  late final Map<MarkerId, Marker> _stableAnimatedMarkers;
  late final Map<MarkerId, Marker> _activeAnimatedMarkers;
  final Map<MarkerId, _MarkerTransition> _activeTransitions = {};

  int _animationSteps = 1;
  Duration _animationInterval = const Duration(milliseconds: 16);
  Timer? _tickerTimer;
  LatLngBounds? _latestViewportAnimationBounds;

  @override
  void initState() {
    super.initState();

    // Set initial state for marker buckets and animation configurations.
    _staticMarkers = Map<MarkerId, Marker>.from(widget.staticMarkersMap);
    _stableAnimatedMarkers = Map<MarkerId, Marker>.from(
      widget.animatedMarkersMap,
    );
    _activeAnimatedMarkers = <MarkerId, Marker>{};
    _refreshAnimationConfig();
    _attachViewportBoundsListener(widget.viewportAnimationBoundsListenable);
    _refreshViewportAnimationBounds();
    _markersStreamController = StreamController<Set<Marker>>.broadcast();

    // Add initial markers to the stream.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _markersStreamController.isClosed) {
        return;
      }
      _emitCurrentMarkers();
    });
  }

  @override
  void dispose() {
    // Close the stream to avoid memory leaks.
    _tickerTimer?.cancel();
    _detachViewportBoundsListener(widget.viewportAnimationBoundsListenable);
    _markersStreamController.close();
    super.dispose();
  }

  void _emitMarkers(Set<Marker> markers) {
    if (!_markersStreamController.isClosed) {
      _markersStreamController.add(markers);
    }
  }

  Set<Marker> _composeCurrentMarkers() {
    return <Marker>{
      ..._staticMarkers.values,
      ..._stableAnimatedMarkers.values,
      ..._activeAnimatedMarkers.values,
    };
  }

  void _emitCurrentMarkers() {
    _emitMarkers(_composeCurrentMarkers());
  }

  void _refreshAnimationConfig() {
    _animationSteps = math.max(
      1,
      (widget.fps * widget.duration.inMilliseconds / 1000).round(),
    );
    _animationInterval = Duration(
      microseconds: math.max(
        1,
        (widget.duration.inMicroseconds / _animationSteps).round(),
      ),
    );
  }

  void _onViewportBoundsChanged() {
    _refreshViewportAnimationBounds();
  }

  void _refreshViewportAnimationBounds() {
    _latestViewportAnimationBounds =
        widget.viewportAnimationBoundsListenable?.value ??
        widget.viewportAnimationBounds;
  }

  void _attachViewportBoundsListener(
    ValueListenable<LatLngBounds?>? listenable,
  ) {
    listenable?.addListener(_onViewportBoundsChanged);
  }

  void _detachViewportBoundsListener(
    ValueListenable<LatLngBounds?>? listenable,
  ) {
    listenable?.removeListener(_onViewportBoundsChanged);
  }

  bool _isInsideBounds(LatLng point, LatLngBounds bounds) {
    final sw = bounds.southwest;
    final ne = bounds.northeast;
    final isLatitudeInRange =
        point.latitude >= sw.latitude && point.latitude <= ne.latitude;
    final isLongitudeInRange =
        sw.longitude <= ne.longitude
            ? (point.longitude >= sw.longitude &&
                point.longitude <= ne.longitude)
            : (point.longitude >= sw.longitude ||
                point.longitude <= ne.longitude);
    return isLatitudeInRange && isLongitudeInRange;
  }

  bool _shouldAnimateMarker(Marker current, Marker target) {
    final bounds = _latestViewportAnimationBounds;
    if (bounds == null) {
      return true;
    }
    return _isInsideBounds(current.position, bounds) ||
        _isInsideBounds(target.position, bounds);
  }

  @override
  void didUpdateWidget(covariant AnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportAnimationBoundsListenable !=
        widget.viewportAnimationBoundsListenable) {
      _detachViewportBoundsListener(
        oldWidget.viewportAnimationBoundsListenable,
      );
      _attachViewportBoundsListener(widget.viewportAnimationBoundsListenable);
    }
    _refreshViewportAnimationBounds();
    _tickerTimer
        ?.cancel(); // Cancel any active timer before starting a new one.
    _refreshAnimationConfig();
    _staticMarkers
      ..clear()
      ..addAll(widget.staticMarkersMap);

    // This reflects the latest rendered state, including in-flight animations.
    final Map<MarkerId, Marker> lastDisplayedMarkers = Map<MarkerId, Marker>.of(
      _stableAnimatedMarkers,
    )..addAll(_activeAnimatedMarkers);

    // Rebuild stable/active buckets from the latest widget input.
    _stableAnimatedMarkers.clear();
    _activeAnimatedMarkers.clear();
    _activeTransitions.clear();

    // Iterate over the new animated markers to identify updates or new additions.
    for (final newMarker in widget.animatedMarkers) {
      final currentDisplayedMarker = lastDisplayedMarkers[newMarker.markerId];
      if (currentDisplayedMarker == null) {
        // New animated marker: no interpolation needed this frame.
        _stableAnimatedMarkers[newMarker.markerId] = newMarker;
      } else {
        // Compare against what is currently shown on screen (not just the
        // previous widget target), so re-builds during animation don't snap.
        if (currentDisplayedMarker.position != newMarker.position ||
            currentDisplayedMarker.rotation != newMarker.rotation) {
          if (_shouldAnimateMarker(currentDisplayedMarker, newMarker)) {
            _activeTransitions[newMarker.markerId] = _MarkerTransition(
              from: currentDisplayedMarker,
              to: newMarker,
            );
            _activeAnimatedMarkers[newMarker.markerId] = currentDisplayedMarker;
          } else {
            _stableAnimatedMarkers[newMarker.markerId] = newMarker;
          }
        } else {
          // Unchanged animated marker remains stable and skips interpolation.
          _stableAnimatedMarkers[newMarker.markerId] = newMarker;
        }
      }
    }

    // Removed animated markers are implicitly dropped by bucket rebuild above.
    _emitCurrentMarkers();

    // If there are no markers whose position needs to be animated, update the stream once and return.
    if (_activeTransitions.isEmpty) {
      return;
    }

    // Start a timer to interpolate marker positions over the specified duration.
    _tickerTimer = Timer.periodic(_animationInterval, (timer) {
      if (!mounted || _markersStreamController.isClosed) {
        timer.cancel();
        return;
      }

      if (timer.tick >= _animationSteps) {
        // Animation complete: Update with final positions and cancel the timer.
        for (final entry in _activeTransitions.entries) {
          _stableAnimatedMarkers[entry.key] =
              entry.value.to; // Store the final state (new position)
        }
        _activeTransitions.clear();
        _activeAnimatedMarkers.clear();
        _emitCurrentMarkers();
        timer.cancel();
        return;
      }

      final double fraction =
          (timer.tick / _animationSteps).clamp(0.0, 1.0).toDouble();
      final curveFraction = widget.curve.transform(fraction);

      // Update only markers currently transitioning.
      for (final markerPair in _activeTransitions.entries) {
        final oldMarker = markerPair.value.from;
        final newMarker = markerPair.value.to;

        final oldPosition = oldMarker.position;
        final newPosition = newMarker.position;

        // Interpolates position and angle based on the animation curve.
        final newLatLng = oldPosition.lerp(newPosition, step: curveFraction);
        final newRotation = oldMarker.rotation.lerp(
          newMarker.rotation,
          step: curveFraction,
        );

        // Create a new marker at the interpolated position.
        final newMarkerCopy = newMarker.copyWith(
          positionParam: newLatLng,
          rotationParam: newRotation,
        );
        _activeAnimatedMarkers[newMarkerCopy.markerId] = newMarkerCopy;
      }
      _emitCurrentMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<Marker>>(
      stream: _markersStreamController.stream,
      builder: (context, snapshot) {
        // Build GoogleMap with animated markers.
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData) {
          return widget.builder(context, _composeCurrentMarkers());
        }

        final allMarkers = snapshot.data!;
        return widget.builder(context, allMarkers);
      },
    );
  }
}
