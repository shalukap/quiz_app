import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/account_service.dart';
import '../services/app_open_ad_manager.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';
import '../services/subscription_service.dart';
import '../config/premium_config.dart';
import '../config/grades.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;
  String? _temporaryPhotoUrl;

  Future<void> _confirmDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final needsPassword = AccountService.reauthMethodFor(user) == ReauthMethod.password;
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(icon: Icons.delete_forever_rounded, color: AppColors.danger, size: 64),
              const SizedBox(height: 20),
              Text('Delete account?', textAlign: TextAlign.center, style: AppText.title()),
              const SizedBox(height: 8),
              Text(
                'This permanently deletes your account, profile, quiz history, saved questions '
                'and unlocked sets. This cannot be undone.\n\n'
                'Active Premium subscriptions are not cancelled automatically. '
                '${PremiumConfig.cancelInstructions}',
                textAlign: TextAlign.center,
                style: AppText.body(),
              ),
              if (needsPassword) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  style: AppText.style(size: 15, weight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Enter your password to confirm',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                label: 'Delete permanently',
                icon: Icons.delete_forever_rounded,
                gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFDC2626)]),
                glowColor: AppColors.danger,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Cancel', style: AppText.style(weight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
    final password = passwordController.text;
    passwordController.dispose();
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      await AccountService.deleteAccount(password: needsPassword ? password : null);
      messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Incorrect password. Account not deleted.',
        'canceled' || 'web-context-canceled' => 'Sign-in cancelled. Account not deleted.',
        _ => 'Could not delete account: ${e.message ?? e.code}',
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Picking an image briefly backgrounds the app on some platforms;
      // don't let that resume trigger an app-open ad on top of the picker.
      AppOpenAdManager.instance.suppressNextShow = true;
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        await _uploadImage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(File image) async {
    setState(() => _isUploading = true);

    try {
      final uid = AppState.currentUid;
      if (uid == null) throw Exception('User ID not found');
      
      final extension = path.extension(image.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$uid$extension');

      // Upload file
      await storageRef.putFile(image);
      
      // Get download URL
      final photoUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirestoreService().updateUserProfilePhoto(uid, photoUrl);

      setState(() {
        _temporaryPhotoUrl = photoUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update photo', style: AppText.title()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    child: Column(
                      children: [
                        const IconBadge(icon: Icons.camera_alt_rounded, color: AppColors.primary, size: 48),
                        const SizedBox(height: 10),
                        Text('Camera', style: AppText.style(weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    child: Column(
                      children: [
                        const IconBadge(icon: Icons.photo_library_rounded, color: AppColors.violet, size: 48),
                        const SizedBox(height: 10),
                        Text('Gallery', style: AppText.style(weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: 'My profile',
        actions: [
          GlassIconButton(icon: Icons.settings_outlined, size: 40, onTap: () {}),
        ],
      ),
      body: AuroraBackground(
        child: FutureBuilder(
          future: Future.wait([
            FirestoreService().getUserProfile(AppState.currentUsername ?? 'guest'),
            FirestoreService().getRecentResults(AppState.currentUsername ?? 'guest'),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoader();
            }

            final profile = snapshot.data?[0] as UserProfile?;
            final recentResults = (snapshot.data?[1] as List<QuizResult>?) ?? [];

            final username = profile?.username ?? 'Guest User';

            // Group results by grade and calculate stats
            final Map<int, List<QuizResult>> groupedResults = {};
            for (var result in recentResults) {
              groupedResults.putIfAbsent(result.grade, () => []).add(result);
            }
            final sortedGrades = groupedResults.keys.toList()..sort((a, b) => b.compareTo(a));

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    FadeSlideIn(child: _buildProfileHeader(username, profile?.photoUrl)),
                    const SizedBox(height: 28),

                    if (sortedGrades.isEmpty)
                      _buildEmptyState()
                    else
                      ...sortedGrades.asMap().entries.map((entry) {
                        final grade = entry.value;
                        final results = groupedResults[grade]!;
                        final quizzesCount = results.length;
                        final totalPoints = results.fold(0, (sum, r) => sum + (r.score * 10));
                        final avgAccuracy =
                            (results.fold(0.0, (sum, r) => sum + r.percentage) / quizzesCount * 100).toStringAsFixed(0);

                        return FadeSlideIn(
                          index: entry.key + 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                                  child: SectionLabel('${Grades.label(grade)} performance', icon: Icons.insights_rounded),
                                ),
                                _buildStatsRow(
                                  quizzesCount.toString(),
                                  totalPoints.toString(),
                                  '$avgAccuracy%',
                                ),
                                const SizedBox(height: 12),
                                _GradeTrendChart(results: results, color: AppColors.primary),
                              ],
                            ),
                          ),
                        );
                      }),

                    _buildPremiumCard(),
                    const SizedBox(height: 12),
                    _buildMenuItems(context),
                    const SizedBox(height: 32),
                    _buildAppInfo(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String username, String? profilePhotoUrl) {
    final displayPhotoUrl = _temporaryPhotoUrl ?? profilePhotoUrl;

    return GlassCard(
      blur: true,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.progress,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    width: 84,
                    height: 84,
                    color: AppColors.bgElevated,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        displayPhotoUrl != null
                            ? Image.network(
                                displayPhotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person_rounded, size: 42, color: Colors.white38),
                              )
                            : const Icon(Icons.person_rounded, size: 42, color: Colors.white38),
                        if (_isUploading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Pressable(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgElevated, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(size: 22, weight: FontWeight.w800, spacing: -0.6),
                ),
                const SizedBox(height: 8),
                SubscriptionService.instance.isPremium
                    ? const PremiumBadge(label: 'Premium member')
                    : const Pill(label: 'Quiz enthusiast', color: AppColors.cyan, icon: Icons.auto_awesome_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String quizzes, String points, String accuracy) {
    return Row(
      children: [
        _StatCard(
          label: 'Quizzes',
          value: quizzes,
          icon: Icons.quiz_outlined,
          color: const Color(0xFF818CF8),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Points',
          value: points,
          icon: Icons.bolt_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Accuracy',
          value: accuracy,
          icon: Icons.track_changes_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 40),
            const SizedBox(height: 12),
            Text('No tests taken yet', style: AppText.style(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Your stats will show up here.', style: AppText.style(size: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard() {
    final subs = SubscriptionService.instance;
    return ListenableBuilder(
      listenable: subs,
      builder: (context, _) {
        if (!subs.isPremium) {
          return GlassCard(
            accent: PremiumStyle.gold,
            onTap: () => Navigator.pushNamed(context, '/premium'),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.gold,
                    boxShadow: [BoxShadow(color: PremiumStyle.gold.withValues(alpha: 0.5), blurRadius: 18)],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: PremiumStyle.onGold),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Go ${PremiumConfig.displayName}', style: AppText.style(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('All question sets, no ads, gold theme',
                          style: AppText.style(size: 12, color: PremiumStyle.goldLight)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: PremiumStyle.goldLight),
              ],
            ),
          );
        }

        final grades = subs.activeGrades.toList()..sort();
        return GlassCard(
          accent: PremiumStyle.gold,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(PremiumConfig.displayName, style: AppText.style(size: 16, weight: FontWeight.w800)),
                  const Spacer(),
                  const PremiumBadge(label: 'Active', compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in grades) Pill(label: Grades.label(g), color: PremiumStyle.gold, icon: Icons.check_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Manage',
                      icon: Icons.open_in_new_rounded,
                      height: 46,
                      onPressed: () => launchUrl(
                        Uri.parse(subs.managementUrl ?? 'https://play.google.com/store/account/subscriptions'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Add grade',
                      icon: Icons.add_rounded,
                      height: 46,
                      onPressed: () => Navigator.pushNamed(context, '/premium'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _MenuItem(
                icon: Icons.history_rounded,
                color: AppColors.primary,
                title: 'Quiz history',
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
              _MenuItem(
                icon: Icons.bookmark_outline_rounded,
                color: AppColors.warning,
                title: 'Saved questions',
                onTap: () => Navigator.pushNamed(context, '/saved'),
              ),
              _MenuItem(
                icon: Icons.notifications_none_rounded,
                color: AppColors.violet,
                title: 'Notifications',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                color: AppColors.cyan,
                title: 'Help center',
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _MenuItem(
            icon: Icons.logout_rounded,
            color: AppColors.danger,
            title: 'Sign out',
            isDestructive: true,
            onTap: () async {
              final navigator = Navigator.of(context);
              await SubscriptionService.instance.signOut();
              navigator.pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _MenuItem(
            icon: Icons.delete_forever_rounded,
            color: AppColors.danger,
            title: _isDeleting ? 'Deleting account…' : 'Delete account',
            isDestructive: true,
            onTap: _isDeleting ? () {} : _confirmDeleteAccount,
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            'QUIZMASTER',
            style: AppText.style(size: 12, weight: FontWeight.w800, spacing: 3, color: AppColors.textFaint),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.2.5',
            style: AppText.style(size: 11, weight: FontWeight.w600, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppText.style(size: 20, weight: FontWeight.w800, spacing: -0.5)),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.style(size: 11, weight: FontWeight.w600, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Color.lerp(color, Colors.white, 0.2), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppText.style(
                    size: 15,
                    weight: FontWeight.w600,
                    color: isDestructive ? AppColors.danger : Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive ? AppColors.danger.withValues(alpha: 0.5) : AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeTrendChart extends StatelessWidget {
  final List<QuizResult> results;
  final Color color;

  const _GradeTrendChart({required this.results, required this.color});

  @override
  Widget build(BuildContext context) {
    // Get last 10 results, oldest first
    final trendData = results.reversed.take(10).toList().reversed.toList();
    if (trendData.isEmpty) return const SizedBox();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      child: SizedBox(
        height: 130,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 50,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) {
                    if (value % 50 == 0) {
                      return Text(
                        '${value.toInt()}%',
                        style: AppText.style(size: 9, weight: FontWeight.w700, color: AppColors.textFaint),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (trendData.length - 1).toDouble().clamp(1, double.infinity),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: trendData.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), e.value.percentage * 100);
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.primary, AppColors.violet]),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: color,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
