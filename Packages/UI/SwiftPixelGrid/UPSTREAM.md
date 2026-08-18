# Upstream

- Project: [afetmin/SwiftPixelGrid](https://github.com/afetmin/SwiftPixelGrid)
- Version: `v0.1.0`
- Commit: `1496aacdf2ffb92ddd9d51788c24a33f35ef0b42`
- License: MIT (`LICENSE`)

## Compatibility patch

Monologue supports iOS 16, while upstream v0.1.0 declares iOS 17. This vendored package keeps the public API and renderer intact, lowers the package platform to iOS 16, replaces the single iOS 17-only `Animation.smooth` call in `PixelPatternView` with `easeInOut`, and expresses the two-value `onChange` restart hook with the iOS 16 callback form. The Canvas-based `PixelGrid` renderer used by the player theme is otherwise unchanged.
