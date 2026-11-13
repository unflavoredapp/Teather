# Tetherless — two iPhone apps + Debian helper

This repository contains three independently built components:

- **Tetherless** (`team.tetherless.ios`): pairing, files, library, device and backend settings.
- **Tetherless Decrypt** (`team.tetherless.decrypt`): standalone app-selection/decryption workflow UI.
- **TetherlessHelper**: Swift command-line/API service for Debian Linux.

## GitHub builds

Push this repository to GitHub, then run Actions:

- `Build Tetherless unsigned IPA`
- `Build Tetherless Decrypt unsigned IPA`
- `Build Debian TetherlessHelper`

The two iOS workflows package unsigned `.ipa` files without an Apple signing identity. These IPAs are build artifacts, not ready-to-install signed apps; sign them with your own authorized certificate/provisioning workflow before ordinary installation.

The Debian helper remains a separate executable and service. Set its API token and data directory in the deployment environment. Do not commit credentials.

## Current integration boundary

Both iOS apps are separate targets and bundle IDs. Tetherless currently has the helper health/device/metadata client. Tetherless Decrypt currently establishes the independent decryption UI; its job submission must be wired to a supported helper job API before it can perform an end-to-end operation. Neither app extracts Apple's protected FairPlay keys or bypasses DRM.
