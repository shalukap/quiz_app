import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

class McqScreen extends StatefulWidget {
  const McqScreen({super.key});

  @override
  State<McqScreen> createState() => _McqScreenState();
}

class _McqScreenState extends State<McqScreen> {
  int _currentQuestion = 0;
  int? _selectedOption;
  bool _bookmarked = false;
  int _score = 0;

  List<Question>? _questions;
  bool _isLoading = false;
  String? _error;
  List<int> _userAnswers = [];
  bool _isSaving = false;

  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerForQuestion() {
    _timer?.cancel();
    if (_questions == null || _questions!.isEmpty) return;

    final question = _questions![_currentQuestion];
    final limit = question.timeLimit ?? 30; // Default to 30s

    setState(() {
      _secondsRemaining = limit;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _handleTimeUp();
        }
      });
    });
  }

  void _handleTimeUp() {
    if (!mounted) return;

    // Add -1 to indicate timed out / skipped
    _userAnswers.add(-1);

    setState(() {
      if (_currentQuestion < _questions!.length - 1) {
        _currentQuestion++;
        _selectedOption = null;
        _bookmarked = false;
        _startTimerForQuestion();
      } else {
        _saveAndShowResults();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_questions == null && !_isLoading && _error == null) {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final subjectId = args?['subjectId'] as String? ?? '';
      final grade = args?['grade'] as int? ?? 10;
      
      final db = FirestoreService();
      final questions = await db.getQuestions(subjectId, grade);
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        _startTimerForQuestion(); // Start timer
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _submitAnswer() {
    if (_selectedOption == null || _questions == null) return;

    _timer?.cancel(); // Cancel timer on manual submission
    _userAnswers.add(_selectedOption!);

    if (_selectedOption == _questions![_currentQuestion].correctIndex) {
      _score++;
    }

    setState(() {
      if (_currentQuestion < _questions!.length - 1) {
        _currentQuestion++;
        _selectedOption = null;
        _bookmarked = false;
        _startTimerForQuestion(); // Restart for next question
      } else {
        _saveAndShowResults();
      }
    });
  }

  Future<void> _saveAndShowResults() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final subjectId = args?['subjectId'] as String? ?? '';
      final subjectName = args?['subjectName'] as String? ?? '';

      await FirestoreService().saveQuizResult(
        username: AppState.currentUsername ?? 'guest',
        subjectId: subjectId,
        subjectName: subjectName,
        score: _score,
        totalQuestions: _questions!.length,
        userAnswers: _userAnswers,
      );
    } catch (e) {
      // Provide silent failure or log to console
    }

    if (mounted) {
      setState(() => _isSaving = false);
      _showResults();
    }
  }

  void _showResults() {
    final screenContext = context;
    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Quiz Completed!',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Score',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / ${_questions?.length ?? 0}',
              style: GoogleFonts.inter(
                color: const Color(0xFF2563EB),
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog using dialogContext
              final result = await Navigator.pushNamed(
                screenContext,
                '/review_answers',
                arguments: {
                  'questions': _questions!,
                  'userAnswers': _userAnswers,
                },
              );
              if (screenContext.mounted) {
                if (result == 'restart') {
                  setState(() {
                    _currentQuestion = 0;
                    _selectedOption = null;
                    _score = 0;
                    _bookmarked = false;
                    _userAnswers.clear();
                  });
                  _startTimerForQuestion(); // Restart timer
                } else {
                  Navigator.pop(screenContext); // Go back to subjects (exit)
                }
              }
            },
            child: Text(
              'Review Answers',
              style: GoogleFonts.inter(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_error != null || _questions == null || _questions!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Text(
            'No questions available for this subject.',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
        ),
      );
    }

    final question = _questions![_currentQuestion];
    final totalQuestions = _questions!.length;
    final progress = (_currentQuestion + 1) / totalQuestions;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Practice Quiz',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: _secondsRemaining < 5 
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1) 
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _secondsRemaining < 5 
                    ? const Color(0xFFEF4444) 
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined, 
                  color: _secondsRemaining < 5 ? const Color(0xFFEF4444) : Colors.white70, 
                  size: 16
                ),
                const SizedBox(width: 4),
                Text(
                  '${_secondsRemaining}s',
                  style: TextStyle(
                    color: _secondsRemaining < 5 ? const Color(0xFFEF4444) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quiz Progress',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Question ${_currentQuestion + 1} of $totalQuestions',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice Quiz',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.text,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                InteractiveViewer(
                                  clipBehavior: Clip.none,
                                  maxScale: 3.0,
                                  child: Image.network(
                                    question.imageUrl!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color(0xFF1E293B),
                          height: 220,
                          width: double.infinity,
                          child: Image.network(
                            question.imageUrl!,
                            fit: BoxFit.contain, // Fits entire image without cropping
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.white60)));
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // Options
                  ...List.generate(question.options.length, (i) {
                    final isSelected = _selectedOption == i;
                    final label = ['A', 'B', 'C', 'D','E'][i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedOption = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 10,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Option $label: ${question.options[i]}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    if (question.optionImages != null &&
                                        question.optionImages!.length > i &&
                                        question.optionImages![i].isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              backgroundColor: Colors.transparent,
                                              insetPadding: const EdgeInsets.all(12),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  InteractiveViewer(
                                                    clipBehavior: Clip.none,
                                                    maxScale: 3.0,
                                                    child: Image.network(
                                                      question.optionImages![i],
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 10,
                                                    right: 10,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                                      onPressed: () => Navigator.pop(context),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            color: const Color(0xFF0F172A),
                                            height: 120,
                                            width: double.infinity,
                                            child: Image.network(
                                              question.optionImages![i],
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2));
                                              },
                                              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.white30)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // Bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Bookmark button
                GestureDetector(
                  onTap: () => setState(() => _bookmarked = !_bookmarked),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _bookmarked
                           ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _bookmarked
                          ? const Color(0xFF2563EB)
                          : Colors.white24,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Submit button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedOption != null ? _submitAnswer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        disabledBackgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _currentQuestion < _questions!.length - 1
                                  ? 'Submit Answer'
                                  : 'Finish Quiz',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


