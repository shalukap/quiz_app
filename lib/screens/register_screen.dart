import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../state/app_state.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';
import '../services/analytics_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Failed to get User ID from registration");

      final db = FirestoreService();
      await db.createUserProfile(username, email: email, uid: uid);
      
      AppState.currentUsername = username;
      AppState.currentUid = uid;
      await SubscriptionService.instance.identify(uid);
      await AnalyticsService.instance.setUser(uid);
      await AnalyticsService.instance.logSignUp('email');
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/grade');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context),
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FadeSlideIn(
                  child: PageHeader(
                    overline: 'Get started',
                    title: 'Create your\naccount',
                    subtitle: 'Join the community of learners',
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  index: 1,
                  child: GlassCard(
                    blur: true,
                    radius: AppRadius.xl,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Choose a username',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _emailController,
                          label: 'Email address',
                          hint: 'yourname@example.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Create a password',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _confirmPasswordController,
                          label: 'Confirm password',
                          hint: 'Re-enter your password',
                          icon: Icons.lock_reset_rounded,
                          isPassword: true,
                          obscureText: _obscurePassword,
                        ),
                        const SizedBox(height: 28),
                        GradientButton(
                          label: 'Create account',
                          icon: Icons.arrow_forward_rounded,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _handleRegister,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
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
            suffixIcon: isPassword && onToggleVisibility != null
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
}
