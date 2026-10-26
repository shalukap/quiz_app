import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../config/grades.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<QuizResult> _results = [];
  Map<int, Map<String, List<QuizResult>>> _gradeGroupedResults = {}; // Grade -> (Subject -> List<Results>)

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final username = AppState.currentUsername ?? 'guest';
      final results = await FirestoreService().getRecentResults(username);
      
      // Group by Grade and then by Subject
      final Map<int, Map<String, List<QuizResult>>> gradeGrouped = {};
      for (var res in results) {
        final grade = res.grade;
        if (!gradeGrouped.containsKey(grade)) {
          gradeGrouped[grade] = {};
        }
        
        final subjectKey = res.subjectName;
        if (!gradeGrouped[grade]!.containsKey(subjectKey)) {
          gradeGrouped[grade]![subjectKey] = [];
        }
        gradeGrouped[grade]![subjectKey]!.add(res);
      }

      if (mounted) {
        setState(() {
          _results = results;
          _gradeGroupedResults = gradeGrouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context, title: 'My progress'),
      body: AuroraBackground(
        child: SafeArea(
          child: _isLoading
              ? const AppLoader()
              : _results.isEmpty
                  ? const EmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: 'No quiz data yet',
                      subtitle: 'Complete a quiz to see your progress graph!',
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeSlideIn(child: _buildSummaryCards()),
                          const SizedBox(height: 28),
                          ..._buildChartsByGrade(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final avgScore = _results.isEmpty
        ? 0
        : (_results.fold(0, (sum, res) => sum + res.score) /
                _results.fold(0, (sum, res) => sum + res.totalQuestions) *
                100)
            .toInt();

    return GlassCard(
      blur: true,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: avgScore / 100),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    color: AppColors.scoreColor(avgScore / 100),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Center(
                  child: Text('$avgScore%', style: AppText.style(size: 22, weight: FontWeight.w800, spacing: -0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OVERALL ACCURACY', style: AppText.overline(color: AppColors.textMuted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primaryLight, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_results.length}',
                      style: AppText.style(size: 24, weight: FontWeight.w800, spacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    Text('quizzes', style: AppText.style(size: 13, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_gradeGroupedResults.length} grade${_gradeGroupedResults.length == 1 ? '' : 's'} practiced',
                  style: AppText.style(size: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChartsByGrade() {
    final List<Widget> widgets = [];
    final sortedGrades = _gradeGroupedResults.keys.toList()..sort();

    for (var grade in sortedGrades) {
      final gradeResults = _results.where((res) => res.grade == grade).toList();
      final totalQuizzes = gradeResults.length;
      final avgAccuracy = totalQuizzes == 0
          ? 0
          : (gradeResults.fold(0, (sum, res) => sum + res.score) /
                  gradeResults.fold(0, (sum, res) => sum + res.totalQuestions) *
                  100)
              .toInt();

      widgets.add(SectionLabel('${Grades.label(grade)} analysis', icon: Icons.analytics_rounded));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildGradeSummaryRow(totalQuizzes, avgAccuracy));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildChartContainer(grade, _gradeGroupedResults[grade]!));
      widgets.add(const SizedBox(height: 24));
      widgets.add(SectionLabel('Latest for ${Grades.label(grade)}', icon: Icons.history_rounded, color: AppColors.cyan));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildRecentAttemptsListForGrade(grade));
      widgets.add(const SizedBox(height: 36));
    }

    return widgets;
  }

  Widget _buildGradeSummaryRow(int quizzes, int accuracy) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Pill(label: '$quizzes quizzes', icon: Icons.assignment_rounded, color: AppColors.primary),
        Pill(label: '$accuracy% accuracy', icon: Icons.auto_graph_rounded, color: AppColors.success),
      ],
    );
  }

  Widget _buildChartContainer(int grade, Map<String, List<QuizResult>> subjectGrouped) {
    if (subjectGrouped.isEmpty) return const SizedBox();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 28, 20, 12),
      child: SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 100,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface,
                tooltipBorder: BorderSide(color: AppColors.glassStroke),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final subject = subjectGrouped.keys.elementAt(groupIndex);
                  return BarTooltipItem(
                    '$subject\n',
                    AppText.style(size: 12, weight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: '${rod.toY.toInt()}%',
                        style: AppText.style(size: 16, weight: FontWeight.w800, color: AppColors.cyan),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < subjectGrouped.length) {
                      final label = subjectGrouped.keys.elementAt(value.toInt());
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            label,
                            style: AppText.style(size: 9, weight: FontWeight.w700, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                  reservedSize: 80,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value % 25 == 0) {
                      return Text(
                        '${value.toInt()}%',
                        style: AppText.style(size: 9, weight: FontWeight.w700, color: AppColors.textFaint),
                      );
                    }
                    return const SizedBox();
                  },
                  reservedSize: 32,
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: _generateBarGroups(subjectGrouped),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(Map<String, List<QuizResult>> subjectGrouped) {
    final List<BarChartGroupData> groups = [];
    int index = 0;

    subjectGrouped.forEach((label, results) {
      final latestResult = results.first;
      final double latestPercentage = (latestResult.score / latestResult.totalQuestions) * 100;

      groups.add(
        BarChartGroupData(
          x: index++,
          barRods: [
            BarChartRodData(
              toY: latestPercentage,
              gradient: const LinearGradient(
                colors: [AppColors.violet, AppColors.primary, AppColors.cyan],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(2)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    });

    return groups;
  }

  Widget _buildRecentAttemptsListForGrade(int grade) {
    // Get latest attempts for this grade (one per subject)
    final subjectResultsMap = _gradeGroupedResults[grade]!;
    final List<QuizResult> latestInGrade = subjectResultsMap.values.map((results) => results.first).toList();

    // Sort by date (newest first)
    latestInGrade.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: latestInGrade.map((res) => _buildResultTile(res)).toList(),
    );
  }

  Widget _buildResultTile(QuizResult res) {
    final percentage = (res.score / res.totalQuestions * 100).toInt();
    final color = AppColors.scoreColor(percentage / 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: AppRadius.md + 2,
        child: Row(
          children: [
            const IconBadge(icon: Icons.school_rounded, color: AppColors.primary, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.subjectName,
                    style: AppText.style(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Grades.label(res.grade)} • ${_formatDate(res.date)}',
                    style: AppText.style(size: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$percentage%',
                  style: AppText.style(size: 16, weight: FontWeight.w800, color: color),
                ),
                Text(
                  '${res.score}/${res.totalQuestions}',
                  style: AppText.style(size: 10, weight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
