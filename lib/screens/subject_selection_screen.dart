import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../config/grades.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

class SubjectSelectionScreen extends StatelessWidget {
  const SubjectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final grade = args?['grade'] ?? 10;
    final medium = args?['medium'] as String? ?? 'English';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(context, title: 'Subjects'),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: StepProgress(step: 2, total: 5),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeSlideIn(
                  child: PageHeader(
                    overline: '${Grades.label(grade)} · $medium',
                    title: 'What would you\nlike to study?',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _buildSubjectList(context, grade, medium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectList(BuildContext context, int grade, String medium) {
    return FutureBuilder<List<Subject>>(
      future: FirestoreService().getSubjects(grade, medium: medium),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            subtitle: 'Error loading $medium subjects',
          );
        }

        final subjects = snapshot.data ?? [];
        if (subjects.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No subjects yet',
            subtitle: 'No subjects found for $medium.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          itemCount: subjects.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final subject = subjects[index];

            IconData iconData = Icons.book_rounded;
            if (subject.iconName == 'functions') iconData = Icons.functions_rounded;
            if (subject.iconName == 'science') iconData = Icons.science_rounded;
            if (subject.iconName == 'history') iconData = Icons.history_edu_rounded;
            if (subject.iconName == 'language') iconData = Icons.language_rounded;

            return FadeSlideIn(
              index: index,
              child: _SubjectCard(
                subject: subject,
                iconData: iconData,
                fallbackColor: AppColors.accentAt(index),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/buckets',
                    arguments: {
                      'grade': grade,
                      'subjectId': subject.id,
                      'subjectName': subject.name,
                      'medium': medium,
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final IconData iconData;
  final Color fallbackColor;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.iconData,
    required this.fallbackColor,
    required this.onTap,
  });

  Color get _color {
    try {
      return Color(int.parse(subject.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallbackColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(icon: iconData, color: color, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: AppText.style(size: 16, weight: FontWeight.w700, spacing: -0.2),
                ),
                const SizedBox(height: 6),
                Pill(label: 'Practice quiz', color: color, icon: Icons.bolt_rounded),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
