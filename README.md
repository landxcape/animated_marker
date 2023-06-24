# AnimatedMarker

The AnimatedMarker widget is a Dart class that animates the movement of markers on a Google map. This widget takes in a Set of Marker positions, a builder function to build the GoogleMap and a default animation duration of 1 second. It creates an animation controller and initializes the previous and current marker positions to the provided ones. The didUpdateWidget method updates the marker positions if they change and restarts the animation. The build method returns the builder function with the current marker positions.

## Features

- Automatic calculation and animation of marker movement from its old position to the new position
- Customizable animation duration
- Easily wrap any GoogleMap widget with this AnimatedMarker widget, without having to manage the animation code manually.
- builder pattern to build your own custom UI using current marker positions

## Getting started

You will need ```flutter_google_maps: ^latest``` to use with on.

## Usage

Here's an example of how to use AnimatedMarker:

```dart
class MyMapScreen extends StatelessWidget {
  final Set<Marker> _sMarkers = // markers not needing animation...
  final Set<Marker> _aMarkers = // markers to animate...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedMarker(
        staticMarkers: _sMarkers,
        animatedMarkers: _aMarkers,
        duration: const Duration(seconds: 3), // animation duration
        builder: (BuildContext context, Set<Marker> animatedMarkers) {
          return GoogleMap(
            // setup your google map with marker options here...
            markers: animatedMarkers, // supply animated markers to GoogleMap
          );
        },
      ),
    );
  }
}
```

This will animate the markers on the Google Map every time the marker set changes.

## Additional information

This widget can be helpful to remove the markers teleporting from one location to another. It will smoothly transition the marker from the old position to the new one.
