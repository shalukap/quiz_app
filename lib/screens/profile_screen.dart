import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F172A);
    const primaryBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'My Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirestoreService().getUserProfile(AppState.currentUsername ?? 'guest'),
          FirestoreService().getRecentResults(AppState.currentUsername ?? 'guest'),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data?[0] as UserProfile?;
          final recentResults = (snapshot.data?[1] as List<QuizResult>?) ?? [];

          final username = profile?.username ?? 'Guest User';
          final quizzes = profile?.quizzesTaken.toString() ?? '0';
          final points = profile?.points.toString() ?? '0';
          final accuracy = profile != null ? '${(profile.accuracy * 100).toStringAsFixed(0)}%' : '0%';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // User Info
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=antigravity'),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Quiz Enthusiast',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Stats Row
                Row(
                  children: [
                    _StatCard(label: 'Quizzes', value: quizzes, icon: Icons.quiz_outlined, color: Colors.purple.shade400),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Points', value: points, icon: Icons.bolt_rounded, color: Colors.orange.shade400),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Accuracy', value: accuracy, icon: Icons.track_changes_rounded, color: Colors.green.shade400),
                  ],
                ),
                const SizedBox(height: 32),
                // Progress Section
                const _SectionHeader(title: 'Recent Progress'),
                const SizedBox(height: 16),
                if (recentResults.isEmpty)
                  Center(
                    child: Text(
                      'No recent quizzes found.',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  )
                else
                  ...recentResults.map((result) {
                    return _ProgressTile(
                      subject: result.subjectName,
                      progress: result.percentage,
                      score: '${result.score}/${result.totalQuestions}',
                    );
                  }),
                const SizedBox(height: 32),
            // Menu Items
            _MenuItem(icon: Icons.history_rounded, title: 'Quiz History'),
            _MenuItem(icon: Icons.bookmark_outline_rounded, title: 'Saved Questions'),
            _MenuItem(icon: Icons.notifications_none_rounded, title: 'Notifications'),
            _MenuItem(icon: Icons.help_outline_rounded, title: 'Support & Help'),
            const SizedBox(height: 24),
            // Logout
            TextButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          'View All',
          style: GoogleFonts.inter(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final String subject;
  final double progress;
  final String score;

  const _ProgressTile({
    required this.subject,
    required this.progress,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  score,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MenuItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: () {},
      ),
    );
  }
}
