import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  static const _onboardingCompleteKey = 'onboardingComplete';
  final SharedPreferences _sharedPreferences;

  OnboardingRepository(this._sharedPreferences);

  Future<void> setOnboardingComplete() async {
    await _sharedPreferences.setBool(_onboardingCompleteKey, true);
  }

  bool isOnboardingComplete() {
    return _sharedPreferences.getBool(_onboardingCompleteKey) ?? false;
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  throw UnimplementedError('Provider was not initialized');
});
