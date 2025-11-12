# HRMS - Human Resource Management System

A comprehensive Flutter application for managing human resources, built with modern UI/UX principles and Material Design 3.

## Features

### 📊 Dashboard
- Real-time overview of HR metrics
- Employee statistics and counts
- Attendance rate tracking
- Department distribution visualization with pie charts
- Recent activities feed

### 👥 Employee Management
- Complete employee directory
- Detailed employee profiles
- Search and filter functionality
- Employee information including:
  - Personal details
  - Department and position
  - Contact information
  - Join date and salary
  - Employment status

### ⏰ Attendance Tracking
- Daily attendance monitoring
- Check-in/check-out time tracking
- Work hours calculation
- Status indicators (Present, Absent, Late)
- Real-time attendance statistics

### 📝 Leave Management
- Leave request submission
- Leave approval workflow
- Multiple leave types (Vacation, Sick Leave, Personal)
- Leave duration calculation
- Status tracking (Pending, Approved, Rejected)

## Tech Stack

- **Flutter** - UI framework
- **Provider** - State management
- **Google Fonts** - Typography
- **FL Chart** - Data visualization
- **Intl** - Date formatting and internationalization

## Getting Started

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- VS Code or Android Studio with Flutter plugins

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd hrms_flutter_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── employee.dart
│   ├── leave_request.dart
│   └── attendance.dart
├── providers/                # State management
│   └── hrms_provider.dart
├── screens/                  # UI screens
│   ├── dashboard_screen.dart
│   ├── employees_screen.dart
│   ├── attendance_screen.dart
│   └── leaves_screen.dart
└── widgets/                  # Reusable widgets
    ├── stat_card.dart
    └── recent_activities.dart
```

## Features in Detail

### Dashboard Screen
- 4 key metric cards showing total employees, present today, pending leaves, and attendance rate
- Interactive pie chart for department distribution
- Recent activities timeline

### Employees Screen
- Searchable employee list
- Color-coded department indicators
- Quick view employee cards
- Detailed employee profile modal
- Add new employee functionality

### Attendance Screen
- Date-based attendance view
- Status summary chips
- Detailed attendance records with check-in/check-out times
- Work hours calculation

### Leaves Screen
- Comprehensive leave request list
- Visual status indicators
- Leave duration display
- Approve/reject actions for pending requests
- Add new leave request

## Customization

### Theme
The app uses Material Design 3 with a blue color scheme. To customize:
- Edit the `ColorScheme` in `main.dart`
- Modify `seedColor` to change the primary color

### Fonts
Google Fonts (Inter) is used by default. To change:
- Update `GoogleFonts.interTextTheme()` in `main.dart`

## Future Enhancements

- [ ] User authentication and authorization
- [ ] Backend API integration
- [ ] Push notifications
- [ ] Payroll management
- [ ] Performance reviews
- [ ] Document management
- [ ] Employee onboarding
- [ ] Reports and analytics
- [ ] Multi-language support
- [ ] Dark mode

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email support@hrms.com or open an issue in the repository.
# hrms-app
