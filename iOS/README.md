# Tetherless iOS client

Separate SwiftUI iPhone client. The existing SwiftPM service remains the Debian backend.

GitHub Actions workflow `.github/workflows/ios-unsigned-ipa.yml` builds the iOS target on macOS with signing disabled, packages `Payload/Tetherless.app` into `Tetherless-unsigned.ipa`, and uploads it as a workflow artifact. The IPA is intentionally unsigned and needs a valid signing/provisioning path before ordinary iOS installation.

Configure the backend URL and bearer token in the app's Backend tab. The client currently provides backend connectivity, device listing, app metadata lookup, and IPA selection. IPA inspection/extraction/repackaging are handled by the Debian backend. No FairPlay key extraction or DRM memory patching is implemented.
