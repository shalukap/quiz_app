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

  Future<void> createUserProfile(String username, {String? email, String? uid, String? password, String? photoUrl}) async {
    final profile = UserProfile(
      username: username,
      points: 0,
      quizzesTaken: 0,
      accuracy: 0.0,
      createdAt: DateTime.now(),
      password: password,
      email: email,
      uid: uid,
      photoUrl: photoUrl,
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
    final allSubjects = snapshot.docs.map((doc) => Subject.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

    // Filter to only include subjects that have at least one question in the database
    final List<Subject> activeSubjects = [];
    final List<Future<QuerySnapshot>> questionChecks = [];
    
    for (var subject in allSubjects) {
      Query qCheck = _db.collection('questions')
          .where('grade', isEqualTo: grade)
          .where('subjectId', isEqualTo: subject.id);
      if (medium != null) {
        qCheck = qCheck.where('medium', isEqualTo: medium);
      }
      questionChecks.add(qCheck.limit(1).get());
    }
    
    final checks = await Future.wait(questionChecks);
    for (int i = 0; i < allSubjects.length; i++) {
      if (checks[i].docs.isNotEmpty) {
        activeSubjects.add(allSubjects[i]);
      }
    }
    
    return activeSubjects;
  }

  Future<List<int>> getActiveGrades() async {
    final List<Future<QuerySnapshot>> futures = [];
    for (int grade = 1; grade <= 13; grade++) {
      futures.add(
        _db.collection('questions')
            .where('grade', isEqualTo: grade)
            .limit(1)
            .get()
      );
    }
    final snapshots = await Future.wait(futures);
    final activeGrades = <int>[];
    for (int i = 0; i < snapshots.length; i++) {
      if (snapshots[i].docs.isNotEmpty) {
        activeGrades.add(i + 1);
      }
    }
    return activeGrades;
  }


  // QUESTIONS
  Future<List<Question>> getQuestions(String? subjectId, int grade, {String? medium, String? bucketId}) async {
    Query query = _db.collection('questions')
        .where('grade', isEqualTo: grade);
    
    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }
    
    // If it's a numeric bucketNumber (passed as bucketId string)
    int? bucketNumber = int.tryParse(bucketId ?? '');
    
    // If it's a virtual set (e.g. "set_1", "set_2")
    bool isVirtualSet = bucketId != null && bucketId.startsWith('set_');
    
    if (bucketNumber != null && !isVirtualSet) {
      query = query.where('bucketNumber', isEqualTo: bucketNumber);
    }
    
    final snapshot = await query.get();
    var questions = snapshot.docs.map((doc) => Question.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    
    if (medium != null) {
      questions = questions.where((q) => q.medium == medium).toList();
    }

    // Group by scenario to ensure sequential display
    if (questions.any((q) => (q.scenarioText != null && q.scenarioText!.isNotEmpty) || 
                             (q.scenarioImageUrl != null && q.scenarioImageUrl!.isNotEmpty))) {
      final List<Question> groupedQuestions = [];
      final Set<String> processedScenarios = {};

      for (var q in questions) {
        final scenarioKey = (q.scenarioText ?? '') + (q.scenarioImageUrl ?? '');
        if (scenarioKey.isEmpty) {
          groupedQuestions.add(q);
        } else if (!processedScenarios.contains(scenarioKey)) {
          // Find all questions with this exact scenario and add them together
          final scenarioGroup = questions.where((other) {
            final otherKey = (other.scenarioText ?? '') + (other.scenarioImageUrl ?? '');
            return otherKey == scenarioKey;
          }).toList();
          
          groupedQuestions.addAll(scenarioGroup);
          processedScenarios.add(scenarioKey);
        }
      }
      questions = groupedQuestions;
    }

    if (isVirtualSet) {
      final setIndex = int.tryParse(bucketId.replaceFirst('set_', '')) ?? 1;
      final start = (setIndex - 1) * 20;
      final end = start + 20;
      
      if (start >= questions.length) return [];
      return questions.sublist(start, end.clamp(0, questions.length));
    }
    
    return questions;
  }

  // BUCKETS
  Future<List<Bucket>> getBuckets(String? subjectId, int grade, {String? medium}) async {
    // 1. Fetch questions to group by bucket
    Query query = _db.collection('questions')
        .where('grade', isEqualTo: grade);
        
    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }
    
    final snapshot = await query.get();
    final allQuestions = snapshot.docs.map((doc) => Question.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

    // 2. Filter by medium
    final filtered = (medium != null)
        ? allQuestions.where((q) => q.medium == medium).toList()
        : allQuestions;

    if (filtered.isEmpty) return [];

    // 3. Divide all questions into virtual sets of 20
    final List<Bucket> finalBuckets = [];
    final int setSize = 20;
    final int numSets = (filtered.length / setSize).ceil();
    
    for (int i = 0; i < numSets; i++) {
      final start = i * setSize;
      final end = (start + setSize).clamp(0, filtered.length);
      final count = end - start;
      
      finalBuckets.add(Bucket(
        id: 'set_${i + 1}',
        name: 'Question Set ${i + 1}',
        questionCount: count,
      ));
    }
    
    return finalBuckets;
  }

  // RESULTS
  Future<void> saveQuizResult({
    required String username,
    required String subjectId,
    required String subjectName,
    required int grade,
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
      grade: grade,
      score: score,
      totalQuestions: totalQuestions,
      date: DateTime.now(),
      userAnswers: userAnswers,
    );
    await resultRef.set({
      'userId': result.userId,
      'subjectId': result.subjectId,
      'subjectName': result.subjectName,
      'grade': result.grade,
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
  Future<List<QuizResult>> getRecentResults(String username, {int? limit}) async {
    final snapshot = await _db.collection('results')
        .where('userId', isEqualTo: username)
        .get();
    
    final results = snapshot.docs.map((doc) => QuizResult.fromMap(doc.id, doc.data())).toList();
    // Sort locally to avoid requiring composite indexes in Firestore
    results.sort((a, b) => b.date.compareTo(a.date));
    if (limit != null) {
      return results.take(limit).toList();
    }
    return results;
  }

  Future<void> updateUserProfilePhoto(String docId, String photoUrl) async {
    await _db.collection('users').doc(docId).update({
      'photoUrl': photoUrl,
    });
  }

  // BOOKMARKS
  Future<void> toggleBookmark(String username, Question question, bool isBookmarked) async {
    final docId = '${username}_${question.id}';
    final ref = _db.collection('bookmarks').doc(docId);
    
    if (isBookmarked) {
      await ref.set({
        'userId': username,
        'questionId': question.id,
        'savedAt': FieldValue.serverTimestamp(),
        'question': question.toMap(),
      });
    } else {
      await ref.delete();
    }
  }

  Future<Set<String>> getBookmarkedQuestionIds(String username) async {
    final snapshot = await _db.collection('bookmarks')
        .where('userId', isEqualTo: username)
        .get();
    return snapshot.docs.map((doc) => doc.data()['questionId'] as String).toSet();
  }

  Future<List<Question>> getBookmarkedQuestions(String username) async {
    final snapshot = await _db.collection('bookmarks')
        .where('userId', isEqualTo: username)
        .get();
    
    final bookmarks = snapshot.docs.map((doc) {
      final data = doc.data();
      final qData = data['question'] as Map<String, dynamic>;
      final qId = data['questionId'] as String;
      return Question.fromMap(qId, qData);
    }).toList();
    
    return bookmarks;
  }
}
