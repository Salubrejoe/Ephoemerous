# LoreKit

Personal toolkit of context-free SwiftUI components. The strict
admission rule: **no dependency on app state, no reach into anyone's
environment, no domain types.** If it can't be lifted into any future
project without bringing baggage, it doesn't belong here.

## What's in here

- **`Squircle`** — Lamé-curve superellipse with adjustable corners + bulge
  and an animatable `bulge` channel. The shape used as the watch-face
  disc, the ecliptic rim's bulge pattern, the horizon's deformable
  squircle, and anywhere else a "rounded n-gon" reads better than a
  circle. Includes a static `lameRadius(angle:corners:bulge:)` helper
  for callers that want to apply the same radial modulation to their
  own non-circular curves.
- **`SFSymbolShape`** — Any SF Symbol resolved to a `Shape` via
  `VNDetectContoursRequest`. Lets you fill / stroke / animate /
  rotate / sample any SF Symbol as a first-class `Shape`. Cached per
  (name, weight) so the Vision pass is paid once per symbol.
  iOS-only (`#if canImport(UIKit)`); the rest of LoreKit still builds
  on macOS.
- **`LoreSymbol` + `Image(symbol:)`** — Curated SF Symbol vocabulary
  (the classics: calendar, checkmark, plus, xmark, search… plus
  whatever else gets added over time). Ships with a concrete
  `Image(symbol: LoreSymbol)` init so `Image(symbol: .checkmark)`
  works in any consumer with zero per-project boilerplate. A generic
  `Image(symbol:)` for any `RawRepresentable<String>` enum is in
  `Image+Symbol.swift` for unusual one-off vocabularies.
- **`Angle`/`Double`/`Array`/`Color`/`SIMD3`/`Date`** — small
  context-free utilities: `Angle.pi(over:)`, `.clamped(to:)`,
  `Array.uniqued(by:)`, `Color(hex:)`, system colour wrappers,
  `SIMD3` rotations + orthonormal basis, `Date.timeString`.

## Roadmap

When the population grows enough to need shelves, split the single
`LoreKit` target into `LoreShapes` / `LoreUI` / etc. library products
behind the same package.

Future candidates (still in Ephoemerous, not yet migrated):

- Generic glass / blur / breathing-ring view modifiers.
- Geometry helpers (`Angle` extensions, SIMD helpers) that aren't
  astronomy-specific.

## Using it

```swift
import LoreKit

Squircle(corners: 4, bulge: 4)
    .fill(.yellow)
    .frame(width: 44, height: 44)
```
