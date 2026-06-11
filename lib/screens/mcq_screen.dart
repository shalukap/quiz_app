import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';
import '../widgets/formatted_text.dart';

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
  final List<int> _userAnswers = [];
  bool _isSaving = false;
  int _grade = 10; // Added

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
    final limit = question.timeLimit ?? 30;

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
      final medium = args?['medium'] as String?;
      final bucketId = args?['bucketId'] as String?;

      final db = FirestoreService();
      final questions = await db.getQuestions(subjectId, grade,
          medium: medium, bucketId: bucketId);

      if (mounted) {
        setState(() {
          _questions = questions;
          _grade = grade; // Store grade
          _isLoading = false;
        });
        _startTimerForQuestion();
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

    _timer?.cancel();
    _userAnswers.add(_selectedOption!);

    if (_selectedOption == _questions![_currentQuestion].correctIndex) {
      _score++;
    }

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
        grade: _grade, // Pass grade
        score: _score,
        totalQuestions: _questions!.length,
        userAnswers: _userAnswers,
      );
    } catch (e) {
      // Silence
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
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Quiz Completed!',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'YOUR SCORE',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_score / ${_questions?.length ?? 0}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF60A5FA),
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
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
                      _startTimerForQuestion();
                    } else {
                      Navigator.pop(screenContext);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Review Results',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
          ],
        ),
      );
    }

    if (_error != null || _questions == null || _questions!.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Stack(
          children: [
            _buildBackground(),
            Center(
              child: Text(
                'No questions available.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final question = _questions![_currentQuestion];
    final totalQuestions = _questions!.length;
    final progress = (_currentQuestion + 1) / totalQuestions;

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
        actions: [
          _buildTimerWidget(),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildProgressSection(progress, totalQuestions),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionHeader(),
                        const SizedBox(height: 16),
                        _buildScenarioCard(question),
                        _buildQuestionText(question),
                        _buildQuestionImage(question),
                        const SizedBox(height: 32),
                        _buildOptionsList(question),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(),
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

  Widget _buildTimerWidget() {
    final bool isLowTime = _secondsRemaining < 5;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isLowTime
              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLowTime
                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              color: isLowTime ? const Color(0xFFF87171) : const Color(0xFF60A5FA),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '${_secondsRemaining}s',
              style: GoogleFonts.inter(
                color: isLowTime ? const Color(0xFFF87171) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(double progress, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 4 of 5',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white30,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Question ${_currentQuestion + 1} of $total',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF60A5FA),
                  ),
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
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader() {
    return Text(
      'SELECT THE CORRECT OPTION',
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF3B82F6),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildScenarioCard(Question question) {
    if ((question.scenarioText == null || question.scenarioText!.isEmpty) &&
        (question.scenarioImageUrl == null || question.scenarioImageUrl!.isEmpty)) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF60A5FA), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'SCENARIO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF60A5FA),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                if (question.scenarioText != null &&
                    question.scenarioText!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FormattedText(
                    question.scenarioText!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.6,
                    ),
                  ),
                ],
                if (question.scenarioImageUrl != null &&
                    question.scenarioImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildExpandableImage(question.scenarioImageUrl!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionText(Question question) {
    return FormattedText(
      question.text,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.4,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildQuestionImage(Question question) {
    if (question.imageUrl == null || question.imageUrl!.isEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: _buildExpandableImage(question.imageUrl!),
    );
  }

  Widget _buildExpandableImage(String url) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.image_not_supported_rounded, color: Colors.white10),
            ),
            loadingBuilder: (_, child, prog) => prog == null
                ? child
                : const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsList(Question question) {
    return Column(
      children: List.generate(question.options.length, (i) {
        final isSelected = _selectedOption == i;
        final label = ['A', 'B', 'C', 'D', 'E'][i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => setState(() => _selectedOption = i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 2 : 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : Colors.white30,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormattedText(
                              question.options[i],
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            if (question.optionImages != null &&
                                question.optionImages!.length > i &&
                                question.optionImages![i].isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildExpandableImage(question.optionImages![i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _bookmarked = !_bookmarked),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(
                _bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _bookmarked ? const Color(0xFF60A5FA) : Colors.white24,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedOption != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _currentQuestion < (_questions?.length ?? 0) - 1
                            ? 'SUBMIT ANSWER'
                            : 'FINISH QUIZ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



