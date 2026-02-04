import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:animated_marker/src/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Runtime animation quality profile.
enum AdaptiveProfile { low, medium, high }

/// Policy for marker animation behavior.
///
/// This centralizes viewport guarding, animation tuning, and optional adaptive
/// quality control.
@immutable
class AnimationPolicy {
  const AnimationPolicy({
    this.duration = const Duration(seconds: 1),
    this.curve = Curves.ease,
    this.maxFps = 30,
    this.viewportBounds,
    this.viewportBoundsListenable,
    this.adaptiveEnabled = false,
    this.profileOverride,
    this.minFps = 10,
    this.allowSnapOnLow = true,
    this.adaptationCooldown = const Duration(seconds: 2),
  }) : assert(maxFps > 0, 'maxFps must be greater than 0'),
       assert(minFps > 0, 'minFps must be greater than 0');

  /// Animation duration for marker interpolation.
  final Duration duration;

  /// Curve used for marker interpolation.
  final Curve curve;

  /// Maximum animation FPS (used for high profile).
  final int maxFps;

  /// Optional static viewport bounds used to guard interpolation.
  final LatLngBounds? viewportBounds;

  /// Optional dynamic viewport bounds source.
  ///
  /// If provided, this takes precedence over [viewportBounds].
  final ValueListenable<LatLngBounds?>? viewportBoundsListenable;

  /// Enables automatic runtime profile adaptation from frame health.
  final bool adaptiveEnabled;

  /// Optional hard override for profile selection.
  ///
  /// If provided, it takes precedence over adaptive logic.
  final AdaptiveProfile? profileOverride;

  /// Minimum FPS used for medium profile and low profile when snapping is off.
  final int minFps;

  /// In low profile, skip interpolation and snap markers directly to targets.
  final bool allowSnapOnLow;

  /// Minimum time before switching to another adaptive profile.
  final Duration adaptationCooldown;
}

/// A widget that animates a set of [Marker]s on a [GoogleMap].
class AnimatedMarker extends StatefulWidget {
  /// Creates an [AnimatedMarker] widget.
  AnimatedMarker({
    super.key,
    required this.animatedMarkers,
    this.staticMarkers = const {},
    required this.builder,
    this.animationPolicy = const AnimationPolicy(),
  }) : assert(
         animationPolicy.duration.compareTo(Duration.zero) > 0,
         'animationPolicy.duration must be greater than Duration.zero',
       ),
       assert(
         animationPolicy.adaptationCooldown.compareTo(Duration.zero) >= 0,
         'animationPolicy.adaptationCooldown must be non-negative',
       ),
       staticMarkersMap = {
         for (var marker in staticMarkers) marker.markerId: marker,
       },
       animatedMarkersMap = {
         for (var marker in animatedMarkers) marker.markerId: marker,
       };

  /// Markers that can be interpolated when changed.
  final Set<Marker> animatedMarkers;

  /// Markers that are always rendered as-is (never interpolated).
  final Set<Marker> staticMarkers;

  /// Builder that receives the effective markers for rendering.
  final Widget Function(BuildContext context, Set<Marker> markers) builder;

  /// Runtime animation behavior.
  final AnimationPolicy animationPolicy;

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
  static const int _kFrameHealthWindow = 60;
  static const int _kJankFrameThresholdUs = 16667;
  static const int _kMediumFrameTimeUs = 19000;
  static const int _kLowFrameTimeUs = 28000;
  static const double _kMediumJankRatio = 0.18;
  static const double _kLowJankRatio = 0.35;

  late final StreamController<Set<Marker>> _markersStreamController;
  late final Map<MarkerId, Marker> _staticMarkers;
  late final Map<MarkerId, Marker> _stableAnimatedMarkers;
  late final Map<MarkerId, Marker> _activeAnimatedMarkers;
  final Map<MarkerId, _MarkerTransition> _activeTransitions = {};

  late final TimingsCallback _timingsCallback;

  final Queue<int> _frameDurationsUs = Queue<int>();
  int _frameDurationSumUs = 0;
  int _jankFrameCount = 0;
  bool _isTimingsCallbackAttached = false;

  AdaptiveProfile _effectiveProfile = AdaptiveProfile.high;
  late int _effectiveFps;
  late Duration _effectiveDuration;
  late Curve _effectiveCurve;
  late Duration _animationInterval;
  LatLngBounds? _latestViewportBounds;
  DateTime _lastProfileChangeAt = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _tickerTimer;
  int _elapsedAnimationUs = 0;

  AnimationPolicy get _policy => widget.animationPolicy;

  @override
  void initState() {
    super.initState();
    _timingsCallback = _onFrameTimings;

    _staticMarkers = Map<MarkerId, Marker>.from(widget.staticMarkersMap);
    _stableAnimatedMarkers = Map<MarkerId, Marker>.from(
      widget.animatedMarkersMap,
    );
    _activeAnimatedMarkers = <MarkerId, Marker>{};

    _attachViewportBoundsListener(_policy.viewportBoundsListenable);
    _refreshViewportBounds();

    _initializeEffectiveProfile();
    _refreshEffectiveAnimationConfig();
    _syncTimingsCallbackSubscription();

    _markersStreamController = StreamController<Set<Marker>>.broadcast();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _markersStreamController.isClosed) {
        return;
      }
      _emitCurrentMarkers();
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _detachViewportBoundsListener(_policy.viewportBoundsListenable);
    _removeTimingsCallbackIfAttached();
    _markersStreamController.close();
    super.dispose();
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

  void _onViewportBoundsChanged() {
    _refreshViewportBounds();
  }

  void _refreshViewportBounds() {
    _latestViewportBounds =
        _policy.viewportBoundsListenable?.value ?? _policy.viewportBounds;
  }

  bool _shouldCollectFrameTimings() {
    return _policy.adaptiveEnabled && _policy.profileOverride == null;
  }

  void _syncTimingsCallbackSubscription() {
    final shouldAttach = _shouldCollectFrameTimings();
    if (shouldAttach && !_isTimingsCallbackAttached) {
      SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
      _isTimingsCallbackAttached = true;
    } else if (!shouldAttach && _isTimingsCallbackAttached) {
      _removeTimingsCallbackIfAttached();
      _clearFrameHealthWindow();
    }
  }

  void _removeTimingsCallbackIfAttached() {
    if (_isTimingsCallbackAttached) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
      _isTimingsCallbackAttached = false;
    }
  }

  void _clearFrameHealthWindow() {
    _frameDurationsUs.clear();
    _frameDurationSumUs = 0;
    _jankFrameCount = 0;
  }

  void _initializeEffectiveProfile() {
    _effectiveProfile = _policy.profileOverride ?? AdaptiveProfile.high;
  }

  void _refreshEffectiveAnimationConfig() {
    _effectiveDuration = _policy.duration;
    _effectiveCurve = _policy.curve;
    final effectiveMinFps = math.min(_policy.minFps, _policy.maxFps);

    switch (_effectiveProfile) {
      case AdaptiveProfile.high:
        _effectiveFps = _policy.maxFps;
      case AdaptiveProfile.medium:
        _effectiveFps = math.max(effectiveMinFps, (_policy.maxFps / 2).round());
      case AdaptiveProfile.low:
        _effectiveFps = _policy.allowSnapOnLow ? 0 : effectiveMinFps;
    }

    final fpsForInterval = _effectiveFps > 0 ? _effectiveFps : 1;
    _animationInterval = Duration(
      microseconds: math.max(
        1,
        (_effectiveDuration.inMicroseconds / fpsForInterval).round(),
      ),
    );
  }

  void _setEffectiveProfile(AdaptiveProfile profile) {
    if (_effectiveProfile == profile) {
      _refreshEffectiveAnimationConfig();
      return;
    }

    _effectiveProfile = profile;
    _lastProfileChangeAt = DateTime.now();
    _refreshEffectiveAnimationConfig();

    if (_activeTransitions.isEmpty) {
      return;
    }

    if (_effectiveProfile == AdaptiveProfile.low && _policy.allowSnapOnLow) {
      _finalizeActiveTransitions();
      return;
    }

    _restartTicker(keepProgress: true);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_shouldCollectFrameTimings()) {
      return;
    }

    for (final timing in timings) {
      _pushFrameDuration(timing.totalSpan.inMicroseconds);
    }

    _maybeAdaptProfile();
  }

  void _pushFrameDuration(int durationUs) {
    _frameDurationsUs.addLast(durationUs);
    _frameDurationSumUs += durationUs;
    if (durationUs > _kJankFrameThresholdUs) {
      _jankFrameCount++;
    }

    while (_frameDurationsUs.length > _kFrameHealthWindow) {
      final removed = _frameDurationsUs.removeFirst();
      _frameDurationSumUs -= removed;
      if (removed > _kJankFrameThresholdUs) {
        _jankFrameCount--;
      }
    }
  }

  void _maybeAdaptProfile() {
    if (_frameDurationsUs.length < 20) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastProfileChangeAt) < _policy.adaptationCooldown) {
      return;
    }

    final avgFrameUs = _frameDurationSumUs / _frameDurationsUs.length;
    final jankRatio = _jankFrameCount / _frameDurationsUs.length;

    final AdaptiveProfile nextProfile;
    if (avgFrameUs >= _kLowFrameTimeUs || jankRatio >= _kLowJankRatio) {
      nextProfile = AdaptiveProfile.low;
    } else if (avgFrameUs >= _kMediumFrameTimeUs ||
        jankRatio >= _kMediumJankRatio) {
      nextProfile = AdaptiveProfile.medium;
    } else {
      nextProfile = AdaptiveProfile.high;
    }

    _setEffectiveProfile(nextProfile);
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
    if (_effectiveProfile == AdaptiveProfile.low && _policy.allowSnapOnLow) {
      return false;
    }

    final bounds = _latestViewportBounds;
    if (bounds == null) {
      return true;
    }

    return _isInsideBounds(current.position, bounds) ||
        _isInsideBounds(target.position, bounds);
  }

  Set<Marker> _composeCurrentMarkers() {
    return <Marker>{
      ..._staticMarkers.values,
      ..._stableAnimatedMarkers.values,
      ..._activeAnimatedMarkers.values,
    };
  }

  void _emitCurrentMarkers() {
    if (!_markersStreamController.isClosed) {
      _markersStreamController.add(_composeCurrentMarkers());
    }
  }

  void _startTicker({required bool resetProgress}) {
    _tickerTimer?.cancel();
    if (_activeTransitions.isEmpty) {
      return;
    }

    if (resetProgress) {
      _elapsedAnimationUs = 0;
    }

    _tickerTimer = Timer.periodic(_animationInterval, (timer) {
      if (!mounted || _markersStreamController.isClosed) {
        timer.cancel();
        return;
      }

      _elapsedAnimationUs = math.min(
        _elapsedAnimationUs + _animationInterval.inMicroseconds,
        _effectiveDuration.inMicroseconds,
      );
      final fraction = (_elapsedAnimationUs / _effectiveDuration.inMicroseconds)
          .clamp(0.0, 1.0);
      final curveFraction = _effectiveCurve.transform(fraction);

      for (final markerPair in _activeTransitions.entries) {
        final oldMarker = markerPair.value.from;
        final newMarker = markerPair.value.to;
        final newLatLng = oldMarker.position.lerp(
          newMarker.position,
          step: curveFraction,
        );
        final newRotation = oldMarker.rotation.lerp(
          newMarker.rotation,
          step: curveFraction,
        );
        _activeAnimatedMarkers[markerPair.key] = newMarker.copyWith(
          positionParam: newLatLng,
          rotationParam: newRotation,
        );
      }
      _emitCurrentMarkers();

      if (fraction >= 1.0) {
        _finalizeActiveTransitions();
      }
    });
  }

  void _restartTicker({required bool keepProgress}) {
    _startTicker(resetProgress: !keepProgress);
  }

  void _finalizeActiveTransitions() {
    for (final entry in _activeTransitions.entries) {
      _stableAnimatedMarkers[entry.key] = entry.value.to;
    }
    _activeTransitions.clear();
    _activeAnimatedMarkers.clear();
    _tickerTimer?.cancel();
    _elapsedAnimationUs = 0;
    _emitCurrentMarkers();
  }

  @override
  void didUpdateWidget(covariant AnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationPolicy.viewportBoundsListenable !=
        _policy.viewportBoundsListenable) {
      _detachViewportBoundsListener(
        oldWidget.animationPolicy.viewportBoundsListenable,
      );
      _attachViewportBoundsListener(_policy.viewportBoundsListenable);
    }
    _refreshViewportBounds();
    _syncTimingsCallbackSubscription();

    final overrideProfile = _policy.profileOverride;
    if (overrideProfile != null) {
      _setEffectiveProfile(overrideProfile);
    } else if (!_policy.adaptiveEnabled) {
      _setEffectiveProfile(AdaptiveProfile.high);
    } else {
      _refreshEffectiveAnimationConfig();
    }

    _tickerTimer?.cancel();

    _staticMarkers
      ..clear()
      ..addAll(widget.staticMarkersMap);

    final lastDisplayedMarkers = Map<MarkerId, Marker>.of(
      _stableAnimatedMarkers,
    )..addAll(_activeAnimatedMarkers);

    _stableAnimatedMarkers.clear();
    _activeAnimatedMarkers.clear();
    _activeTransitions.clear();

    for (final newMarker in widget.animatedMarkers) {
      final currentDisplayedMarker = lastDisplayedMarkers[newMarker.markerId];
      if (currentDisplayedMarker == null) {
        _stableAnimatedMarkers[newMarker.markerId] = newMarker;
      } else if (currentDisplayedMarker.position != newMarker.position ||
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
        _stableAnimatedMarkers[newMarker.markerId] = newMarker;
      }
    }

    _emitCurrentMarkers();

    if (_activeTransitions.isEmpty) {
      return;
    }

    if (_effectiveProfile == AdaptiveProfile.low && _policy.allowSnapOnLow) {
      _finalizeActiveTransitions();
      return;
    }

    _startTicker(resetProgress: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<Marker>>(
      stream: _markersStreamController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData) {
          return widget.builder(context, _composeCurrentMarkers());
        }
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}
