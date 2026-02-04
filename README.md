# Animated Marker

`AnimatedMarker` smoothly animates `google_maps_flutter` markers whenever their
position or rotation changes.

## Features

- Animate marker movement and rotation automatically.
- Keep non-moving markers separate via `staticMarkers`.
- Tune motion with `AnimationPolicy` (`duration`, `curve`, `maxFps`).
- Plug into any `GoogleMap` via a simple `builder`.

## Installation

```yaml
dependencies:
  animated_marker: ^0.3.0
```

## Usage

```dart
AnimatedMarker(
  staticMarkers: staticMarkers,
  animatedMarkers: animatedMarkers,
  animationPolicy: AnimationPolicy(
    duration: const Duration(seconds: 3),
    maxFps: 30,
    curve: Curves.easeOut,
    // Optional: skip interpolation for markers fully outside this viewport.
    viewportBounds: currentMapBounds,
    // Optional (recommended for frequent camera updates):
    // pass bounds via ValueListenable to avoid parent rebuild churn.
    // viewportBoundsListenable: boundsNotifier,
  ),
  builder: (context, markers) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.77483, -122.41942),
        zoom: 13,
      ),
      markers: markers,
    );
  },
);
```

Use this widget when your marker set is driven by live updates (vehicles,
delivery tracking, moving assets, etc.) and you want smooth transitions instead
of marker jumps.
