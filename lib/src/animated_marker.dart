import 'dart:async';
import 'dart:math' as math;

import 'package:animated_marker/src/extensions.dart';
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
  late final Map<MarkerId, Marker> _transitioningMarkers;

  int _animationSteps = 1;
  Duration _animationInterval = const Duration(milliseconds: 16);
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();

    // Set initial state for markers and animation configurations.
    _transitioningMarkers = Map<MarkerId, Marker>.from(
      widget.animatedMarkersMap,
    );
    _refreshAnimationConfig();
    _markersStreamController = StreamController<Set<Marker>>.broadcast();

    // Add initial markers to the stream.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _markersStreamController.isClosed) {
        return;
      }
      final initialMarkers =
          widget.staticMarkers.followedBy(_transitioningMarkers.values).toSet();
      _emitMarkers(initialMarkers);
    });
  }

  @override
  void dispose() {
    // Close the stream to avoid memory leaks.
    _tickerTimer?.cancel();
    _markersStreamController.close();
    super.dispose();
  }

  void _emitMarkers(Set<Marker> markers) {
    if (!_markersStreamController.isClosed) {
      _markersStreamController.add(markers);
    }
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

  @override
  void didUpdateWidget(covariant AnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tickerTimer
        ?.cancel(); // Cancel any active timer before starting a new one.
    _refreshAnimationConfig();

    // This reflects the latest rendered state, including in-flight animations.
    final Map<MarkerId, Marker> lastDisplayedMarkers = Map.from(
      _transitioningMarkers,
    );

    // Clear _transitioningMarkers to repopulate it according to the new logic.
    // This ensures that only relevant markers are kept at their correct positions.
    _transitioningMarkers.clear();

    final Map<MarkerId, _MarkerTransition> markersToAnimatePosition = {};

    // Iterate over the new animated markers to identify updates or new additions.
    for (final newMarker in widget.animatedMarkers) {
      final currentDisplayedMarker = lastDisplayedMarkers[newMarker.markerId];
      if (currentDisplayedMarker == null) {
        // This is a completely new marker. Add it directly to _transitioningMarkers at its final position.
        _transitioningMarkers[newMarker.markerId] = newMarker;
      } else {
        // Compare against what is currently shown on screen (not just the
        // previous widget target), so re-builds during animation don't snap.
        if (currentDisplayedMarker.position != newMarker.position ||
            currentDisplayedMarker.rotation != newMarker.rotation) {
          // Use the last displayed frame when available so interrupted
          // animations continue smoothly from where they currently are.
          markersToAnimatePosition[newMarker.markerId] = _MarkerTransition(
            from: currentDisplayedMarker,
            to: newMarker,
          );
          _transitioningMarkers[newMarker.markerId] = currentDisplayedMarker;
        } else {
          // The marker exists and its position/rotation has not changed.
          // Add it to _transitioningMarkers with its current data.
          _transitioningMarkers[newMarker.markerId] = newMarker;
        }
      }
    }

    // --- Handling of removed markers ---
    // The logic for removing markers is implicitly handled by `_transitioningMarkers.clear()`
    // and subsequent repopulation. Any marker not present in `widget.animatedMarkers`
    // will not be added back to `_transitioningMarkers`, thus effectively removing it.
    // At this point, `_transitioningMarkers` correctly holds either:
    // - The old positions for markers currently animating.
    // - The new positions for newly added or unchanged markers.

    // Combine static markers and active animated markers for the initial stream update.
    final Set<Marker> currentDisplayMarkers =
        widget.staticMarkers.followedBy(_transitioningMarkers.values).toSet();

    // If there are no markers whose position needs to be animated, update the stream once and return.
    if (markersToAnimatePosition.isEmpty) {
      _emitMarkers(currentDisplayMarkers);
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
        // Ensure _transitioningMarkers contains the final positions for ALL animated markers.
        for (final entry in markersToAnimatePosition.entries) {
          _transitioningMarkers[entry.key] =
              entry.value.to; // Store the final state (new position)
        }

        final allFinalMarkers =
            widget.staticMarkers
                .followedBy(_transitioningMarkers.values)
                .toSet();
        _emitMarkers(allFinalMarkers);
        timer.cancel();
        return;
      }

      final double fraction =
          (timer.tick / _animationSteps).clamp(0.0, 1.0).toDouble();
      final curveFraction = widget.curve.transform(fraction);

      // Create a temporary map for markers in this animation frame.
      // Start with the current state of _transitioningMarkers, which includes non-interpolating markers.
      final Map<MarkerId, Marker> markersForThisFrame = Map.from(
        _transitioningMarkers,
      );

      // Calculate interpolated positions for markers in `markersToAnimatePosition` and update them in `markersForThisFrame`.
      for (final markerPair in markersToAnimatePosition.entries) {
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
        markersForThisFrame[newMarkerCopy.markerId] = newMarkerCopy;
      }

      _transitioningMarkers
        ..clear()
        ..addAll(markersForThisFrame);

      // Update the stream with the new set of markers for this frame.
      final allMarkersForThisFrame =
          widget.staticMarkers.followedBy(markersForThisFrame.values).toSet();
      _emitMarkers(allMarkersForThisFrame);
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
          return widget.builder(
            context,
            widget.staticMarkers
                .followedBy(_transitioningMarkers.values)
                .toSet(),
          );
        }

        final allMarkers = snapshot.data!;
        return widget.builder(context, allMarkers);
      },
    );
  }
}
