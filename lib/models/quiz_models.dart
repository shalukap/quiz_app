import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String username;
  final int points;
  final int quizzesTaken;
  final double accuracy;
  final DateTime createdAt;
  final String? password; // Kept for demonstration or fallback
  final String? email;    // Added for Firebase Auth
  final String? uid;      // Added for Firebase Auth

  UserProfile({
    required this.username,
    required this.points,
    required this.quizzesTaken,
    required this.accuracy,
    required this.createdAt,
    this.password,
    this.email,
    this.uid,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      username: data['username'] ?? '',
      points: data['points'] ?? 0,
      quizzesTaken: data['quizzesTaken'] ?? 0,
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      password: data['password'],
      email: data['email'],
      uid: data['uid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'points': points,
      'quizzesTaken': quizzesTaken,
      'accuracy': accuracy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (password != null) 'password': password,
      if (email != null) 'email': email,
      if (uid != null) 'uid': uid,
    };
  }
}

class Subject {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final int grade;

  Subject({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.grade,
  });

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      name: data['name'] ?? '',
      iconName: data['iconName'] ?? '',
      colorHex: data['colorHex'] ?? '#2563EB',
      grade: data['grade'] ?? 10,
    );
  }
}

class Question {
  final String id;
  final String subjectId;
  final int grade;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String? imageUrl;
  final List<String>? optionImages; // Added

  Question({
    required this.id,
    required this.subjectId,
    required this.grade,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.imageUrl,
    this.optionImages,
  });

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    return Question(
      id: id,
      subjectId: data['subjectId'] ?? '',
      grade: data['grade'] ?? 10,
      text: data['text'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctIndex: data['correctIndex'] ?? 0,
      imageUrl: data['imageUrl'],
      optionImages: data['optionImages'] != null 
          ? List<String>.from(data['optionImages']) 
          : null,
    );
  }
}

class QuizResult {
  final String id;
  final String userId;
  final String subjectId;
  final String subjectName;
  final int score;
  final int totalQuestions;
  final DateTime date;
  final List<int> userAnswers;

  QuizResult({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.subjectName,
    required this.score,
    required this.totalQuestions,
    required this.date,
    required this.userAnswers,
  });

  factory QuizResult.fromMap(String id, Map<String, dynamic> data) {
    return QuizResult(
      id: id,
      userId: data['userId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      score: data['score'] ?? 0,
      totalQuestions: data['totalQuestions'] ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userAnswers: List<int>.from(data['userAnswers'] ?? []),
    );
  }

  double get percentage => totalQuestions > 0 ? score / totalQuestions : 0.0;
}
