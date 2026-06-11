import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/quiz_models.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _temporaryPhotoUrl;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        await _uploadImage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(File image) async {
    setState(() => _isUploading = true);

    try {
      final uid = AppState.currentUid;
      if (uid == null) throw Exception('User ID not found');
      
      final extension = path.extension(image.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$uid$extension');

      // Upload file
      await storageRef.putFile(image);
      
      // Get download URL
      final photoUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirestoreService().updateUserProfilePhoto(uid, photoUrl);

      setState(() {
        _temporaryPhotoUrl = photoUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: Text('Camera', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: Text('Gallery', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
          'My Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.5,
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
      body: Stack(
        children: [
          _buildBackground(),
          FutureBuilder(
            future: Future.wait([
              FirestoreService().getUserProfile(AppState.currentUsername ?? 'guest'),
              FirestoreService().getRecentResults(AppState.currentUsername ?? 'guest'),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
              }

              final profile = snapshot.data?[0] as UserProfile?;
              final recentResults = (snapshot.data?[1] as List<QuizResult>?) ?? [];

              final username = profile?.username ?? 'Guest User';
              
              // Group results by grade and calculate stats
              final Map<int, List<QuizResult>> groupedResults = {};
              for (var result in recentResults) {
                groupedResults.putIfAbsent(result.grade, () => []).add(result);
              }
              final sortedGrades = groupedResults.keys.toList()..sort((a, b) => b.compareTo(a));

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildProfileHeader(username, profile?.photoUrl),
                      const SizedBox(height: 40),
                      
                      if (sortedGrades.isEmpty)
                        _buildEmptyState()
                      else
                        ...sortedGrades.map((grade) {
                          final results = groupedResults[grade]!;
                          final quizzesCount = results.length;
                          final totalPoints = results.fold(0, (sum, r) => sum + (r.score * 10));
                          final avgAccuracy = (results.fold(0.0, (sum, r) => sum + r.percentage) / quizzesCount * 100).toStringAsFixed(0);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                                  child: Text(
                                    'Grade $grade Performance',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                _buildStatsRow(
                                  quizzesCount.toString(),
                                  totalPoints.toString(),
                                  '$avgAccuracy%',
                                ),
                                const SizedBox(height: 16),
                                _GradeTrendChart(
                                  results: results,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ],
                            ),
                          );
                        }),

                      _buildMenuItems(context),
                      const SizedBox(height: 40),
                      _buildAppInfo(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
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

  Widget _buildProfileHeader(String username, String? profilePhotoUrl) {
    final displayPhotoUrl = _temporaryPhotoUrl ?? profilePhotoUrl;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: displayPhotoUrl != null
                        ? Image.network(
                            displayPhotoUrl,
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person_rounded,
                              size: 54,
                              color: Colors.white24,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 54,
                            color: Colors.white24,
                          ),
                  ),
                  if (_isUploading)
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F172A), width: 3),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          username,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'Quiz Enthusiast',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(String quizzes, String points, String accuracy) {
    return Row(
      children: [
        _StatCard(
          label: 'Quizzes',
          value: quizzes,
          icon: Icons.quiz_outlined,
          color: const Color(0xFF818CF8),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Points',
          value: points,
          icon: Icons.bolt_rounded,
          color: const Color(0xFFFBBF24),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Accuracy',
          value: accuracy,
          icon: Icons.track_changes_rounded,
          color: const Color(0xFF34D399),
        ),
      ],
    );
  }


  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, color: Colors.white.withValues(alpha: 0.1), size: 48),
          const SizedBox(height: 16),
          Text(
            'No tests taken yet',
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Column(
      children: [
        _MenuItem(
          icon: Icons.history_rounded,
          title: 'Quiz History',
          onTap: () => Navigator.pushNamed(context, '/history'),
        ),
        _MenuItem(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved Questions',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Help Center',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _MenuItem(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          isDestructive: true,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
        ),
      ],
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        Text(
          'QuizMaster',
          style: GoogleFonts.inter(
            color: Colors.white10,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 1.2.1',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.05),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDestructive
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    icon,
                    color: isDestructive ? const Color(0xFFF87171) : Colors.white30,
                    size: 22,
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isDestructive ? const Color(0xFFF87171) : Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDestructive ? const Color(0xFFF87171).withValues(alpha: 0.3) : Colors.white10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeTrendChart extends StatelessWidget {
  final List<QuizResult> results;
  final Color color;

  const _GradeTrendChart({required this.results, required this.color});

  @override
  Widget build(BuildContext context) {
    // Get last 10 results, oldest first
    final trendData = results.reversed.take(10).toList().reversed.toList();
    if (trendData.isEmpty) return const SizedBox();

    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 50 == 0) {
                    return Text(
                      '${value.toInt()}%',
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trendData.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: trendData.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.percentage * 100);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.5), color],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
