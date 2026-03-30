import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // USER PROFILES
  Future<UserProfile?> getUserProfile(String username) async {
    final snapshot = await _db.collection('users')
        .where('username', isEqualTo: username)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return UserProfile.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  Future<UserProfile?> getUserProfileByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> createUserProfile(String username, {String? email, String? uid, String? password}) async {
    final profile = UserProfile(
      username: username,
      points: 0,
      quizzesTaken: 0,
      accuracy: 0.0,
      createdAt: DateTime.now(),
      password: password,
      email: email,
      uid: uid,
    );
    final docId = uid ?? username;
    await _db.collection('users').doc(docId).set(profile.toMap());
  }

  // SUBJECTS
  Future<List<Subject>> getSubjects(int grade, {String? medium}) async {
    Query query = _db.collection('subjects')
        .where('grade', isEqualTo: grade);
    
    if (medium != null) {
      query = query.where('medium', isEqualTo: medium);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Subject.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }


  // QUESTIONS
  Future<List<Question>> getQuestions(String subjectId, int grade, {String? medium, String? bucketId}) async {
    Query query = _db.collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('grade', isEqualTo: grade);
    
    if (bucketId != null) {
      query = query.where('bucketId', isEqualTo: bucketId);
    }
    
    final snapshot = await query.get();
    final questions = snapshot.docs.map((doc) => Question.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    
    if (medium != null) {
      return questions.where((q) => q.medium == medium).toList();
    }
    
    return questions;
  }

  // BUCKETS
  Future<List<Bucket>> getBuckets(String subjectId, int grade, {String? medium}) async {
    // 1. Fetch questions to group by bucket
    Query query = _db.collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('grade', isEqualTo: grade);
    
    final snapshot = await query.get();
    final questions = snapshot.docs.map((doc) => Question.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

    // 2. Filter by medium
    final filtered = (medium != null)
        ? questions.where((q) => q.medium == medium).toList()
        : questions;

    // 3. Group by bucketId
    final Map<String, Bucket> bucketMap = {};
    for (var q in filtered) {
      final bid = q.bucketId ?? 'default';
      final bname = q.bucketName ?? 'Untitled Set';
      
      if (!bucketMap.containsKey(bid)) {
        bucketMap[bid] = Bucket(id: bid, name: bname, questionCount: 1);
      } else {
        final existing = bucketMap[bid]!;
        bucketMap[bid] = Bucket(
          id: bid,
          name: bname,
          questionCount: existing.questionCount + 1,
        );
      }
    }
    
    return bucketMap.values.toList();
  }

  // RESULTS
  Future<void> saveQuizResult({
    required String username,
    required String subjectId,
    required String subjectName,
    required int score,
    required int totalQuestions,
    required List<int> userAnswers,
  }) async {
    // 1. Save Result Document
    final resultRef = _db.collection('results').doc();
    final result = QuizResult(
      id: resultRef.id,
      userId: username,
      subjectId: subjectId,
      subjectName: subjectName,
      score: score,
      totalQuestions: totalQuestions,
      date: DateTime.now(),
      userAnswers: userAnswers,
    );
    await resultRef.set({
      'userId': result.userId,
      'subjectId': result.subjectId,
      'subjectName': result.subjectName,
      'score': result.score,
      'totalQuestions': result.totalQuestions,
      'date': Timestamp.fromDate(result.date),
      'userAnswers': result.userAnswers,
    });

    // 2. Update User Profile Stats
    final userDoc = await _db.collection('users').doc(username).get();
    if (userDoc.exists) {
      final currentProfile = UserProfile.fromMap(userDoc.data()!);
      final newPoints = currentProfile.points + (score * 10);
      final newQuizzesTaken = currentProfile.quizzesTaken + 1;
      
      // Calculate new accuracy
      final newQuizAccuracy = totalQuestions > 0 ? (score / totalQuestions) : 0.0;
      final avgAccuracy = ((currentProfile.accuracy * currentProfile.quizzesTaken) + newQuizAccuracy) / newQuizzesTaken;

      await _db.collection('users').doc(username).update({
        'points': newPoints,
        'quizzesTaken': newQuizzesTaken,
        'accuracy': avgAccuracy,
      });
    }
  }

  // RECENT RESULTS for Profile Screen
  Future<List<QuizResult>> getRecentResults(String username) async {
    final snapshot = await _db.collection('results')
        .where('userId', isEqualTo: username)
        .get();
    
    final results = snapshot.docs.map((doc) => QuizResult.fromMap(doc.id, doc.data())).toList();
    // Sort locally to avoid requiring composite indexes in Firestore
    results.sort((a, b) => b.date.compareTo(a.date));
    return results.take(10).toList();
  }
}
