import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/rewarded_ad_manager.dart';
import '../services/subscription_service.dart';
import '../config/premium_config.dart';
import '../config/grades.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

/// How a question set can be opened.
enum _Access { open, ad, premium }

class BucketSelectionScreen extends StatefulWidget {
  const BucketSelectionScreen({super.key});

  @override
  State<BucketSelectionScreen> createState() => _BucketSelectionScreenState();
}

class _BucketSelectionScreenState extends State<BucketSelectionScreen> {
  Future<({List<Bucket> buckets, Set<String> unlockedIds})>? _dataFuture;
  bool _argsLoaded = false;

  int _grade = 10;
  String _subjectId = '';
  String _subjectName = 'Subject';
  String? _medium;
  String _userId = 'guest';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _grade = args?['grade'] ?? 10;
      _subjectId = args?['subjectId'] ?? '';
      _subjectName = args?['subjectName'] ?? 'Subject';
      _medium = args?['medium'] as String?;
      _userId = AppState.currentUid ?? AppState.currentUsername ?? 'guest';
      _argsLoaded = true;
      _loadData();
    }
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<({List<Bucket> buckets, Set<String> unlockedIds})> _fetchData() async {
    final service = FirestoreService();
    final results = await Future.wait([
      service.getBuckets(_subjectId, _grade, medium: _medium),
      service.getUnlockedSetIds(_userId),
    ]);
    return (
      buckets: results[0] as List<Bucket>,
      unlockedIds: results[1] as Set<String>,
    );
  }

  String _setKeyFor(Bucket bucket) => '${_grade}_${_subjectId}_${_medium ?? "all"}_${bucket.id}';

  void _openBucket(Bucket bucket) {
    final displayTag = _subjectId.isNotEmpty ? _subjectName : '${_medium ?? "All"} Medium';
    Navigator.pushNamed(
      context,
      '/quiz',
      arguments: {
        'grade': _grade,
        'subjectId': _subjectId,
        'subjectName': displayTag,
        'medium': _medium,
        'bucketId': bucket.id,
        'bucketName': bucket.name,
      },
    );
  }

  /// Set 1 is free, set 2 unlocks with a rewarded ad, later sets need
  /// Premium for this grade. Sets already unlocked with an ad stay unlocked.
  _Access _accessFor(int index, Bucket bucket, Set<String> unlockedIds) {
    if (index == 0 ||
        SubscriptionService.instance.hasGrade(_grade) ||
        unlockedIds.contains(_setKeyFor(bucket))) {
      return _Access.open;
    }
    return index < PremiumConfig.freeSetsPerSubject ? _Access.ad : _Access.premium;
  }

  Future<void> _openPaywall() async {
    await Navigator.pushNamed(context, '/premium', arguments: {'grade': _grade});
  }

  void _onLockedBucketTap(Bucket bucket) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(icon: Icons.lock_open_rounded, color: AppColors.warning, size: 64),
              const SizedBox(height: 20),
              Text(
                'Unlock ${bucket.name}',
                textAlign: TextAlign.center,
                style: AppText.title(),
              ),
              const SizedBox(height: 8),
              Text(
                'Watch a short ad to unlock this question set permanently.',
                textAlign: TextAlign.center,
                style: AppText.body(),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Watch ad',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _watchAdToUnlock(bucket);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Not now', style: AppText.style(weight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _watchAdToUnlock(Bucket bucket) {
    RewardedAdManager.instance.showAd(
      onUserEarnedReward: () async {
        await FirestoreService().unlockSet(_userId, _setKeyFor(bucket));
        if (!mounted) return;
        _loadData();
        _openBucket(bucket);
      },
      onAdUnavailable: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not ready yet, please try again in a moment.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayTag = _subjectId.isNotEmpty ? _subjectName : '${_medium ?? "All"} Medium';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context, title: 'Question sets'),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: StepProgress(step: 3, total: 5),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeSlideIn(
                  child: PageHeader(
                    overline: displayTag,
                    title: 'Pick a\nquestion set',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListenableBuilder(
                  listenable: SubscriptionService.instance,
                  builder: (context, _) => FutureBuilder<({List<Bucket> buckets, Set<String> unlockedIds})>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoader();
                    }
                    if (snapshot.hasError) {
                      return EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Unable to load question sets',
                        action: SizedBox(
                          width: 160,
                          child: GlassButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: _loadData, height: 48),
                        ),
                      );
                    }

                    final buckets = snapshot.data?.buckets ?? [];
                    final unlockedIds = snapshot.data?.unlockedIds ?? {};
                    if (buckets.isEmpty) {
                      return const EmptyState(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Nothing here yet',
                        subtitle: 'No question sets available yet.',
                      );
                    }

                    final access = [
                      for (var i = 0; i < buckets.length; i++) _accessFor(i, buckets[i], unlockedIds),
                    ];
                    final showPromo = access.contains(_Access.premium);

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      itemCount: buckets.length + (showPromo ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (showPromo && index == 0) {
                          return FadeSlideIn(child: _PremiumPromo(grade: _grade, onTap: _openPaywall));
                        }
                        final i = showPromo ? index - 1 : index;
                        final bucket = buckets[i];
                        return FadeSlideIn(
                          index: index,
                          child: _BucketCard(
                            bucket: bucket,
                            index: i,
                            access: access[i],
                            onTap: () => switch (access[i]) {
                              _Access.open => _openBucket(bucket),
                              _Access.ad => _onLockedBucketTap(bucket),
                              _Access.premium => _openPaywall(),
                            },
                          ),
                        );
                      },
                    );
                  },
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

class _BucketCard extends StatelessWidget {
  final Bucket bucket;
  final int index;
  final _Access access;
  final VoidCallback onTap;

  const _BucketCard({
    required this.bucket,
    required this.index,
    required this.access,
    required this.onTap,
  });

  bool get locked => access != _Access.open;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accentAt(index);
    final premiumLocked = access == _Access.premium;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      strength: locked ? 0.6 : 1,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconBadge(
                icon: premiumLocked
                    ? Icons.workspace_premium_rounded
                    : locked
                        ? Icons.lock_rounded
                        : Icons.layers_rounded,
                color: color,
                size: 56,
                muted: locked,
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassStroke),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: AppText.style(size: 11, weight: FontWeight.w800),
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
                  bucket.name,
                  style: AppText.style(
                    size: 16,
                    weight: FontWeight.w700,
                    spacing: -0.2,
                    color: locked ? AppColors.textSecondary : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      label: '${bucket.questionCount} questions',
                      color: locked ? Colors.white : color,
                      icon: Icons.format_list_bulleted_rounded,
                    ),
                    if (access == _Access.ad)
                      const Pill(
                        label: 'Watch ad',
                        color: AppColors.warning,
                        icon: Icons.play_circle_outline_rounded,
                      ),
                    if (premiumLocked) const PremiumBadge(compact: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: locked ? 18 : 24,
          ),
        ],
      ),
    );
  }
}

class _PremiumPromo extends StatelessWidget {
  final int grade;
  final VoidCallback onTap;
  const _PremiumPromo({required this.grade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      accent: PremiumStyle.gold,
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
                Text('Unlock all ${Grades.label(grade)} sets', style: AppText.style(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  Grades.isEbExam(grade)
                      ? 'Premium for ${PremiumConfig.fallbackPrices[PremiumPlan.lifetime]} one-time · no ads'
                      : 'Premium from ${PremiumConfig.fallbackPrices[PremiumPlan.monthly]} / month · no ads',
                  style: AppText.style(size: 12, color: PremiumStyle.goldLight),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: PremiumStyle.goldLight),
        ],
      ),
    );
  }
}
