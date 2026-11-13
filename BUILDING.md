# Build artifacts

GitHub Actions produces three artifacts independently:

| Workflow | Artifact |
|---|---|
| Build Tetherless unsigned IPA | `Tetherless.ipa` |
| Build Tetherless Decrypt unsigned IPA | `TetherlessDecrypt.ipa` |
| Build TetherlessHelper for Debian | `TetherlessHelper-debian-x86_64.tar.gz` |

Both iOS workflows use macOS/Xcode and package an unsigned app bundle into `Payload/<App>.app` inside the IPA. No signing credentials are required for the build. The resulting IPA must be signed with an appropriate certificate and provisioning profile before normal installation.

The Debian workflow runs the Swift test suite before building the Linux executable.
