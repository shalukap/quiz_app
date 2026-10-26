import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper over Firebase Analytics. Location, device and install data are
/// collected automatically; these are the app-specific events and properties.
/// Analytics failures are never allowed to break the app.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Logs a screen_view for every named route push/pop.
  late final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Analytics failed: $e');
    }
  }

  Future<void> setUser(String uid) => _run(() => _analytics.setUserId(id: uid));

  Future<void> logLogin(String method) => _run(() => _analytics.logLogin(loginMethod: method));

  Future<void> logSignUp(String method) => _run(() => _analytics.logSignUp(signUpMethod: method));

  /// Stored on the user so every report can be filtered by grade and medium.
  Future<void> setStudyProfile({required int grade, String? medium}) => _run(() async {
        await _analytics.setUserProperty(name: 'grade', value: '$grade');
        if (medium != null) await _analytics.setUserProperty(name: 'medium', value: medium);
      });

  Future<void> logQuizCompleted({
    required int grade,
    required String subjectName,
    String? medium,
    required int score,
    required int totalQuestions,
  }) =>
      _run(() => _analytics.logEvent(name: 'quiz_completed', parameters: {
            'grade': grade,
            'subject': subjectName,
            'medium': medium ?? 'unknown',
            'score': score,
            'total_questions': totalQuestions,
            'score_percent': totalQuestions == 0 ? 0 : (score * 100 ~/ totalQuestions),
          }));
}
