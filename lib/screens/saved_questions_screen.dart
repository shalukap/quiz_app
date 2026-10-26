import 'package:flutter/material.dart';

import '../models/quiz_models.dart';
import '../config/grades.dart';
import '../services/firestore_service.dart';
import '../state/app_state.dart';
import '../widgets/formatted_text.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

class SavedQuestionsScreen extends StatefulWidget {
  const SavedQuestionsScreen({super.key});

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  bool _isLoading = true;
  List<Question> _savedQuestions = [];
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSavedQuestions();
  }

  Future<void> _fetchSavedQuestions() async {
    setState(() => _isLoading = true);
    try {
      final username = AppState.currentUsername ?? 'guest';
      final questions = await FirestoreService().getBookmarkedQuestions(username);
      if (mounted) {
        setState(() {
          _savedQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved questions: $e')),
        );
      }
    }
  }

  Future<void> _removeBookmark(Question question) async {
    final username = AppState.currentUsername ?? 'guest';
    
    // Optimistic UI update
    setState(() {
      _savedQuestions.removeWhere((q) => q.id == question.id);
      _expandedIds.remove(question.id);
    });

    try {
      await FirestoreService().toggleBookmark(username, question, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question removed from bookmarks'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert state if failed
      _fetchSavedQuestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove bookmark: $e')),
        );
      }
    }
  }

  void _practiceSavedQuestions() {
    if (_savedQuestions.isEmpty) return;

    Navigator.pushNamed(
      context,
      '/quiz',
      arguments: {
        'questions': _savedQuestions,
        'grade': _savedQuestions.first.grade,
        'subjectId': 'saved_practice',
        'subjectName': 'Saved Practice',
      },
    ).then((_) {
      // Refresh list on return in case they unbookmarked items
      _fetchSavedQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final showPractice = !_isLoading && _savedQuestions.isNotEmpty;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context, title: 'Saved questions'),
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? const AppLoader()
              : _savedQuestions.isEmpty
                  ? const EmptyState(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'No saved questions yet',
                      subtitle: 'Questions you bookmark during quizzes will appear here for you to review and practice.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 200),
                      itemCount: _savedQuestions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16, left: 4),
                            child: Text(
                              '${_savedQuestions.length} saved question${_savedQuestions.length == 1 ? '' : 's'} · tap to expand',
                              style: AppText.style(size: 13, weight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          );
                        }
                        final question = _savedQuestions[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(
                            index: index - 1,
                            child: _buildQuestionCard(question, index),
                          ),
                        );
                      },
                    ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPractice)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: GradientButton(
                label: 'Practice saved questions',
                icon: Icons.play_arrow_rounded,
                onPressed: _practiceSavedQuestions,
              ),
            ),
          FloatingNavBar(currentIndex: 2, onTap: _onNavTap),
        ],
      ),
    );
  }

  void _onNavTap(int i) {
    if (i == 2) return;
    if (i == 0) {
      Navigator.pushNamedAndRemoveUntil(context, '/grade', (route) => false);
    } else if (i == 1) {
      Navigator.pushReplacementNamed(context, '/leaderboard');
    } else if (i == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  Widget _buildQuestionCard(Question question, int number) {
    final isExpanded = _expandedIds.contains(question.id);

    return GlassCard(
      padding: EdgeInsets.zero,
      accent: isExpanded ? AppColors.primary : null,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedIds.add(question.id);
              } else {
                _expandedIds.remove(question.id);
              }
            });
          },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(label: '#$number', color: AppColors.primary),
                  Pill(label: Grades.label(question.grade), color: AppColors.violet),
                ],
              ),
              if (!isExpanded) ...[
                const SizedBox(height: 10),
                FormattedText(
                  question.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.bookmark_rounded, color: AppColors.warning, size: 24),
            onPressed: () => _removeBookmark(question),
            tooltip: 'Unsave question',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if ((question.scenarioText != null && question.scenarioText!.isNotEmpty) ||
                (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassStrokeSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Scenario', color: AppColors.cyan),
                    if (question.scenarioText != null && question.scenarioText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FormattedText(
                        question.scenarioText!,
                        style: AppText.style(size: 13, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                    if (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          question.scenarioImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            FormattedText(
              question.text,
              style: AppText.style(size: 16, weight: FontWeight.w700, height: 1.45),
            ),
            if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  question.imageUrl!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...List.generate(question.options.length, (i) {
              final isCorrect = i == question.correctIndex;
              final hasOptionImage = question.optionImages != null &&
                  question.optionImages!.length > i &&
                  question.optionImages![i].isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect ? AppColors.success.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.025),
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    border: Border.all(
                      color: isCorrect ? AppColors.success.withValues(alpha: 0.5) : AppColors.glassStrokeSoft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCorrect ? AppColors.success.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: AppText.style(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: isCorrect ? AppColors.success : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FormattedText(
                              question.options[i],
                              style: AppText.style(
                                size: 13.5,
                                weight: isCorrect ? FontWeight.w600 : FontWeight.w400,
                                color: isCorrect ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (isCorrect) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                          ],
                        ],
                      ),
                      if (hasOptionImage) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            question.optionImages![i],
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
