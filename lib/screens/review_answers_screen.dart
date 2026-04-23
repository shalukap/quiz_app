import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quiz_models.dart';

class ReviewAnswersScreen extends StatelessWidget {
  const ReviewAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final questions = args?['questions'] as List<Question>? ?? [];
    final userAnswers = args?['userAnswers'] as List<int>? ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, 'exit'),
        ),
        title: Text(
          'Review Answers',
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
          questions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 120),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    final userAnswer =
                        userAnswers.length > index ? userAnswers[index] : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildQuestionCard(
                          context, index + 1, question, userAnswer),
                    );
                  },
                ),
          _buildBottomBar(context),
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

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No answers to review.',
        style: GoogleFonts.inter(color: Colors.white30, fontWeight: FontWeight.w600),
      ),
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
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildButton(
                    onPressed: () => Navigator.pop(context, 'exit'),
                    label: 'Exit',
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildButton(
                    onPressed: () => Navigator.pop(context, 'restart'),
                    label: 'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required String label,
    bool isSecondary = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSecondary
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              ),
        color: isSecondary ? Colors.white.withValues(alpha: 0.05) : null,
        border: isSecondary ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        boxShadow: [
          if (!isSecondary)
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSecondary ? Colors.white70 : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
      BuildContext context, int index, Question question, int? userAnswer) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'QUESTION $index',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF60A5FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (userAnswer != null)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (userAnswer == question.correctIndex
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        userAnswer == question.correctIndex
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        color: userAnswer == question.correctIndex
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Scenario (if any)
              if ((question.scenarioText != null &&
                      question.scenarioText!.isNotEmpty) ||
                  (question.scenarioImageUrl != null &&
                      question.scenarioImageUrl!.isNotEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCENARIO',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white30,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (question.scenarioText != null &&
                          question.scenarioText!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          question.scenarioText!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (question.scenarioImageUrl != null &&
                          question.scenarioImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            question.scenarioImageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              Text(
                question.text,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.4,
                  letterSpacing: -0.3,
                ),
              ),
              if (userAnswer == -1) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_off_outlined,
                          color: Color(0xFFEF4444), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Timed Out',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    question.imageUrl!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ...List.generate(question.options.length, (i) {
                final isCorrect = i == question.correctIndex;
                final isUserSelected = i == userAnswer;
                final label = ['A', 'B', 'C', 'D', 'E', 'F'][i];

                Color glassColor = Colors.white.withValues(alpha: 0.02);
                Color borderColor = Colors.white.withValues(alpha: 0.05);
                Color textColor = Colors.white60;
                IconData? icon;
                Color iconColor = Colors.transparent;

                if (isCorrect) {
                  glassColor = const Color(0xFF10B981).withValues(alpha: 0.1);
                  borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
                  textColor = const Color(0xFF10B981);
                  icon = Icons.check_circle_rounded;
                  iconColor = const Color(0xFF10B981);
                } else if (isUserSelected && !isCorrect) {
                  glassColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
                  borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
                  textColor = const Color(0xFFEF4444);
                  icon = Icons.cancel_rounded;
                  iconColor = const Color(0xFFEF4444);
                }

                final hasOptionImage = question.optionImages != null &&
                    question.optionImages!.length > i &&
                    question.optionImages![i].isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: glassColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
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
                                color: (isCorrect || isUserSelected)
                                    ? textColor.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: (isCorrect || isUserSelected)
                                        ? textColor
                                        : Colors.white30,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                question.options[i],
                                style: GoogleFonts.inter(
                                  color: (isCorrect || isUserSelected)
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: (isCorrect || isUserSelected)
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (icon != null) ...[
                              const SizedBox(width: 8),
                              Icon(icon, color: iconColor, size: 18),
                            ],
                          ],
                        ),
                        if (hasOptionImage) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              question.optionImages![i],
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
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
      ),
    );
  }
}

