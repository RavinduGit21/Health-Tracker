import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:health_tracker/src/features/authentication/login_screen.dart';
import 'package:health_tracker/src/features/authentication/signup_screen.dart';
import 'package:health_tracker/src/features/dashboard/dashboard_screen.dart';
import 'package:health_tracker/src/features/goals/goals_screen.dart';
import 'package:health_tracker/src/features/history/history_screen.dart';
import 'package:health_tracker/src/features/history/statistics_screen.dart';
import 'package:health_tracker/src/features/onboarding/onboarding_screen.dart';
import 'package:health_tracker/src/features/weight/weight_screen.dart';

import 'package:health_tracker/src/common_widgets/main_layout.dart';

final goRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/weight',
          builder: (context, state) => const WeightScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/goals',
      builder: (context, state) => const GoalsScreen(),
    ),
    GoRoute(
      path: '/statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),
  ],
);

