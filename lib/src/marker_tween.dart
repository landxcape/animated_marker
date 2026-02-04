import 'package:flutter/animation.dart';
import 'package:animated_marker/src/extensions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    show Marker, LatLng;

class MarkerTween extends Tween<Marker> {
  /// this is the extension of [Tween] to be able to calculate begin and end
  /// of the [Marker]'s state
  ///
  /// the [begin] and [end] are same as default [Tween] of type [Marker]
  MarkerTween({
    /// the begining state of the marker
    required super.begin,

    /// the end state of the marker
    required super.end,
  });

  @override
  Marker lerp(double t) {
    final startMarker = begin!;
    final targetMarker = end!;
    final interpolatedZIndex =
        (startMarker.zIndexInt +
                (targetMarker.zIndexInt - startMarker.zIndexInt) * t)
            .round();

    return targetMarker.copyWith(
      positionParam: LatLng(
        startMarker.position.latitude +
            (targetMarker.position.latitude - startMarker.position.latitude) *
                t,
        startMarker.position.longitude +
            (targetMarker.position.longitude - startMarker.position.longitude) *
                t,
      ),
      alphaParam:
          startMarker.alpha + (targetMarker.alpha - startMarker.alpha) * t,
      rotationParam: startMarker.rotation.lerp(targetMarker.rotation, step: t),
      zIndexIntParam: interpolatedZIndex,
    );
  }
}
