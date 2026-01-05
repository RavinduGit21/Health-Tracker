import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'onboarding_repository.dart';
import '../../constants/app_colors.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: IntroductionScreen(
        pages: [
          PageViewModel(
            title: "Welcome to Health Tracker",
            body: "Your personal companion for a healthier lifestyle.",
            image: const Icon(Icons.health_and_safety, size: 100, color: AppColors.primary),
            decoration: _pageDecoration(),
          ),
          PageViewModel(
            title: "Track Sugar Intake",
            body: "Monitor your daily sugar consumption to stay within healthy limits.",
            image: const Icon(Icons.cake, size: 100, color: AppColors.secondary),
            decoration: _pageDecoration(),
          ),
          PageViewModel(
            title: "Stay Hydrated",
            body: "Keep track of your water intake and reach your hydration goals.",
            image: const Icon(Icons.water_drop, size: 100, color: Colors.blueAccent),
            decoration: _pageDecoration(),
          ),
        ],
        onDone: () => _onIntroEnd(context, ref),
        onSkip: () => _onIntroEnd(context, ref),
        showSkipButton: true,
        skip: const Text("Skip", style: TextStyle(fontWeight: FontWeight.w600)),
        next: const Icon(Icons.arrow_forward),
        done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
        dotsDecorator: DotsDecorator(
          size: const Size.square(10.0),
          activeSize: const Size(20.0, 10.0),
          activeColor: AppColors.primary,
          color: Colors.black26,
          spacing: const EdgeInsets.symmetric(horizontal: 3.0),
          activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0)),
        ),
      ),
    );
  }

  void _onIntroEnd(BuildContext context, WidgetRef ref) async {
    final onboardingRepo = ref.read(onboardingRepositoryProvider);
    await onboardingRepo.setOnboardingComplete();
    if (context.mounted) {
      context.go('/login'); // Navigate to login after onboarding
    }
  }

  PageDecoration _pageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: TextStyle(fontSize: 19.0),
      imagePadding: EdgeInsets.all(24),
      pageColor: AppColors.backgroundDark,
    );
  }
}
