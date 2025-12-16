# Smart HR App

A comprehensive Human Resource Management System Flutter application.

## Features

- Employee dashboard with attendance tracking
- Leave management system
- Notification system with Firebase Cloud Messaging
- Face recognition attendance
- Location-based attendance verification
- Multi-role access (Admin, HR, Manager, Employee)

## Getting Started

### Prerequisites

- Flutter SDK 3.9.0 or higher
- Android Studio or VS Code
- Firebase project for FCM

### Installation

1. Clone the repository
2. Run `flutter pub get`
3. Set up Firebase for the project
4. Run `flutter run`

## Testing

Run the tests with:
```bash
flutter test
```

## Building for Release

To build for Android release:
```bash
flutter build apk --release
```

To build for iOS release:
```bash
flutter build ios --release
```

## Project Structure

- `lib/main.dart` - Entry point
- `lib/screens/` - All screen widgets
- `lib/providers/` - State management with Provider
- `lib/models/` - Data models
- `lib/services/` - API and FCM services
- `lib/utils/` - Utility functions
- `lib/widgets/` - Reusable widgets

## Dependencies

Key dependencies include:
- provider: State management
- firebase_messaging: Push notifications
- geolocator: Location services
- camera: Face recognition
- http: API communication

## License

This project is proprietary and confidential.