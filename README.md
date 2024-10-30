# AnimatedMarker

The `AnimatedMarker` widget is a Flutter class that animates the movement of markers on a Google Map. This widget takes a `Set` of marker positions, a builder function to construct the `GoogleMap`, and allows customization of the animation duration, frames per second, and animation curve. It creates an animation controller and initializes the previous and current marker positions to the provided ones. The `didUpdateWidget` method updates the marker positions if they change and restarts the animation. The `build` method returns the builder function with the current marker positions.

## Features

- **Automatic Movement Animation**: Smoothly calculates and animates the movement of markers from their old positions to new ones.
- **Customizable Animation Duration**: Easily adjust the duration of the animation to fit your needs.
- **Flexible Integration**: Wrap any `GoogleMap` widget with this `AnimatedMarker` widget without having to manage the animation code manually.
- **Builder Pattern**: Build your custom UI using the current marker positions with a flexible builder function.

## Getting Started

Add the following dependencies in your `pubspec.yaml` file:

```yaml
dependencies:
  google_maps_flutter: ^latest
  flutter: any
```

## Usage

Here's an example of how to use AnimatedMarker:

```dart
class MyMapScreen extends StatelessWidget {
  final Set<Marker> _sMarkers = // markers not needing animation...
  final Set<Marker> _aMarkers = // markers to animate...

  @override
  Widget build(BuildContext context) {
    return AnimatedMarker(
      staticMarkers: staticMarkers,
      animatedMarkers: markers,
      duration: const Duration(seconds: 3), // change the animation duration
      fps: 30, // change the animation frames per second
      curve: Curves.easeOut, // change the animation curve
      builder: (context, animatedMarkers) {
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: mockPositions.first,
            zoom: 13,
          ),
          markers: animatedMarkers,
        );
      },
    );
  }
}
```

This will animate the markers on the Google Map every time the `animatedMarker` set changes.

## Additional information

The AnimatedMarker widget can help eliminate marker teleportation, providing a smooth transition from one location to another. It is particularly useful for applications requiring real-time updates, such as tracking moving vehicles, displaying user locations, or visualizing dynamic data changes.

By using this widget, you can enhance the user experience by ensuring that map markers move smoothly rather than jumping abruptly between positions.
