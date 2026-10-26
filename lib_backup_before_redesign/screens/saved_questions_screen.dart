import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/quiz_models.dart';
import '../services/firestore_service.dart';
import '../state/app_state.dart';
import '../widgets/formatted_text.dart';

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Saved Questions',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _savedQuestions.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                              itemCount: _savedQuestions.length,
                              itemBuilder: (context, index) {
                                final question = _savedQuestions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildQuestionCard(question, index + 1),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          if (!_isLoading && _savedQuestions.isNotEmpty) _buildBottomActionButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 80,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 20),
          Text(
            'No saved questions yet',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Questions you bookmark during quizzes will appear here for you to review and practice.',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int number) {
    final isExpanded = _expandedIds.contains(question.id);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedIds.add(question.id);
                  } else {
                    _expandedIds.remove(question.id);
                  }
                });
              },
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'SAVED $number',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF60A5FA),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'Grade ${question.grade}',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.bookmark_rounded,
                  color: Color(0xFF60A5FA),
                  size: 24,
                ),
                onPressed: () => _removeBookmark(question),
                tooltip: 'Unsave question',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if ((question.scenarioText != null && question.scenarioText!.isNotEmpty) ||
                    (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty)) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                        if (question.scenarioText != null && question.scenarioText!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          FormattedText(
                            question.scenarioText!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.5,
                            ),
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
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      question.imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...List.generate(question.options.length, (i) {
                  final isCorrect = i == question.correctIndex;
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
                  }

                  final hasOptionImage = question.optionImages != null &&
                      question.optionImages!.length > i &&
                      question.optionImages![i].isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: glassColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? textColor.withValues(alpha: 0.1)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: isCorrect ? textColor : Colors.white30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FormattedText(
                                  question.options[i],
                                  style: GoogleFonts.inter(
                                    color: isCorrect ? Colors.white : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isCorrect ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (icon != null) ...[
                                const SizedBox(width: 8),
                                Icon(icon, color: iconColor, size: 16),
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
        ),
      ),
    );
  }

  Widget _buildBottomActionButton() {
    return Positioned(
      bottom: 16,
      left: 20,
      right: 20,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          ),
          boxShadow: [
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
            onTap: _practiceSavedQuestions,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Text(
                'Practice Saved Questions',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: BottomNavigationBar(
        currentIndex: 2, // 'SAVED'
        onTap: (i) {
          if (i == 2) return;
          if (i == 0) {
            Navigator.pushNamedAndRemoveUntil(context, '/grade', (route) => false);
          } else if (i == 1) {
            Navigator.pushReplacementNamed(context, '/leaderboard');
          } else if (i == 3) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.white24,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'GRADES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_rounded),
            label: 'GLOBAL',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_rounded),
            label: 'SAVED',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }
}
