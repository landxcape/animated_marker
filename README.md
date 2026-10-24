# animated_marker

Smooth marker movement and rotation interpolation for Flutter Google Maps.

[![pub package](https://img.shields.io/pub/v/animated_marker.svg)](https://pub.dev/packages/animated_marker)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-flutter%20%7C%20android%20%7C%20ios%20%7C%20web-blue)](https://pub.dev/packages/animated_marker)

`AnimatedMarker` continuously interpolates position (`LatLng`), bearing/rotation (shortest angular path), alpha, and z-index between location updates without blocking the UI or causing marker jumps. It uses `google_maps_flutter_platform_interface` under the hood to ensure seamless compatibility with any version of `google_maps_flutter` without native plugin conflicts.

## Features

- **Smooth Interpolation**: Automatically animates position changes and spherical angle rotations between location updates.
- **Static vs Animated Partitioning**: Isolate non-moving markers via `staticMarkers` so only active markers undergo ticker calculations.
- **Viewport Culling**: Skip interpolation for markers outside the current viewport via `viewportBounds` or dynamic `viewportBoundsListenable`.
- **Adaptive Performance Tuning**: Centralized `AnimationPolicy` with frame-health monitoring (`adaptiveEnabled`, `allowSnapOnLow`, and `AdaptiveProfile` tiers) that automatically reduces frame rate under device load to preserve 60 FPS UI responsiveness.
- **Zero-Friction DX**: Accepts standard `Set<Marker>` and outputs the effective `Set<Marker>` directly into your `GoogleMap` widget builder.

## Installation

Add via CLI:

```bash
flutter pub add animated_marker
```

Or add to your `pubspec.yaml`:

```yaml
dependencies:
  animated_marker: ^<latest>
  google_maps_flutter: ^<latest>
```

## Quick Start

```dart
import 'package:animated_marker/animated_marker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FleetTrackingMap extends StatelessWidget {
  const FleetTrackingMap({
    super.key,
    required this.movingVehicles,
    required this.staticDepots,
  });

  final Set<Marker> movingVehicles;
  final Set<Marker> staticDepots;

  @override
  Widget build(BuildContext context) {
    return AnimatedMarker(
      animatedMarkers: movingVehicles,
      staticMarkers: staticDepots,
      animationPolicy: const AnimationPolicy(
        duration: Duration(seconds: 2),
        curve: Curves.easeInOut,
        maxFps: 30,
        adaptiveEnabled: true,
      ),
      builder: (BuildContext context, Set<Marker> markers) {
        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.77483, -122.41942),
            zoom: 14,
          ),
          markers: markers,
        );
      },
    );
  }
}
```

## Advanced Policy Configuration

Configure runtime animation behavior, viewport bounds, and adaptive quality via `AnimationPolicy`:

```dart
AnimationPolicy(
  // Duration of marker transition between updates:
  duration: const Duration(milliseconds: 1500),

  // Motion curve:
  curve: Curves.easeOutCubic,

  // Target FPS ceiling for smooth movement:
  maxFps: 30,

  // Optional: static viewport bounds to skip interpolation for off-screen markers:
  viewportBounds: currentVisibleBounds,

  // Optional: dynamic bounds listenable to guard viewport without parent rebuilds:
  viewportBoundsListenable: visibleBoundsNotifier,

  // Adaptive quality mode: automatically down-samples FPS when frame drops occur:
  adaptiveEnabled: true,
  minFps: 15,
  allowSnapOnLow: true,
  adaptationCooldown: const Duration(seconds: 2),
)
```

## How It Works

1. **Shortest Angular Rotation**: Angles are normalized and lerped along the shortest rotational path, preventing full 360° spin-arounds when crossing the 0°/360° meridian.
2. **State Transition Continuity**: If a marker's target updates mid-flight, the animation picks up smoothly from its current rendered position rather than resetting or jumping to the original origin.
3. **Pure Platform Interface**: Built against `google_maps_flutter_platform_interface` rather than native plugins, making it lightweight and compatible across Android, iOS, and Web.
