import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:animated_marker/animated_marker.dart';

/// Stream of mock data positions for the AnimatedMarker widget:
final List<LatLng> mockPositions = [
  const LatLng(37.77483, -122.41942),
  const LatLng(37.76703, -122.40124),
  const LatLng(37.76651, -122.42206),
];

final Stream<List<LatLng>> positionStream = Stream.fromIterable([
  mockPositions,
  mockPositions.reversed.toList(),
]);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  /// Note: This example assumes you already have google_maps_flutter
  /// and animated_marker packages added to your project as dependencies.
  /// Also, remember to replace 'your_api_key' with your actual
  /// Google Maps API Key in your AndroidManifest.xml file
  /// or Info.plist file for Android and iOS respectively.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        /// implementation with a StreamBuilder using the above stream:
        body: StreamBuilder<List<LatLng>>(
          stream: positionStream, // use the stream in the builder
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container(); // handle no data

            final markers = snapshot.data!.map((position) {
              return Marker(
                markerId: MarkerId(position.toString()),
                position: position,
              );
            }).toSet();

            return AnimatedMarker(
              animatedMarkers: markers,
              duration:
                  const Duration(seconds: 3), // change the animation duration
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
          },
        ),
      ),
    );
  }
}
