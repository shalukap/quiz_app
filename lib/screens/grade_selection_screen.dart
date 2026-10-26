import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/app_open_ad_manager.dart';
import '../services/subscription_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';
import '../services/analytics_service.dart';
import '../config/grades.dart';

class GradeSelectionScreen extends StatefulWidget {
  const GradeSelectionScreen({super.key});

  @override
  State<GradeSelectionScreen> createState() => _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends State<GradeSelectionScreen> {
  int _selectedNav = 0;
  Future<List<int>>? _activeGradesFuture;
  Future<UserProfile?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _activeGradesFuture = FirestoreService().getActiveGrades();
    _profileFuture = AppState.currentUid != null
        ? FirestoreService().getUserProfileByUid(AppState.currentUid!)
        : null;
  }

  void _onGradeTap(int grade) {
    AppOpenAdManager.instance.showAdIfAvailable();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (context) {
        return _MediumSelectionSheet(
          grade: grade,
          onMediumSelected: (medium) {
            AnalyticsService.instance.setStudyProfile(grade: grade, medium: medium);
            Navigator.pop(context);
            Navigator.pushNamed(
              context,
              '/subjects',
              arguments: {
                'grade': grade,
                'medium': medium,
              },
            );
          },
        );
      },
    );
  }

  void _onEbExamsTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (sheetContext) => _EbExamSheet(
        onExamSelected: (grade) {
          Navigator.pop(sheetContext);
          _onGradeTap(grade);
        },
      ),
    );
  }

  Future<void> _onNavTap(int i) async {
    if (i == 0) return;
    setState(() => _selectedNav = i);
    final navigator = Navigator.of(context);
    if (i == 1) await navigator.pushNamed('/leaderboard');
    if (i == 2) await navigator.pushNamed('/saved');
    if (i == 3) await navigator.pushNamed('/profile');
    if (mounted) {
      setState(() => _selectedNav = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    PremiumScope.watch(context);
    final name = AppState.currentUsername;
    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _buildTopBar(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: FadeSlideIn(
                  child: PageHeader(
                    overline: name != null && name.isNotEmpty ? 'Hi, $name 👋' : 'Welcome 👋',
                    title: 'Choose your\ngrade',
                    subtitle: 'Pick a level to start practicing',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<int>>(
                  future: _activeGradesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoader();
                    }
                    final activeGrades = snapshot.data ?? [];
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                          sliver: SliverToBoxAdapter(
                            child: FadeSlideIn(child: _EbExamsCard(onTap: _onEbExamsTap)),
                          ),
                        ),
                        if (snapshot.hasError)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Error loading grades',
                              subtitle: 'Check your connection and try again.',
                            ),
                          )
                        else if (activeGrades.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.school_outlined,
                              title: 'No grades yet',
                              subtitle: 'No grades with questions found.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            sliver: SliverGrid.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: activeGrades.length,
                              itemBuilder: (context, index) {
                                final grade = activeGrades[index];
                                return FadeSlideIn(
                                  index: index + 1,
                                  child: _GradeTile(
                                    grade: grade,
                                    color: AppColors.accentAt(index),
                                    onTap: () => _onGradeTap(grade),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FloatingNavBar(currentIndex: _selectedNav, onTap: _onNavTap),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppGradients.progress,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Text('QuizMaster', style: AppText.style(size: 18, weight: FontWeight.w800, spacing: -0.4)),
        const SizedBox(width: 8),
        if (SubscriptionService.instance.isPremium)
          const PremiumBadge(compact: true)
        else if (SubscriptionService.instance.isAvailable)
          Pressable(
            onTap: () => Navigator.pushNamed(context, '/premium'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: PremiumStyle.gold.withValues(alpha: 0.7)),
                color: PremiumStyle.gold.withValues(alpha: 0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 13, color: PremiumStyle.goldLight),
                  const SizedBox(width: 4),
                  Text('Go Premium',
                      style: AppText.style(size: 10.5, weight: FontWeight.w800, color: PremiumStyle.goldLight)),
                ],
              ),
            ),
          ),
        const Spacer(),
        Pressable(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: FutureBuilder<UserProfile?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final photoUrl = snapshot.data?.photoUrl;
              return Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.primary,
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: AppColors.bgElevated,
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          )
                        : const Icon(Icons.person_rounded, color: Colors.white70, size: 22),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GradeTile extends StatelessWidget {
  final int grade;
  final Color color;
  final VoidCallback onTap;

  const _GradeTile({required this.grade, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Accent glow in the corner
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: Icons.school_rounded, color: color, size: 40),
                const Spacer(),
                Text(
                  grade.toString().padLeft(2, '0'),
                  style: AppText.style(size: 40, weight: FontWeight.w800, spacing: -1.5, height: 1),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'GRADE $grade',
                      style: AppText.style(
                        size: 11,
                        weight: FontWeight.w800,
                        spacing: 1.2,
                        color: Color.lerp(color, Colors.white, 0.35),
                      ),
                    ),
                    const Spacer(),
                    SubscriptionService.instance.hasGrade(grade)
                        ? const Icon(Icons.workspace_premium_rounded, size: 18, color: PremiumStyle.gold)
                        : Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EbExamsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EbExamsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = PremiumStyle.gold;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const IconBadge(icon: Icons.emoji_events_rounded, color: color, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EB Exams', style: AppText.style(size: 18, weight: FontWeight.w800, spacing: -0.3)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final grade in Grades.ebExams) Pill(label: Grades.label(grade), color: color),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _EbExamSheet extends StatelessWidget {
  final ValueChanged<int> onExamSelected;

  const _EbExamSheet({required this.onExamSelected});

  static const _colors = [AppColors.primary, AppColors.violet, AppColors.pink];

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EB Exams', style: AppText.style(size: 22, weight: FontWeight.w800, spacing: -0.5)),
          const SizedBox(height: 4),
          Text('Choose your exam', style: AppText.body(color: AppColors.textMuted)),
          const SizedBox(height: 22),
          for (final (index, grade) in Grades.ebExams.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            _MediumOptionTile(
              title: Grades.label(grade),
              subtitle: '${Grades.label(grade)} exam practice papers',
              icon: Icons.emoji_events_rounded,
              color: _colors[index % _colors.length],
              onTap: () => onExamSelected(grade),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MediumSelectionSheet extends StatelessWidget {
  final int grade;
  final ValueChanged<String> onMediumSelected;

  const _MediumSelectionSheet({
    required this.grade,
    required this.onMediumSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select medium', style: AppText.style(size: 22, weight: FontWeight.w800, spacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Choose the instruction language', style: AppText.body(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Pill(label: Grades.label(grade), color: AppColors.cyan),
            ],
          ),
          const SizedBox(height: 22),
          _MediumOptionTile(
            title: 'English Medium',
            subtitle: 'English language subjects & quizzes',
            icon: Icons.language_rounded,
            color: AppColors.primary,
            onTap: () => onMediumSelected('English'),
          ),
          const SizedBox(height: 12),
          _MediumOptionTile(
            title: 'Sinhala Medium',
            subtitle: 'සිංහල මාධ්‍යය ප්‍රශ්න පත්‍ර සහ පාඩම්',
            icon: Icons.translate_rounded,
            color: AppColors.violet,
            onTap: () => onMediumSelected('Sinhala'),
          ),
          const SizedBox(height: 12),
          _MediumOptionTile(
            title: 'Tamil Medium',
            subtitle: 'தமிழ் மொழி வினாக்கள் மற்றும் பாடங்கள்',
            icon: Icons.g_translate_rounded,
            color: AppColors.pink,
            onTap: () => onMediumSelected('Tamil'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MediumOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MediumOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: AppRadius.md + 2,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.style(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
