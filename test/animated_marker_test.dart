import 'package:animated_marker/animated_marker.dart';
import 'package:animated_marker/src/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Marker _marker({
  required String id,
  required double lat,
  double lng = 0,
  double rotation = 0,
}) {
  return Marker(
    markerId: MarkerId(id),
    position: LatLng(lat, lng),
    rotation: rotation,
  );
}

Marker _findMarker(Set<Marker> markers, String markerId) {
  return markers.firstWhere((marker) => marker.markerId == MarkerId(markerId));
}

bool _hasMarker(Set<Marker> markers, String markerId) {
  return markers.any((marker) => marker.markerId == MarkerId(markerId));
}

void main() {
  test('LatLng and angle lerp behave as expected', () {
    expect(
      const LatLng(0, 0).lerp(const LatLng(10, 10), step: 0.25),
      const LatLng(2.5, 2.5),
    );
    expect(350.0.lerp(10.0, step: 0.5), closeTo(0, 0.0001));
    expect(10.0.lerp(350.0, step: 0.5), closeTo(0, 0.0001));
  });

  test(
    'Range checks throw for invalid interpolation and duration division',
    () {
      expect(
        () => const LatLng(0, 0).lerp(const LatLng(1, 1), step: -0.1),
        throwsRangeError,
      );
      expect(() => 90.0.lerp(180.0, step: 1.1), throwsRangeError);
      expect(() => const Duration(seconds: 1) / 0, throwsArgumentError);
    },
  );

  test('AnimatedMarker validates constructor inputs', () {
    final marker = _marker(id: 'm1', lat: 0);

    expect(
      () => AnimatedMarker(
        animatedMarkers: {marker},
        fps: 0,
        builder: (_, markers) => const SizedBox.shrink(),
      ),
      throwsAssertionError,
    );

    expect(
      () => AnimatedMarker(
        animatedMarkers: {marker},
        duration: Duration.zero,
        builder: (_, markers) => const SizedBox.shrink(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('AnimatedMarker includes static and animated markers', (
    tester,
  ) async {
    Set<Marker> latestMarkers = <Marker>{};
    final staticMarker = _marker(id: 'static', lat: 1);
    final animatedMarker = _marker(id: 'animated', lat: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMarker(
          staticMarkers: {staticMarker},
          animatedMarkers: {animatedMarker},
          builder: (_, markers) {
            latestMarkers = markers;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();

    expect(latestMarkers.length, 2);
    expect(
      latestMarkers.any(
        (marker) => marker.markerId == const MarkerId('static'),
      ),
      isTrue,
    );
    expect(
      latestMarkers.any(
        (marker) => marker.markerId == const MarkerId('animated'),
      ),
      isTrue,
    );
  });

  testWidgets(
    'AnimatedMarker continues from last displayed frame on interrupted updates',
    (tester) async {
      Set<Marker> latestMarkers = <Marker>{};

      Widget buildWidget(Set<Marker> markers) {
        return MaterialApp(
          home: AnimatedMarker(
            animatedMarkers: markers,
            duration: const Duration(seconds: 1),
            fps: 4,
            curve: Curves.linear,
            builder: (_, streamedMarkers) {
              latestMarkers = streamedMarkers;
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 0)}));
      await tester.pump();

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 4)}));
      await tester.pump(const Duration(milliseconds: 250));
      final firstAnimationLat =
          _findMarker(latestMarkers, 'car').position.latitude;
      expect(firstAnimationLat, closeTo(1, 0.0001));

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 8)}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final secondAnimationLat =
          _findMarker(latestMarkers, 'car').position.latitude;
      expect(secondAnimationLat, closeTo(2.75, 0.001));
    },
  );

  testWidgets(
    'AnimatedMarker does not snap when rebuilt with the same target mid-animation',
    (tester) async {
      Set<Marker> latestMarkers = <Marker>{};

      Widget buildWidget(Set<Marker> markers) {
        return MaterialApp(
          home: AnimatedMarker(
            animatedMarkers: markers,
            duration: const Duration(seconds: 1),
            fps: 4,
            curve: Curves.linear,
            builder: (_, streamedMarkers) {
              latestMarkers = streamedMarkers;
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 0)}));
      await tester.pump();

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 4)}));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _findMarker(latestMarkers, 'car').position.latitude,
        closeTo(1, 0.001),
      );

      await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 4)}));
      await tester.pump();
      expect(
        _findMarker(latestMarkers, 'car').position.latitude,
        closeTo(1, 0.001),
      );

      await tester.pump(const Duration(milliseconds: 250));
      final continuedLat = _findMarker(latestMarkers, 'car').position.latitude;
      expect(continuedLat, closeTo(1.75, 0.001));
      expect(continuedLat, lessThan(4));
    },
  );

  testWidgets('AnimatedMarker applies updated FPS while animating', (
    tester,
  ) async {
    Set<Marker> latestMarkers = <Marker>{};

    Widget buildWidget({
      required Set<Marker> markers,
      required int fps,
      Duration duration = const Duration(seconds: 1),
    }) {
      return MaterialApp(
        home: AnimatedMarker(
          animatedMarkers: markers,
          duration: duration,
          fps: fps,
          curve: Curves.linear,
          builder: (_, streamedMarkers) {
            latestMarkers = streamedMarkers;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(
      buildWidget(markers: {_marker(id: 'car', lat: 0)}, fps: 4),
    );
    await tester.pump();

    await tester.pumpWidget(
      buildWidget(markers: {_marker(id: 'car', lat: 4)}, fps: 4),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(1, 0.001),
    );

    await tester.pumpWidget(
      buildWidget(markers: {_marker(id: 'car', lat: 4)}, fps: 2),
    );
    await tester.pump();
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(1, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(1, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(2.5, 0.001),
    );
  });

  testWidgets('AnimatedMarker handles add/remove/update in one update', (
    tester,
  ) async {
    Set<Marker> latestMarkers = <Marker>{};

    Widget buildWidget(Set<Marker> markers) {
      return MaterialApp(
        home: AnimatedMarker(
          staticMarkers: {_marker(id: 'static', lat: 100)},
          animatedMarkers: markers,
          duration: const Duration(seconds: 1),
          fps: 2,
          curve: Curves.linear,
          builder: (_, streamedMarkers) {
            latestMarkers = streamedMarkers;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(
      buildWidget({_marker(id: 'a', lat: 0), _marker(id: 'b', lat: 5)}),
    );
    await tester.pump();

    await tester.pumpWidget(
      buildWidget({_marker(id: 'a', lat: 2), _marker(id: 'c', lat: 7)}),
    );
    await tester.pump();
    await tester.pump();

    expect(_hasMarker(latestMarkers, 'static'), isTrue);
    expect(_hasMarker(latestMarkers, 'a'), isTrue);
    expect(
      _findMarker(latestMarkers, 'a').position.latitude,
      closeTo(0, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(_hasMarker(latestMarkers, 'c'), isTrue);
    expect(_hasMarker(latestMarkers, 'b'), isFalse);
    expect(
      _findMarker(latestMarkers, 'a').position.latitude,
      closeTo(1, 0.001),
    );
    expect(
      _findMarker(latestMarkers, 'c').position.latitude,
      closeTo(7, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      _findMarker(latestMarkers, 'a').position.latitude,
      closeTo(2, 0.001),
    );
    expect(_hasMarker(latestMarkers, 'b'), isFalse);
  });

  testWidgets('AnimatedMarker viewportAnimationBounds can skip interpolation', (
    tester,
  ) async {
    Set<Marker> latestMarkers = <Marker>{};

    Widget buildWidget(Set<Marker> markers) {
      return MaterialApp(
        home: AnimatedMarker(
          animatedMarkers: markers,
          duration: const Duration(seconds: 1),
          fps: 4,
          curve: Curves.linear,
          viewportAnimationBounds: LatLngBounds(
            southwest: const LatLng(50, 50),
            northeast: const LatLng(60, 60),
          ),
          builder: (_, streamedMarkers) {
            latestMarkers = streamedMarkers;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 0)}));
    await tester.pump();

    await tester.pumpWidget(buildWidget({_marker(id: 'car', lat: 4)}));
    await tester.pump();
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(4, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      _findMarker(latestMarkers, 'car').position.latitude,
      closeTo(4, 0.001),
    );
  });

  test('MarkerTween interpolates marker position and rotation', () {
    final tween = MarkerTween(
      begin: _marker(id: 'vehicle', lat: 0, rotation: 350),
      end: _marker(id: 'vehicle', lat: 10, rotation: 10),
    );

    final marker = tween.lerp(0.5);
    expect(marker.position.latitude, closeTo(5, 0.0001));
    expect(marker.rotation, closeTo(0, 0.0001));
  });
}
