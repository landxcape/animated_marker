import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

/// Extension for [LatLng] to add custom operators and methods.
extension LatLngExt on LatLng {
  /// Adds two [LatLng] instances by adding their latitude and longitude.
  LatLng operator +(LatLng other) {
    return LatLng(latitude + other.latitude, longitude + other.longitude);
  }

  /// Subtracts the longitude and latitude of another [LatLng] instance.
  LatLng operator -(LatLng other) {
    return LatLng(latitude - other.latitude, longitude - other.longitude);
  }

  /// Multiplies the latitude and longitude by a given multiplier.
  LatLng operator *(double multiplier) {
    return LatLng(latitude * multiplier, longitude * multiplier);
  }

  /// Linearly interpolates between this [LatLng] and another [LatLng].
  /// [step] should be a value between 0.0 and 1.0 (inclusive).
  LatLng lerp(LatLng other, {required double step}) {
    assert(step >= 0.0 && step <= 1.0);
    return LatLng(
      latitude * (1 - step) + other.latitude * step,
      longitude * (1 - step) + other.longitude * step,
    );
  }
}

/// Extension for [Duration] to add a division operator.
extension DurationExt on Duration {
  /// Divides the duration by a given divisor.
  Duration operator /(double divisor) {
    return Duration(microseconds: inMicroseconds ~/ divisor);
  }
}

/// Extension for [double] to add interpolation for angles.
extension IntExtension on double {
  /// Interpolates between this angle and another angle.
  /// The interpolation is normalized to the range [0, 360].
  /// [step] should be a value between 0.0 and 1.0 (inclusive).
  double lerp(double angle, {required double step}) {
    assert(step >= 0.0 && step <= 1.0);
    // Normalize angles between 0 and 360
    final angleA = this % 360;
    angle %= 360;

    // Calculate shortest angular difference
    double difference = angle - angleA;

    // Wrap difference within -180 to 180
    if (difference > 180) {
      difference -= 360;
    } else if (difference < -180) {
      difference += 360;
    }

    // Calculate the interpolated angle at the given fraction (0.0 to 1.0)
    return (angleA + step * difference) % 360;
  }
}
