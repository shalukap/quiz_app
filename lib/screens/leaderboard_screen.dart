import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark mode colors based on Stitch design
    const backgroundColor = Color(0xFF0F172A);
    const cardColor = Color(0xFF1E293B);
    const goldColor = Color(0xFFFBBF24);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Leaderboard',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Top 3 Podium
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PodiumItem(
                  rank: 2,
                  name: 'Alex R.',
                  score: '2,840',
                  height: 120,
                  color: Colors.grey.shade400,
                ),
                _PodiumItem(
                  rank: 1,
                  name: 'Sarah J.',
                  score: '3,120',
                  height: 160,
                  color: goldColor,
                  isWinner: true,
                ),
                _PodiumItem(
                  rank: 3,
                  name: 'Mike D.',
                  score: '2,650',
                  height: 100,
                  color: Colors.brown.shade400,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Leaderboard List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                itemCount: 7,
                separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
                itemBuilder: (context, index) {
                  final rank = index + 4;
                  return _LeaderboardTile(
                    rank: rank,
                    name: _dummyNames[index],
                    score: '${3000 - (rank * 100)} pts',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final int rank;
  final String name;
  final String score;
  final double height;
  final Color color;
  final bool isWinner;

  const _PodiumItem({
    required this.rank,
    required this.name,
    required this.score,
    required this.height,
    required this.color,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: isWinner ? 80 : 64,
              height: isWinner ? 80 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                image: const DecorationImage(
                  image: NetworkImage('https://i.pravatar.cc/150'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (isWinner)
              Positioned(
                top: -10,
                child: Icon(Icons.workspace_premium_rounded, color: color, size: 24),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Text(
          score,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final String score;

  const _LeaderboardTile({
    required this.rank,
    required this.name,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            rank.toString(),
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          score,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

const _dummyNames = [
  'Emma Watson',
  'John Doe',
  'Lisa Ray',
  'David Chen',
  'Sofia Garcia',
  'James Wilson',
  'Chloe Miller',
];
