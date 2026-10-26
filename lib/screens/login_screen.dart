import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';
import '../services/app_open_ad_manager.dart';
import '../state/app_state.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';
import '../services/analytics_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRedirectResult();
  }

  Future<void> _checkRedirectResult() async {
    if (!kIsWeb) return;

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.getRedirectResult();
      final User? user = userCredential.user;

      if (user != null) {
        setState(() => _isLoading = true);
        final db = FirestoreService();
        final username = user.displayName ?? user.email?.split('@')[0] ?? 'GoogleUser';
        
        var profile = await db.getUserProfileByUid(user.uid);
        if (profile == null) {
          await db.createUserProfile(username, email: user.email, uid: user.uid, photoUrl: user.photoURL);
        } else if (user.photoURL != null && profile.photoUrl != user.photoURL) {
          // Update photo if it changed or was missing
          await db.updateUserProfilePhoto(user.uid, user.photoURL!);
        }
        AppState.currentUsername = username;
        AppState.currentUid = user.uid;
        await SubscriptionService.instance.identify(user.uid);
        await AnalyticsService.instance.setUser(user.uid);
        profile == null
            ? await AnalyticsService.instance.logSignUp('google')
            : await AnalyticsService.instance.logLogin('google');

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/grade');
        }
      }
    } catch (e) {
      debugPrint('Redirect Auth Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirestoreService();
      
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Failed to retrieve user ID");

      var profile = await db.getUserProfileByUid(uid);
      
      if (profile != null) {
        AppState.currentUsername = profile.username;
        AppState.currentUid = uid;
      } else {
        final username = email.split('@')[0];
        AppState.currentUsername = username;
        AppState.currentUid = uid;
      }
      await SubscriptionService.instance.identify(uid);
      await AnalyticsService.instance.setUser(uid);
      await AnalyticsService.instance.logLogin('email');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/grade');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email to reset password')),
        );
      }
      return;
    }
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset Error: $e')),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        try {
          userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
        } catch (e) {
          debugPrint('Popup sign-in failed/unimplemented, falling back to redirect: $e');
          await FirebaseAuth.instance.signInWithRedirect(provider);
          return;
        }
      } else {
        // The account chooser briefly backgrounds the app; don't let that
        // resume trigger an app-open ad on top of it.
        AppOpenAdManager.instance.suppressNextShow = true;
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;
        final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user != null) await _completeSocialSignIn(user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      AppOpenAdManager.instance.suppressNextShow = true;
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final userCredential = await FirebaseAuth.instance.signInWithProvider(provider);
      final User? user = userCredential.user;
      if (user != null) await _completeSocialSignIn(user, fallbackName: 'Student');
    } on FirebaseAuthException catch (e) {
      // User closed the Apple sheet.
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple Sign-In Error: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple Sign-In Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Creates/updates the Firestore profile after Google or Apple sign-in
  /// and opens the app.
  Future<void> _completeSocialSignIn(User user, {String fallbackName = 'GoogleUser'}) async {
    final db = FirestoreService();
    final displayName = user.displayName?.trim();
    final username = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : user.email?.split('@')[0] ?? fallbackName;

    var profile = await db.getUserProfileByUid(user.uid);
    if (profile == null) {
      await db.createUserProfile(username, email: user.email, uid: user.uid, photoUrl: user.photoURL);
    } else if (user.photoURL != null && profile.photoUrl != user.photoURL) {
      // Update photo if it changed or was missing
      await db.updateUserProfilePhoto(user.uid, user.photoURL!);
    }
    AppState.currentUsername = username;
    AppState.currentUid = user.uid;
    await SubscriptionService.instance.identify(user.uid);
    final method = user.providerData.isNotEmpty ? user.providerData.first.providerId : 'social';
    await AnalyticsService.instance.setUser(user.uid);
    profile == null
        ? await AnalyticsService.instance.logSignUp(method)
        : await AnalyticsService.instance.logLogin(method);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/grade');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  FadeSlideIn(index: 0, child: _buildBrand()),
                  const SizedBox(height: 32),
                  FadeSlideIn(index: 1, child: _buildGlassCard()),
                  const SizedBox(height: 28),
                  FadeSlideIn(index: 2, child: _buildFooter()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: AppGradients.progress,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 48,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(29),
              child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('QuizMaster', style: AppText.style(size: 30, weight: FontWeight.w800, spacing: -1)),
            const SizedBox(width: 10),
            const Pill(label: 'v1.2.5', color: AppColors.cyan, uppercase: false),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return GlassCard(
      blur: true,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back 👋', style: AppText.style(size: 24, weight: FontWeight.w800, spacing: -0.5)),
          const SizedBox(height: 6),
          Text('Access your personalized question bank', style: AppText.body()),
          const SizedBox(height: 28),
          _buildInputField(
            label: 'Email',
            controller: _emailController,
            hint: 'name@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Password',
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: AppText.style(size: 13, weight: FontWeight.w600, color: AppColors.primaryLight),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Log in',
            icon: Icons.arrow_forward_rounded,
            loading: _isLoading,
            onPressed: _isLoading ? null : _handleLogin,
          ),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          GlassButton(
            label: 'Continue with Google',
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('assets/images/google_logo.png', height: 18, width: 18),
            ),
          ),
          if (_showAppleSignIn) ...[
            const SizedBox(height: 12),
            _buildAppleButton(),
          ],
        ],
      ),
    );
  }

  bool get _showAppleSignIn => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Follows Apple's button guidelines: white background, black Apple logo.
  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleAppleSignIn,
        icon: const Icon(Icons.apple, size: 24),
        label: Text(
          'Sign in with Apple',
          style: AppText.style(size: 15, weight: FontWeight.w600, color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.style(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppText.style(size: 15, weight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.glassStroke)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: AppText.style(size: 11, weight: FontWeight.w700, spacing: 1.4, color: AppColors.textFaint),
          ),
        ),
        Expanded(child: Divider(color: AppColors.glassStroke)),
      ],
    );
  }

  Widget _buildFooter() {
    return RichText(
      text: TextSpan(
        style: AppText.style(size: 14, color: AppColors.textMuted),
        children: [
          const TextSpan(text: "Don't have an account? "),
          TextSpan(
            text: 'Sign up',
            style: AppText.style(size: 14, weight: FontWeight.w800, color: AppColors.cyan),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.pushNamed(context, '/register'),
          ),
        ],
      ),
    );
  }
}
