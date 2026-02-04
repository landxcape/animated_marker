# Changelog

## 0.3.0

* Breaking: replaced direct animation params (`duration`, `curve`, `fps`, `viewportAnimationBounds*`) with `animationPolicy`.
* Feat: added `AnimationPolicy` and `AdaptiveProfile` for centralized animation/runtime behavior.
* Feat: added optional adaptive profile controls (`adaptiveEnabled`, `profileOverride`, `minFps`, `allowSnapOnLow`, `adaptationCooldown`).
* Perf: kept viewport guard behavior via `AnimationPolicy.viewportBounds` and `AnimationPolicy.viewportBoundsListenable`.
* Docs/Test: updated README, example app, and package tests for the new API.

## 0.2.2

* Feat: added `viewportAnimationBoundsListenable` for runtime viewport guard updates without parent rebuilds.
* Docs: updated README examples for viewport guard usage.

## 0.2.1

* Perf: optimized animated marker runtime with stable/active marker buckets.
* Feat: added `viewportAnimationBounds` to skip interpolation outside viewport.
* Test: added coverage for viewport animation guard behavior.

## 0.2.0

* Chore: updated package metadata and SDK constraints for current Flutter.
* Chore: improved README and publish hygiene (`.pubignore`).
* Refactor: tightened animation lifecycle safety and added package tests.
* Fix: replaced deprecated marker z-index API usage.

## 0.1.5

* Merged [pr#14] Refactor animated marker update and animation logic

## 0.1.4

* Fixed static markers' `InfoWindow`'s `onTap` callback not working.

## 0.1.3

* Fixed markers flickering on map load due to new markers being added before the initial animation completes.

## 0.1.2

* Fixed markers stream to initially emit only after the widgets are built.

## 0.1.1

* Fixed initially markers showing late due to waiting for the animation to start. Now, it shows all the markers before animation.

## 0.1.0

* Changed marker animation method from `AnimationController` to `Ticker` to add fps control and improve performance by reducing unnecessary repaints.

## 0.0.8

* Chore: updated to use latest version of flutter and packages

## 0.0.7

* Refactored marker animation logic for improved performance

## 0.0.6

* Fixed janky marker animations where the marker would jump to new locations if the animation was interrupted with new data

## 0.0.5

* updated examples showing latest changes

## 0.0.4

* added "staticMarkers" field (those markers that are not to animate)
* changed "markerLocations" to "animatedMarkers"

## 0.0.3

* Update marker pairs only when the list markers are different in update

## 0.0.2

* Added Curve Animation; you can now give curve effect to the animations
* Changed minimum sdk support to >= 2.17.0

## 0.0.1

* AnimatedMarker is a simple and convenient way to animate markers on Google Maps in Flutter. This initial release provides basic functionality, including marker animation calculation and customization options.
