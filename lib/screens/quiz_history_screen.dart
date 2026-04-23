import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Quiz History',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBackground(),
          _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<QuizResult>>(
        future: FirestoreService().getRecentResults(AppState.currentUsername ?? 'guest'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return _buildEmptyState();
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: sortedGrades.length,
            itemBuilder: (context, gradeIndex) {
              final grade = sortedGrades[gradeIndex];
              final gradeMap = groupedHistory[grade]!;
              final sortedSubjects = gradeMap.keys.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'GRADE $grade',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...sortedSubjects.map((subject) {
                    final results = gradeMap[subject]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                          child: Text(
                            subject,
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.5,
                            ),
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
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: Colors.white.withValues(alpha: 0.1), size: 80),
          const SizedBox(height: 24),
          Text(
            'No history found',
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a quiz to see it here!',
            style: GoogleFonts.inter(
              color: Colors.white10,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

  Color _getScoreColor() {
    final percentage = result.percentage;
    if (percentage >= 0.8) return const Color(0xFF34D399); // Green
    if (percentage >= 0.5) return const Color(0xFFFBBF24); // Yellow
    return const Color(0xFFF87171); // Red
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor();
    final formattedDate = DateFormat('MMM d, h:mm a').format(result.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: scoreColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attempt $attemptNumber Result',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: Colors.white24, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
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
                      style: GoogleFonts.inter(
                        color: scoreColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${result.score}/${result.totalQuestions}',
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
