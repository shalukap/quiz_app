import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/ad_helper.dart';
import 'services/interstitial_ad_manager.dart';
import 'services/app_open_ad_manager.dart';
import 'services/rewarded_ad_manager.dart';
import 'services/subscription_service.dart';
import 'services/analytics_service.dart';
import 'widgets/glass_ui.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/grade_selection_screen.dart';
import 'screens/subject_selection_screen.dart';
import 'screens/mcq_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/review_answers_screen.dart';
import 'screens/bucket_selection_screen.dart';
import 'screens/quiz_history_screen.dart';
import 'screens/saved_questions_screen.dart';
import 'screens/premium_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Google Sign-In (Native only)
  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (e) {
      debugPrint('Google Sign-In failed to initialize: $e');
    }
  }

  // QuizMaster Premium (RevenueCat). Keeps the gold premium style in sync.
  final subscriptions = SubscriptionService.instance;
  subscriptions.addListener(() => PremiumStyle.active = subscriptions.isPremium);
  await subscriptions.init();

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    await AdHelper.configure();
    InterstitialAdManager.instance.loadAd();
    AppOpenAdManager.instance.loadAd();
    RewardedAdManager.instance.loadAd();
    AppOpenLifecycleReactor().listen();
  }

  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Question Bank',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) => PremiumScope(child: child ?? const SizedBox.shrink()),
      navigatorObservers: [AnalyticsService.instance.observer],
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/grade': (context) => const GradeSelectionScreen(),
        '/subjects': (context) => const SubjectSelectionScreen(),
        '/buckets': (context) => const BucketSelectionScreen(),
        '/quiz': (context) => const McqScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/review_answers': (context) => const ReviewAnswersScreen(),
        '/history': (context) => const QuizHistoryScreen(),
        '/saved': (context) => const SavedQuestionsScreen(),
        '/premium': (context) => const PremiumScreen(),
      },
    );
  }
}
