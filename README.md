# ZeroTrace

A data/media wiping app that cleans your data safely and securely.


<br>

## About

ZeroTrace is a secure data-wiping Android app built with Flutter. It
ensures permanently unrecoverable deletion of files by overwriting their
content with zeros or cryptographically secure random data. Users can
wipe sensitive files before selling, recycling, or handing over their
devices, ensuring complete privacy and erasure of their personal data.

<br>

## Features

-   🔐 **Secure Data Wiping:** Zero, Random, or DoD 7‑pass secure
    overwrite methods.
    
-   📁 **File Browser:** Browse and select files directly from device
    storage.

-   🧪 **Post‑Wipe Verification:** View hex‑level corrupted byte
    output.

-   🗑️ **Safe Deletion:** Option to delete wiped files or keep them for
    verification.

-   📄 **PDF Certificate Generation:** Includes filenames, sizes, wipe
    method, timestamp, and SHA‑256 digital signature.

-   📤 **Shareable Certificates:** Export via WhatsApp, email, or other
    apps.

-   🔒 **Fully Offline:** No data leaves the device---complete privacy
    guaranteed.

<br>

## Direct Download Link

The app .apk file can be downloaded form the below link,

Download: [ZeroTrace.apk](https://github.com/omhujband/ZeroTrace/releases/download/v1.0.0.0/ZeroTrace.apk)

<br>

## Installation

Clone the repository and run on any Flutter-supported Android
environment.

``` bash
git clone https://github.com/omhujband/ZeroTrace.git
cd zerotrace
# get all the dependencies 
flutter pub get
# run the app
flutter run
```

<br>

## Prerequisites

-   Flutter SDK (\>=3.x recommended)
-   Android SDK + emulator or physical device
-   Dart SDK (included with Flutter)
-   Required storage permissions on device

<br>

## Setup

1.  Install Flutter & set up the environment.

2.  Enable USB debugging (for physical devices).

3.  Connect device or start emulator.

4.  Fetch dependencies using:

``` bash
flutter pub get
```

<br>

## Running the App

To build and run:

``` bash
flutter run
```

To build a release APK:

``` bash
flutter build apk --release
```

<br>

## How It Works

1.  User selects a file.

2.  The file's raw bytes are overwritten with chosen wipe pattern:
    -   **Quick Zero:** Single pass of zero bytes.

    -   **Standard Random:** 3 passes with cryptographically secure
        random data.

    -   **DoD 7‑Pass:** Military‑grade 7‑layer overwrite, where the first pass is zeros, second pass is 1's, and third to seventh pass is random bit pattern.

3.  User can verify corruption by viewing hex output.

4.  User may delete the wiped file entirely.

5.  ZeroTrace generates a **tamper‑proof PDF certificate** summarizing
    the wipe operation.

<br>

## Architecture

-   **Flutter UI Layer:** Material + custom widgets.

-   **Platform Channels:** Bridge to Android for secure byte-level
    overwrite.

-   **Wipe Engine:** Kotlin/Android code performing secure overwrites.

-   **PDF Generator:** Flutter + native utilities exporting
    certificates.

-   **Local Storage / File APIs:** Access and modify device filesystem.

<br>

## Data Storage

-   No cloud storage.

-   Only local temporary buffers used during overwrite.

-   Certificates stored locally until user exports/shares them.

<br>

## Counter Types

Used to count wipe passes: - **Single-pass counter** - **Triple-pass
counter** - **7-pass DoD counter**

Used internally for tracking overwrite progress & certificate logging.

<br>

## Dependencies

Common Flutter dependencies may include: - `path_provider` -
`file_picker` - `permission_handler` - `flutter_pdf` / `pdf` - `crypto`
(for SHA‑256) - `shared_preferences` (optional)

(Actual dependencies depend on your project's `pubspec.yaml`.)

<br>

## Screenshots

*Add screenshots in `/assets/screenshots/` and reference them here.*

Example:

    ![Home Screen](assets/screenshots/home.png)
    ![Wipe Progress](assets/screenshots/wipe_progress.png)

<br>

## Project Structure

```

lib/
├── main.dart                      # App entry point
│
├── models/
│   ├── certificate.dart           # Certificate data model
│   ├── wipe_result.dart           # Wipe result & method models
│   └── wiped_file.dart            # Wiped file tracking model
│
├── services/
│   ├── certificate_service.dart   # PDF/JSON certificate generation
│   ├── storage_service.dart       # Local storage for wiped files
│   └── wipe_service.dart          # Core secure wiping logic
│
└── screens/
    ├── home_screen.dart           # Main screen with file selection
    ├── file_browser_screen.dart   # Native file browser
    ├── wipe_progress_screen.dart  # Wiping progress display
    ├── verification_screen.dart   # Data destruction verification
    ├── decision_screen.dart       # Delete or keep choice
    ├── wiped_files_screen.dart    # Manage kept wiped files
    └── certificate_screen.dart    # Certificate display & sharing

```

<br>

## Future Enhancements

-   🧹 Full‑drive wiping (internal + SD card)
-   🔄 Background wipe queue
-   📊 Analytics dashboard (on‑device only)
-   🔑 Encrypted wipe certificates
-   🌐 Multi‑language support
-   🤖 AI-based file sensitivity detection (all offline)

<br>

## Contributing

Contributions, issues, and feature requests are welcome!

1.  Fork the repository\
2.  Create a branch: `git checkout -b feature-name`\
3.  Commit changes: `git commit -m "Added feature"`\
4.  Push: `git push origin feature-name`\
5.  Open a pull request

<br>

## License

This project is licensed under the MIT License.\
See `LICENSE` file for details.

<br>

## Contact

For questions or collaboration:\
**Your Name**\
Email: your.email@example.com\
GitHub: https://github.com/yourusername
