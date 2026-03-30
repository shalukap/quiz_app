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
      backgroundColor: const Color(0xFF0F172A),
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
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: questions.isEmpty
          ? Center(
              child: Text(
                'No answers to review.',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final userAnswer = userAnswers.length > index ? userAnswers[index] : null;

                return Column(
                  children: [
                    _buildQuestionCard(context, index + 1, question, userAnswer),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'exit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Exit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'restart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, int index, Question question, int? userAnswer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB), width: 1),
                ),
                child: Text(
                  'Q$index',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (userAnswer != null)
                Icon(
                  userAnswer == question.correctIndex ? Icons.check_circle : Icons.cancel,
                  color: userAnswer == question.correctIndex ? Colors.green : Colors.red,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Scenario (if any)
          if ((question.scenarioText != null && question.scenarioText!.isNotEmpty) ||
              (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCENARIO',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 1,
                    ),
                  ),
                  if (question.scenarioText != null && question.scenarioText!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      question.scenarioText!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
          Text(
            question.text,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          if (userAnswer == -1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_off_outlined, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Timed Out',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                question.imageUrl!,
                fit: BoxFit.contain,
                height: 180,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...List.generate(question.options.length, (i) {
            final isCorrect = i == question.correctIndex;
            final isUserSelected = i == userAnswer;
            final label = ['A', 'B', 'C', 'D', 'E', 'F'][i];

            Color bgColor = const Color(0xFF0F172A);
            Color borderColor = Colors.white.withValues(alpha: 0.05);
            IconData? icon;
            Color iconColor = Colors.transparent;

            if (isCorrect) {
              bgColor = Colors.green.withValues(alpha: 0.1);
              borderColor = Colors.green;
              icon = Icons.check_circle_rounded;
              iconColor = Colors.green;
            } else if (isUserSelected && !isCorrect) {
              bgColor = Colors.red.withValues(alpha: 0.1);
              borderColor = Colors.red;
              icon = Icons.cancel_rounded;
              iconColor = Colors.red;
            }

            final hasOptionImage = question.optionImages != null &&
                question.optionImages!.length > i &&
                question.optionImages![i].isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$label.',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: isCorrect ? Colors.green : (isUserSelected ? Colors.red : Colors.white60),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.options[i],
                            style: GoogleFonts.inter(
                              color: isCorrect || isUserSelected ? Colors.white : Colors.white70,
                              fontSize: 14,
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
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          question.optionImages![i],
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
          }),
        ],
      ),
    );
  }
}
