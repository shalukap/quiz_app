import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/rewarded_ad_manager.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

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

  void _onLockedBucketTap(Bucket bucket) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unlock ${bucket.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Text(
          'Watch a short ad to unlock this question set permanently.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () {
              Navigator.pop(dialogContext);
              _watchAdToUnlock(bucket);
            },
            child: Text('Watch Ad', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'QuizMaster',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildProgressSection(),
                const SizedBox(height: 32),
                _buildHeader(displayTag),
                const SizedBox(height: 24),
                Expanded(
                  child: FutureBuilder<({List<Bucket> buckets, Set<String> unlockedIds})>(
                    future: _dataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 48, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text('Unable to load question sets',
                                  style: GoogleFonts.inter(color: Colors.white70)),
                            ],
                          ),
                        );
                      }

                      final buckets = snapshot.data?.buckets ?? [];
                      final unlockedIds = snapshot.data?.unlockedIds ?? {};
                      if (buckets.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_outlined,
                                  size: 64, color: Colors.white.withValues(alpha: 0.05)),
                              const SizedBox(height: 24),
                              Text(
                                'No question sets available yet.',
                                style: GoogleFonts.inter(
                                  color: Colors.white24,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        itemCount: buckets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final bucket = buckets[index];
                          final locked =
                              index != 0 && !unlockedIds.contains(_setKeyFor(bucket));
                          return _BucketCard(
                            bucket: bucket,
                            index: index,
                            locked: locked,
                            onTap: () =>
                                locked ? _onLockedBucketTap(bucket) : _openBucket(bucket),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        gradient: RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.5,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF0F172A),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step 3 of 5',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white30,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '60% COMPLETE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF60A5FA),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String subjectName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Question Set',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
            ),
            child: Text(
              subjectName.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF60A5FA),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  final Bucket bucket;
  final int index;
  final bool locked;
  final VoidCallback onTap;

  const _BucketCard({
    required this.bucket,
    required this.index,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> accentColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
    ];
    final color = locked ? Colors.white24 : accentColors[index % accentColors.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    locked ? Icons.lock_rounded : Icons.school_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.name,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.format_list_bulleted_rounded,
                                    size: 12, color: color),
                                const SizedBox(width: 6),
                                Text(
                                  '${bucket.questionCount} QUESTIONS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.play_circle_outline_rounded,
                                      size: 12, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'WATCH AD',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFF59E0B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                    color: Colors.white24,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
