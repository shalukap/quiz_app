import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../theme/app_theme.dart';
import '../widgets/formatted_text.dart';
import '../widgets/glass_ui.dart';

class ReviewAnswersScreen extends StatelessWidget {
  const ReviewAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final questions = args?['questions'] as List<Question>? ?? [];
    final userAnswers = args?['userAnswers'] as List<int>? ?? [];

    int correct = 0;
    int timedOut = 0;
    for (int i = 0; i < questions.length; i++) {
      final a = userAnswers.length > i ? userAnswers[i] : -1;
      if (a == questions[i].correctIndex) correct++;
      if (a == -1) timedOut++;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: 'Review answers',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GlassBackButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context, 'exit'),
          ),
        ),
      ),
      body: AuroraBackground(
        child: Stack(
          children: [
            questions.isEmpty
                ? const EmptyState(icon: Icons.fact_check_outlined, title: 'No answers to review.')
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                      20,
                      140,
                    ),
                    itemCount: questions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildSummary(correct, questions.length - correct - timedOut, timedOut),
                        );
                      }
                      final i = index - 1;
                      final question = questions[i];
                      final userAnswer = userAnswers.length > i ? userAnswers[i] : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FadeSlideIn(
                          index: i,
                          child: _buildQuestionCard(context, i + 1, question, userAnswer),
                        ),
                      );
                    },
                  ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(int correct, int wrong, int timedOut) {
    Widget stat(String label, int value, Color color, IconData icon) => Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text('$value', style: AppText.style(size: 22, weight: FontWeight.w800)),
                Text(label, style: AppText.style(size: 11, weight: FontWeight.w700, color: AppColors.textMuted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat('Correct', correct, AppColors.success, Icons.check_circle_rounded),
        const SizedBox(width: 10),
        stat('Wrong', wrong, AppColors.danger, Icons.cancel_rounded),
        const SizedBox(width: 10),
        stat('Timed out', timedOut, AppColors.warning, Icons.timer_off_rounded),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.6),
              border: Border(top: BorderSide(color: AppColors.glassStroke)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Exit',
                    icon: Icons.home_rounded,
                    onPressed: () => Navigator.pop(context, 'exit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: 'Try again',
                    icon: Icons.replay_rounded,
                    onPressed: () => Navigator.pop(context, 'restart'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, int index, Question question, int? userAnswer) {
    final isCorrectAnswer = userAnswer == question.correctIndex;
    final statusColor = userAnswer == -1
        ? AppColors.warning
        : isCorrectAnswer
            ? AppColors.success
            : AppColors.danger;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(label: 'Question $index', color: AppColors.primary),
              const Spacer(),
              if (userAnswer != null)
                Pill(
                  label: userAnswer == -1
                      ? 'Timed out'
                      : isCorrectAnswer
                          ? 'Correct'
                          : 'Wrong',
                  color: statusColor,
                  icon: userAnswer == -1
                      ? Icons.timer_off_outlined
                      : isCorrectAnswer
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                    const SizedBox(height: 10),
                    FormattedText(
                      question.scenarioText!,
                      style: AppText.style(size: 14, color: AppColors.textSecondary, height: 1.6),
                    ),
                  ],
                  if (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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
            style: AppText.style(size: 16.5, weight: FontWeight.w700, height: 1.45, spacing: -0.2),
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
          const SizedBox(height: 18),
          ...List.generate(question.options.length, (i) {
            final isCorrect = i == question.correctIndex;
            final isUserSelected = i == userAnswer;
            return _ReviewOption(
              label: String.fromCharCode(65 + i),
              text: question.options[i],
              imageUrl: question.optionImages != null &&
                      question.optionImages!.length > i &&
                      question.optionImages![i].isNotEmpty
                  ? question.optionImages![i]
                  : null,
              state: isCorrect
                  ? _OptionState.correct
                  : isUserSelected
                      ? _OptionState.wrong
                      : _OptionState.neutral,
            );
          }),
        ],
      ),
    );
  }
}

enum _OptionState { neutral, correct, wrong }

class _ReviewOption extends StatelessWidget {
  final String label;
  final String text;
  final String? imageUrl;
  final _OptionState state;

  const _ReviewOption({required this.label, required this.text, required this.state, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.wrong => AppColors.danger,
      _OptionState.neutral => null,
    };
    final highlighted = color != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          border: Border.all(color: highlighted ? color.withValues(alpha: 0.5) : AppColors.glassStrokeSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: highlighted ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: AppText.style(
                        size: 12,
                        weight: FontWeight.w800,
                        color: highlighted ? color : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormattedText(
                    text,
                    style: AppText.style(
                      size: 14,
                      weight: highlighted ? FontWeight.w600 : FontWeight.w400,
                      color: highlighted ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (highlighted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    state == _OptionState.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: color,
                    size: 18,
                  ),
                ],
              ],
            ),
            if (imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl!,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
