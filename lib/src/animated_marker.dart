import 'dart:async';

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
  })  : staticMarkersMap = {
          for (var marker in staticMarkers) marker.markerId: marker
        },
        animatedMarkersMap = {
          for (var marker in animatedMarkers) marker.markerId: marker
        };

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

class _AnimatedMarkerState extends State<AnimatedMarker> {
  late final StreamController<Set<Marker>> _markersStreamController;
  late final Map<MarkerId, Marker> _transitioningMarkers;

  late final double _animationSteps;
  late final Duration _animationInterval;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();

    // Set initial state for markers and animation configurations.
    _transitioningMarkers = widget.animatedMarkersMap;
    _animationSteps = widget.fps * widget.duration.inMilliseconds / 1000;
    _animationInterval = widget.duration / _animationSteps;
    _markersStreamController = StreamController<Set<Marker>>.broadcast();
  }

  @override
  void dispose() {
    // Close the stream to avoid memory leaks.
    _tickerTimer?.cancel();
    _markersStreamController.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tickerTimer
        ?.cancel(); // Cancel any active timer before starting a new one.

    final Map<MarkerId, Marker> sameAnimatedMarkers = {};
    final Map<Marker, Marker> updatedMarkerPairs = {};

    // Compare current markers with previous markers to find updated positions.
    for (final marker in widget.animatedMarkers) {
      final oldMarker = _transitioningMarkers[marker.markerId] ??
          oldWidget.animatedMarkersMap[marker.markerId];
      if (oldMarker != null && oldMarker != marker) {
        updatedMarkerPairs[oldMarker] = marker;
      } else {
        sameAnimatedMarkers[marker.markerId] = marker;
      }
    }

    // Combine static markers and unchanged animated markers.
    final Set<Marker> allStaticMarkers =
        widget.staticMarkers.followedBy(sameAnimatedMarkers.values).toSet();

    // If there are no marker changes, update the stream with static markers only.
    if (updatedMarkerPairs.isEmpty) {
      _markersStreamController.add(allStaticMarkers);
      return;
    }

    // Start a timer to interpolate marker positions over the specified duration.
    _tickerTimer = Timer.periodic(_animationInterval, (timer) {
      if (timer.tick >= _animationSteps) {
        // Animation complete: Update with final positions and cancel the timer.
        final allMarkers =
            allStaticMarkers.followedBy(_transitioningMarkers.values).toSet();
        _markersStreamController.add(allMarkers);
        timer.cancel();
        return;
      }
      final double fraction = (timer.tick / _animationSteps).clamp(0, 1);
      final curveFraction = widget.curve.transform(fraction);

      _transitioningMarkers.clear();

      // Calculate interpolated positions for each updated marker.
      for (final markerPair in updatedMarkerPairs.entries) {
        final oldMarker = markerPair.key;
        final newMarker = markerPair.value;

        final oldPosition = oldMarker.position;
        final newPosition = newMarker.position;

        // Interpolates position and angle based on the animation curve.
        final newLatLng = oldPosition.lerp(newPosition, step: curveFraction);
        final newRotation =
            oldMarker.rotation.lerp(newMarker.rotation, step: curveFraction);

        // Create a new marker at the interpolated position.
        final newMarkerCopy = newMarker.copyWith(
          positionParam: newLatLng,
          rotationParam: newRotation,
        );
        _transitioningMarkers[newMarkerCopy.markerId] = newMarkerCopy;
      }

      // Update the stream with the new marker positions.
      final allMarkers =
          allStaticMarkers.followedBy(_transitioningMarkers.values).toSet();
      _markersStreamController.add(allMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<Marker>>(
        stream: _markersStreamController.stream.distinct(),
        builder: (context, snapshot) {
          // Build GoogleMap with animated markers.
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData) {
            return widget.builder(
                context,
                widget.staticMarkers
                    .followedBy(_transitioningMarkers.values)
                    .toSet());
          }

          final allMarkers = snapshot.data!;
          return widget.builder(context, allMarkers);
        });
  }
}
