import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:health_tracker/src/constants/app_colors.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    
    int currentIndex = 0;
    if (location.startsWith('/dashboard')) currentIndex = 0;
    else if (location.startsWith('/history')) currentIndex = 1;
    else if (location.startsWith('/weight')) currentIndex = 2;
    else if (location.startsWith('/sleep')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/history');
              break;
            case 2:
              context.go('/weight');
              break;
            case 3:
              context.go('/sleep');
              break;
          }
        },
        backgroundColor: AppColors.backgroundDark,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppColors.primary),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight, color: AppColors.primary),
            label: 'Weight',
          ),
          NavigationDestination(
            icon: Icon(Icons.nightlight_outlined),
            selectedIcon: Icon(Icons.nightlight_round, color: AppColors.primary),
            label: 'Sleep',
          ),
        ],
      ),
    );
  }
}
