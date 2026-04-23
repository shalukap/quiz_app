import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'My Progress',
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
                : _results.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCards(),
                            const SizedBox(height: 32),
                            ..._buildChartsByGrade(),
                          ],
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'No quiz data yet',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a quiz to see your progress graph!',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final avgScore = _results.isEmpty 
        ? 0 
        : (_results.fold(0, (sum, res) => sum + res.score) / _results.fold(0, (sum, res) => sum + res.totalQuestions) * 100).toInt();

    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            title: 'QUIZZES',
            value: _results.length.toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassCard(
            title: 'ACCURACY',
            value: '$avgScore%',
            icon: Icons.auto_graph_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
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
          : (gradeResults.fold(0, (sum, res) => sum + res.score) / gradeResults.fold(0, (sum, res) => sum + res.totalQuestions) * 100).toInt();

      widgets.add(_buildChartTitle('GRADE $grade ANALYSIS'));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildGradeSummaryRow(totalQuizzes, avgAccuracy));
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildChartContainer(grade, _gradeGroupedResults[grade]!));
      widgets.add(const SizedBox(height: 24));
      widgets.add(_buildRecentAttemptsTitleForGrade(grade));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildRecentAttemptsListForGrade(grade));
      widgets.add(const SizedBox(height: 48));
    }

    return widgets;
  }

  Widget _buildGradeSummaryRow(int quizzes, int accuracy) {
    return Row(
      children: [
        _buildMiniStatCard('Quizzes', quizzes.toString(), Icons.assignment_rounded, const Color(0xFF3B82F6)),
        const SizedBox(width: 12),
        _buildMiniStatCard('Accuracy', '$accuracy%', Icons.auto_graph_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            '$value $label',
            style: GoogleFonts.inter(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.analytics_rounded, color: Color(0xFF60A5FA), size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFF60A5FA),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildChartContainer(int grade, Map<String, List<QuizResult>> subjectGrouped) {
    if (subjectGrouped.isEmpty) return const SizedBox();
    
    return Container(
      height: 320,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: 100,
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              tooltipBorder: const BorderSide(color: Colors.white10),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final subject = subjectGrouped.keys.elementAt(groupIndex);
                return BarTooltipItem(
                  '$subject\n',
                  GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()}%',
                      style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900, fontSize: 16),
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
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 9, 
                            fontWeight: FontWeight.w700,
                          ),
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
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 28,
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
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _generateBarGroups(subjectGrouped),
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
                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

  Widget _buildRecentAttemptsTitleForGrade(int grade) {
    return Row(
      children: [
        const Icon(Icons.history_rounded, color: Color(0xFF60A5FA), size: 16),
        const SizedBox(width: 8),
        Text(
          'LATEST FOR GRADE $grade',
          style: GoogleFonts.inter(
            color: const Color(0xFF60A5FA),
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAttemptsListForGrade(int grade) {
    // Get latest attempts for this grade (one per subject)
    final subjectResultsMap = _gradeGroupedResults[grade]!;
    final List<QuizResult> latestInGrade = subjectResultsMap.values
        .map((results) => results.first)
        .toList();

    // Sort by date (newest first)
    latestInGrade.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: latestInGrade.map((res) => _buildResultTile(res)).toList(),
    );
  }

  Widget _buildResultTile(QuizResult res) {
    final percentage = (res.score / res.totalQuestions * 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF60A5FA), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.subjectName,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Grade ${res.grade} • ${_formatDate(res.date)}',
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  color: percentage >= 75 ? const Color(0xFF10B981) : (percentage >= 50 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                '${res.score}/${res.totalQuestions}',
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
