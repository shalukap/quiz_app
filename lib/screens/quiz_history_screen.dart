import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../config/grades.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context, title: 'Quiz history'),
      body: AuroraBackground(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<QuizResult>>(
        future: FirestoreService().getRecentResults(AppState.currentUsername ?? 'guest'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No history found',
              subtitle: 'Complete a quiz to see it here!',
            );
          }

          // Grade -> Subject -> Results
          final Map<int, Map<String, List<QuizResult>>> groupedHistory = {};
          for (var result in history) {
            final gradeMap = groupedHistory.putIfAbsent(result.grade, () => {});
            final subjectList = gradeMap.putIfAbsent(result.subjectName, () => []);
            subjectList.add(result);
          }

          final sortedGrades = groupedHistory.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: sortedGrades.length,
            itemBuilder: (context, gradeIndex) {
              final grade = sortedGrades[gradeIndex];
              final gradeMap = groupedHistory[grade]!;
              final sortedSubjects = gradeMap.keys.toList()..sort();

              return FadeSlideIn(
                index: gradeIndex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: Text(
                              Grades.label(grade).toUpperCase(),
                              style: AppText.style(size: 12, weight: FontWeight.w800, spacing: 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Container(height: 1, color: AppColors.glassStrokeSoft)),
                        ],
                      ),
                    ),
                    ...sortedSubjects.map((subject) {
                      final results = gradeMap[subject]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subject,
                                        style: AppText.style(size: 16, weight: FontWeight.w700, spacing: -0.3),
                                      ),
                                    ),
                                    Text(
                                      '${results.length} attempt${results.length == 1 ? '' : 's'}',
                                      style: AppText.style(size: 12, weight: FontWeight.w600, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              ...results.asMap().entries.map((entry) {
                                final index = entry.key;
                                final result = entry.value;
                                // results is sorted newest first, so:
                                final attemptNumber = results.length - index;
                                return _HistoryCard(
                                  result: result,
                                  attemptNumber: attemptNumber,
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QuizResult result;
  final int attemptNumber;

  const _HistoryCard({
    required this.result,
    required this.attemptNumber,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppColors.scoreColor(result.percentage);
    final formattedDate = DateFormat('MMM d, h:mm a').format(result.date);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: AppColors.glassStrokeSoft),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: result.percentage.clamp(0.0, 1.0),
                  strokeWidth: 3.5,
                  strokeCap: StrokeCap.round,
                  color: scoreColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                Center(
                  child: Text(
                    '#$attemptNumber',
                    style: AppText.style(size: 10, weight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attempt $attemptNumber',
                  style: AppText.style(size: 13.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: AppText.style(size: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(result.percentage * 100).toStringAsFixed(0)}%',
                style: AppText.style(size: 17, weight: FontWeight.w800, color: scoreColor, spacing: -0.5),
              ),
              Text(
                '${result.score}/${result.totalQuestions}',
                style: AppText.style(size: 11, weight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
