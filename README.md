# Health Tracker App

A high-performance Android application built with Flutter for tracking personal goals, focusing on sugar intake and hydration.

## Features

### 1. User Account Management
- **Security:** Secure authentication flow simulation.
- **Experience:** Clean login and registration interfaces.

### 2. Onboarding
- **Interactive:** Built with `introduction_screen` to guide new users.
- **Persistent:** Shows only on first launch using `SharedPreferences`.

### 3. Dashboard
- **Visuals:** Uses `fl_chart` for historical data visualization.
- **Widgets:** Custom glassmorphic cards for Sugar and Water tracking.
- **Real-time:** Updates efficiently using `flutter_riverpod`.

### 4. Goal Tracking
- **Customizable:** Users can set their daily limits for sugar (g) and water (mL).
- **Storage:** Persists user preferences locally.

### 5. Notifications
- **Local Notifications:** Reminders to log data using `flutter_local_notifications`.

## Architecture
- **State Management:** Riverpod.
- **Navigation:** GoRouter.
- **UI Design System:** Material 3 with a custom Dark Theme utilizing `GoogleFonts.outfit`.

## Getting Started

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the App:**
   ```bash
   flutter run
   ```

## Performance Note
This app utilizes `const` constructors extensively and lazy-builds charts and lists to ensure 60fps performance on Android devices.
