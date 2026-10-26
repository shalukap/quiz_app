import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../services/interstitial_ad_manager.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';
import '../widgets/formatted_text.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/glass_ui.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';

class McqScreen extends StatefulWidget {
  const McqScreen({super.key});

  @override
  State<McqScreen> createState() => _McqScreenState();
}

class _McqScreenState extends State<McqScreen> {
  int _currentQuestion = 0;
  int? _selectedOption;
  int _score = 0;

  List<Question>? _questions;
  bool _isLoading = false;
  String? _error;
  List<int> _userAnswers = [];
  List<bool> _bookmarkedQuestions = [];
  List<int> _questionTimesRemaining = [];
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

    final limit = _questionTimesRemaining[_currentQuestion];

    setState(() {
      _secondsRemaining = limit;
    });

    if (_secondsRemaining <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
          _questionTimesRemaining[_currentQuestion] = _secondsRemaining;
        } else {
          timer.cancel();
          _handleTimeUp();
        }
      });
    });
  }

  void _handleTimeUp() {
    if (!mounted) return;

    setState(() {
      if (_currentQuestion < _questions!.length - 1) {
        _currentQuestion++;
        final savedAnswer = _userAnswers[_currentQuestion];
        _selectedOption = savedAnswer == -1 ? null : savedAnswer;
        _startTimerForQuestion();
      } else {
        _finishQuiz();
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
      final db = FirestoreService();
      final username = AppState.currentUsername ?? 'guest';
      
      List<Question> questions = [];
      int grade = 10;
      
      if (args != null && args.containsKey('questions')) {
        questions = List<Question>.from(args['questions']);
        grade = args['grade'] as int? ?? 10;
      } else {
        final subjectId = args?['subjectId'] as String? ?? '';
        grade = args?['grade'] as int? ?? 10;
        final medium = args?['medium'] as String?;
        final bucketId = args?['bucketId'] as String?;
        questions = await db.getQuestions(subjectId, grade,
            medium: medium, bucketId: bucketId);
      }

      final bookmarkedIds = await db.getBookmarkedQuestionIds(username);

      if (mounted) {
        setState(() {
          _questions = questions;
          _grade = grade; // Store grade
          _isLoading = false;
          _userAnswers = List<int>.filled(questions.length, -1);
          _bookmarkedQuestions = questions.map((q) => bookmarkedIds.contains(q.id)).toList();
          _questionTimesRemaining = questions.map((q) => q.timeLimit ?? 30).toList();
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

  void _navigateToQuestion(int targetIndex) {
    if (_questions == null || targetIndex < 0 || targetIndex >= _questions!.length) return;

    _timer?.cancel();
    
    // Save current question's time remaining
    _questionTimesRemaining[_currentQuestion] = _secondsRemaining;

    setState(() {
      _currentQuestion = targetIndex;
      final savedAnswer = _userAnswers[_currentQuestion];
      _selectedOption = savedAnswer == -1 ? null : savedAnswer;
    });

    _startTimerForQuestion();
  }

  void _finishQuiz() {
    _timer?.cancel();
    
    // Save current question's remaining time
    if (_questions != null && _currentQuestion < _questionTimesRemaining.length) {
      _questionTimesRemaining[_currentQuestion] = _secondsRemaining;
    }

    _score = 0;
    if (_questions != null) {
      for (int i = 0; i < _questions!.length; i++) {
        if (_userAnswers[i] == _questions![i].correctIndex) {
          _score++;
        }
      }
    }

    _saveAndShowResults();
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
      AnalyticsService.instance.logQuizCompleted(
        grade: _grade,
        subjectName: subjectName,
        medium: args?['medium'] as String?,
        score: _score,
        totalQuestions: _questions!.length,
      );
    } catch (e) {
      // Silence
    }

    if (mounted) {
      setState(() => _isSaving = false);
      InterstitialAdManager.instance.showAdThen(() {
        if (mounted) _showResults();
      });
    }
  }

  void _showResults() {
    final screenContext = context;
    final total = _questions?.length ?? 0;
    final ratio = total == 0 ? 0.0 : _score / total;
    final color = AppColors.scoreColor(ratio);
    final headline = ratio >= 0.75
        ? 'Outstanding! 🎉'
        : ratio >= 0.5
            ? 'Nice work! 👏'
            : 'Keep practicing 💪';

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('QUIZ COMPLETE', style: AppText.overline(color: AppColors.cyan)),
                const SizedBox(height: 8),
                Text(headline, style: AppText.title(), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 40),
                            ],
                          ),
                        ),
                        CircularProgressIndicator(
                          value: v,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(v * 100).round()}%',
                                style: AppText.style(size: 34, weight: FontWeight.w800, spacing: -1),
                              ),
                              Text(
                                '$_score / $total',
                                style: AppText.style(size: 13, weight: FontWeight.w700, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: 'Review answers',
                  icon: Icons.arrow_forward_rounded,
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
                          _userAnswers = List<int>.filled(_questions!.length, -1);
                          _bookmarkedQuestions = List<bool>.filled(_questions!.length, false);
                          _questionTimesRemaining = _questions!.map((q) => q.timeLimit ?? 30).toList();
                        });
                        _startTimerForQuestion();
                      } else {
                        Navigator.pop(screenContext);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AuroraBackground(child: AppLoader()),
      );
    }

    if (_error != null || _questions == null || _questions!.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: glassAppBar(context),
        body: const AuroraBackground(
          child: EmptyState(
            icon: Icons.quiz_outlined,
            title: 'No questions available',
            subtitle: 'Try another question set.',
          ),
        ),
      );
    }

    final question = _questions![_currentQuestion];
    final totalQuestions = _questions!.length;
    final progress = (_currentQuestion + 1) / totalQuestions;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: GlassBackButton(icon: Icons.close_rounded),
        ),
        title: 'Question ${_currentQuestion + 1} of $totalQuestions',
        actions: [_buildTimerWidget(question)],
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: GlowProgressBar(value: progress),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_currentQuestion),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScenarioCard(question),
                        _buildQuestionCard(question),
                        const SizedBox(height: 20),
                        _buildQuestionHeader(),
                        const SizedBox(height: 12),
                        _buildOptionsList(question),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              const BannerAdWidget(),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerWidget(Question question) {
    final total = (question.timeLimit ?? 30).clamp(1, 1 << 30);
    final bool isLowTime = _secondsRemaining < 5;
    final color = isLowTime ? AppColors.danger : AppColors.cyan;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLowTime ? AppColors.danger.withValues(alpha: 0.15) : AppColors.glassFill,
              boxShadow: isLowTime
                  ? [BoxShadow(color: AppColors.danger.withValues(alpha: 0.4), blurRadius: 16)]
                  : null,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (_secondsRemaining / total).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Text(
              '$_secondsRemaining',
              style: AppText.style(size: 14, weight: FontWeight.w800, color: isLowTime ? AppColors.danger : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader() {
    return Text('SELECT THE CORRECT OPTION', style: AppText.overline(color: AppColors.textMuted));
  }

  Widget _buildScenarioCard(Question question) {
    if ((question.scenarioText == null || question.scenarioText!.isEmpty) &&
        (question.scenarioImageUrl == null || question.scenarioImageUrl!.isEmpty)) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        accent: AppColors.cyan,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Scenario', icon: Icons.info_outline_rounded, color: AppColors.cyan),
            if (question.scenarioText != null && question.scenarioText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              FormattedText(
                question.scenarioText!,
                style: AppText.style(size: 15, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9), height: 1.6),
              ),
            ],
            if (question.scenarioImageUrl != null && question.scenarioImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildExpandableImage(question.scenarioImageUrl!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return GlassCard(
      blur: true,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill(label: 'Q${_currentQuestion + 1}', color: AppColors.violet, icon: Icons.help_outline_rounded),
          const SizedBox(height: 14),
          _buildQuestionText(question),
          _buildQuestionImage(question),
        ],
      ),
    );
  }

  Widget _buildQuestionText(Question question) {
    return FormattedText(
      question.text,
      style: AppText.style(size: 20, weight: FontWeight.w700, height: 1.45, spacing: -0.3),
    );
  }

  Widget _buildQuestionImage(Question question) {
    if (question.imageUrl == null || question.imageUrl!.isEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _buildExpandableImage(question.imageUrl!),
    );
  }

  Widget _buildExpandableImage(String url) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.85),
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            shape: const RoundedRectangleBorder(),
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
                  top: 12,
                  right: 12,
                  child: GlassIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.05),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white24)),
                ),
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.zoom_out_map_rounded, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(Question question) {
    final enabled = _secondsRemaining > 0;
    return Column(
      children: List.generate(question.options.length, (i) {
        final isSelected = _selectedOption == i;
        final label = String.fromCharCode(65 + i);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Pressable(
            onTap: enabled
                ? () {
                    setState(() {
                      _selectedOption = i;
                      _userAnswers[_currentQuestion] = i;
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.30),
                          AppColors.violet.withValues(alpha: 0.16),
                        ],
                      )
                    : AppGradients.glass(),
                border: Border.all(
                  color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.9) : AppColors.glassStroke,
                  width: isSelected ? 1.6 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: -6,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: isSelected ? AppGradients.primary : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: isSelected ? Colors.white.withValues(alpha: 0.3) : AppColors.glassStroke,
                      ),
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : Text(
                              label,
                              style: AppText.style(size: 14, weight: FontWeight.w800, color: AppColors.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormattedText(
                            question.options[i],
                            style: AppText.style(
                              size: 15.5,
                              weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
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
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActions() {
    if (_questions == null || _questions!.isEmpty) return const SizedBox();
    final isLast = _currentQuestion >= (_questions?.length ?? 0) - 1;
    final bookmarked = _bookmarkedQuestions[_currentQuestion];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GlassCard(
        blur: true,
        radius: 26,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            GlassIconButton(
              icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 52,
              active: bookmarked,
              color: AppColors.warning,
              onTap: () async {
                final newStatus = !_bookmarkedQuestions[_currentQuestion];
                setState(() {
                  _bookmarkedQuestions[_currentQuestion] = newStatus;
                });
                try {
                  await FirestoreService().toggleBookmark(
                    AppState.currentUsername ?? 'guest',
                    _questions![_currentQuestion],
                    newStatus,
                  );
                } catch (e) {
                  debugPrint('Failed to toggle bookmark: $e');
                }
              },
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _currentQuestion > 0 ? 1.0 : 0.35,
              child: GlassIconButton(
                icon: Icons.chevron_left_rounded,
                size: 52,
                onTap: _currentQuestion > 0 ? () => _navigateToQuestion(_currentQuestion - 1) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GradientButton(
                height: 52,
                label: isLast ? 'Finish quiz' : 'Next',
                icon: isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                loading: _isSaving,
                gradient: isLast
                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF22D3EE)])
                    : AppGradients.primary,
                onPressed: () {
                  if (!isLast) {
                    _navigateToQuestion(_currentQuestion + 1);
                  } else {
                    _finishQuiz();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
