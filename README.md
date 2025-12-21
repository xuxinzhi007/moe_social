# Moe Social

A social networking application built with Flutter, designed to provide a modern and intuitive user experience.

## Features

- User authentication (login/register)
- Profile management
- Settings configuration
- Cross-platform support (Android, iOS, Web, Windows, macOS, Linux)

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK installed
- IDE (VS Code, Android Studio, or IntelliJ IDEA) with Flutter plugin

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application

### Building for Production

- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`
- Windows: `flutter build windows`
- macOS: `flutter build macos`
- Linux: `flutter build linux`

## Project Structure

```
moe_social/
├── android/           # Android platform specific code
├── ios/               # iOS platform specific code
├── lib/               # Main Dart source code
│   ├── auth_service.dart   # Authentication logic
│   ├── login_page.dart     # Login screen
│   ├── main.dart           # App entry point
│   ├── profile_page.dart   # User profile screen
│   ├── register_page.dart  # Registration screen
│   └── settings_page.dart  # Settings screen
├── linux/             # Linux platform specific code
├── macos/             # macOS platform specific code
├── test/              # Unit and widget tests
├── web/               # Web platform specific code
└── windows/           # Windows platform specific code
```

## Technologies Used

- Flutter
- Dart
- Material Design

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
