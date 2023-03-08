import 'package:flutter/animation.dart';
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

  /// this function normalizes the rotation values within 360 degrees
  ///
  /// then converts negative values to positive equivalent angles
  /// then calculates the shortest path for the rotation to calculate
  /// (for example, it will go directly from +10 degrees to -10 degrees without
  /// rotating full 340 degrees)
  /// it will also calculate and choose the shortest path to rotate
  /// (i.e. it wont rotate over 180 degrees, it will calculate and take another
  /// direction instead)
  double _calculateRotation(
      double beginRotation, double endRotation, double t) {
    beginRotation %= 360;
    endRotation %= 360;

    if (beginRotation < 0) beginRotation += 360;
    if (endRotation < 0) endRotation += 360;

    final diff = (beginRotation - endRotation).abs();
    if (diff > 180) {
      if (beginRotation > 180) {
        beginRotation -= 360;
      } else {
        endRotation -= 360;
      }
    }
    return beginRotation + (endRotation - beginRotation) * t;
  }

  @override
  Marker lerp(double t) {
    return Marker(
      markerId: end!.markerId,
      position: LatLng(
        begin!.position.latitude +
            (end!.position.latitude - begin!.position.latitude) * t,
        begin!.position.longitude +
            (end!.position.longitude - begin!.position.longitude) * t,
      ),
      icon: end!.icon,
      alpha: begin!.alpha + (end!.alpha - begin!.alpha) * t,
      anchor: end!.anchor,
      draggable: end!.draggable,
      flat: end!.flat,
      infoWindow: end!.infoWindow,
      rotation: _calculateRotation(begin!.rotation, end!.rotation, t),
      visible: end!.visible,
      zIndex: begin!.zIndex + (end!.zIndex - begin!.zIndex) * t,
    );
  }
}
