/// EB exams are stored in the same `grade` field as school grades, using
/// reserved values (EB1 = 101, EB2 = 102, EB3 = 103), so subjects, questions,
/// sets and results work exactly like a grade. Keep in sync with the admin
/// CMS's src/utils/grades.ts.
class Grades {
  static const List<int> ebExams = [101, 102, 103];

  static bool isEbExam(int grade) => ebExams.contains(grade);

  static String label(int grade) => isEbExam(grade) ? 'EB${grade - 100}' : 'Grade $grade';
}
