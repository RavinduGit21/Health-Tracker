# Health Tracker App Implementation Plan

## Overview
A high-performance Android application built with Flutter for tracking personal goals, specifically sugar intake and water consumption.

## Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod (for separation of concerns and testability)
- **Local Storage:** Hive (NoSQL, fast, lightweight) or Isar
- **Notifications:** flutter_local_notifications
- **Navigation:** go_router
- **UI Components:** Material 3, Google Fonts, Custom Painters for charts/progress
- **Web Integration:** Flutter Web (PWA), Supabase (Cloud Sync)

## Architecture
We will follow a Feature-first architecture:
```
lib/
  src/
    features/
      authentication/
      onboarding/
      dashboard/
      goals/
      shared/
    common_widgets/
    constants/
    utils/
    routing/
  main.dart
```

## detailed Feature Implementation

### 1. User Account Management
- **Description:** Registration and Login.
- **Implementation:** 
  - UI: Login Screen, Sign Up Screen.
  - Logic: `AuthRepository` interface. For immediate usage, we will implement a mock repository or integration with Firebase Auth if configuration allows.
  - Security: Secure storage for tokens/credentials (`flutter_secure_storage`).

### 2. Onboarding Process
- **Description:** Guide new users.
- **Implementation:** 
  - Library: `introduction_screen` or custom `PageView`.
  - Content: Slide 1 (Welcome), Slide 2 (Sugar Tracking importance), Slide 3 (Hydration importance), Slide 4 (Set initial goals).
  - Logic: Show only on first launch (persisted flag in SharedPreferences/Hive).

### 3. Dashboard (Done)
- **Description:** Overview of daily stats.
- **UI:** creates a modern, glassmorphic card layout.
- **Widgets:** 
  - Circular Progress Indicator for Water (mL tracked vs Goal).
  - Linear Progress/Bar Chart for Sugar (grams).
  - "Quick Add" floating action buttons or bottom sheet.
  - **History Mode:** View all past logs.

### 4. Goal Tracking (Done)
- **Description:** Set and update goals.
- **Implementation:**
  - Data Modeling: `Goal` class (type, targetValue, date).
  - Storage: Hive box `goals`.
  - UI: Settings page or specialized Goal Set modal.
  - **Sugar Modes:** Added/Total sugar tracking toggle.

### 5. Notifications & Reminders (Done)
- **Description:** Reminders to log data.
- **Implementation:**
  - Scheduled local notifications.
  - **Customization:** User can set Start Time, End Time, and Interval.
  - **Intelligent:** Reminders reset (delay) when user manually logs water.
  - Action buttons in notifications to logging directly (if supported) or open app.
  
### 6. Body Weight Tracking (Done)
- **Description:** Track daily or weekly body weight.
- **Implementation:**
  - Storage: Hive box `weight_logs`.
  - UI: Weight Card on Dashboard, Weight Journey screen with charts.
  - Features: Progress visualization, Target Weight comparison, Highlight when target reached or "low" weight detected.

### 7. Unified Web & Cloud Sync (Work in Progress)
- **Objective:** Combine Flutter App and JS Website into one unified codebase.
- **Ported Features:**
  - [x] Workout tracking (Done)
  - [x] Activity Streaks (Done)
  - [x] 7-Day Sugar Challenge (Done)
  - [x] PDF Report Generation (Done)
- **Synchronization:**
  - Transition from Hive (Local) to Supabase (Cloud) for real-time sync between Mobile and Web.
  - Automatic data refresh when logging on any device.

### 8. Performance & Optimization
- **Best Practices:** 
  - Use `const` constructors.
  - Lazy loading for lists.
  - Efficient state updates (Riverpod `select`).
  - Rendering optimization (avoid transparency over-draws where not needed).

### 7. User Interface (UI)
- **Theme:** 
  - Primary Color: Teal/Cyan (Hydration).
  - Secondary Color: Pink/Purple (Sugar/Action).
  - Font: 'Outfit' or 'Poppins'.
  - Dark Mode support.

## Next Steps
1. Initialize Flutter project.
2. Add dependencies.
3. Setup project structure.
4. Implement Onboarding (First entry point).
5. Implement Dashboard Skeleton.
