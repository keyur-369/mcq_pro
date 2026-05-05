import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:mcq_test_app/models/question.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://hlygfkobyemsjgjuqdhi.supabase.co', 
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhseWdma29ieWVtc2pnanVxZGhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMzg3NDksImV4cCI6MjA5MjYxNDc0OX0.gYl44Ki2p0WQCUl0hWdvbNIaNzI17xmnp5JnlHsluZk',
    );
  }

  // --- Auth ---
  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> login(String email, String password) async {
    return await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await supabase.from('users').select().eq('id', userId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<AuthResponse> signup({
    required String email,
    required String password,
    required String role,
    int? studentClass,
    String? division,
    String? rollNo,
    String? studentGroup,
    String? name,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'class': studentClass,
        'division': division,
        'roll_no': rollNo,
        'student_group': studentGroup,
        'name': name,
      },
    );
    
    if (response.user != null) {
      await _saveUserToTable(
        id: response.user!.id,
        email: email,
        role: role,
        studentClass: studentClass,
        division: division,
        rollNo: rollNo,
        studentGroup: studentGroup,
        name: name,
      );
    }
    return response;
  }

  Future<void> _saveUserToTable({
    required String id,
    required String email,
    required String role,
    int? studentClass,
    String? division,
    String? rollNo,
    String? studentGroup,
    String? name,
  }) async {
    await supabase.from('users').insert({
      'id': id,
      'role': role,
      'email': email,
      'class': studentClass,
      'division': division,
      'roll_no': rollNo,
      'student_group': studentGroup,
      'name': name,
    });
  }

  // --- Tests ---
  Future<String> createTest(Test test) async {
    final response = await supabase.from('tests').insert(test.toMap()).select().single();
    return response['id'];
  }

  Future<void> updateTest(String testId, TestStatus status) async {
    await supabase.from('tests').update({
      'status': status.name,
    }).eq('id', testId);
  }

  Future<void> saveQuestions(List<Question> questions) async {
    final maps = questions.map((q) => q.toMap()).toList();
    await supabase.from('questions').insert(maps);
  }

  Future<List<Test>> getTeacherTests(String teacherId) async {
    final response = await supabase
        .from('tests')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Test.fromMap(e)).toList();
  }

  Future<List<Test>> getAvailableTests(int studentClass) async {
    final userId = currentUser!.id;
    
    // Get user profile to check student group
    final userProfileResponse = await supabase
        .from('users')
        .select('student_group')
        .eq('id', userId)
        .maybeSingle();
        
    final studentGroup = userProfileResponse?['student_group'] as String?;

    // Get attempts for this user
    final attemptsResponse = await supabase
        .from('attempts')
        .select('test_id')
        .eq('student_id', userId);
        
    final attemptedTestIds = (attemptsResponse as List)
        .map((e) => e['test_id'] as String)
        .toSet();

    final response = await supabase
        .from('tests')
        .select()
        .eq('class', studentClass)
        .eq('status', 'published')
        .order('created_at', ascending: false);
        
    final allTests = (response as List).map((e) => Test.fromMap(e)).toList();
    
    // Filter out attempted tests and tests not applicable to the student's group
    return allTests.where((test) {
      if (attemptedTestIds.contains(test.id)) return false;
      
      // Group filtering logic
      if (test.subject == 'Math' && studentGroup != 'Maths') return false;
      if (test.subject == 'Biology' && studentGroup != 'Biology') return false;
      
      return true;
    }).toList();
  }

  Future<Test?> getPublishedTestByCode(String testCode) async {
    final normalizedCode = testCode.trim().toLowerCase();
    if (normalizedCode.isEmpty) return null;

    try {
      final response = await supabase
          .from('tests')
          .select()
          .eq('test_code', normalizedCode)
          .eq('status', 'published')
          .maybeSingle();

      if (response == null) return null;
      return Test.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAttemptedTest(String testId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;

    final response = await supabase
        .from('attempts')
        .select('id')
        .eq('student_id', userId)
        .eq('test_id', testId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  // --- Attempts & Answers ---
  Future<void> submitAttempt({
    required String testId,
    required int score,
    required Map<String, String> selectedAnswers, // questionId: option
  }) async {
    final userId = currentUser!.id;
    
    // 1. Save attempt
    final attemptResponse = await supabase.from('attempts').insert({
      'student_id': userId,
      'test_id': testId,
      'score': score,
    }).select().single();
    
    final attemptId = attemptResponse['id'];

    // 2. Save answers
    final List<Map<String, dynamic>> answersList = [];
    selectedAnswers.forEach((qId, val) {
      answersList.add({
        'attempt_id': attemptId,
        'question_id': qId,
        'selected_answer': val,
      });
    });

    await supabase.from('answers').insert(answersList);
  }

  Future<List<Question>> getTestQuestions(String testId) async {
    final response = await supabase.from('questions').select().eq('test_id', testId);
    return (response as List).map((e) => Question.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentHistory() async {
    final userId = currentUser!.id;
    final response = await supabase
        .from('attempts')
        .select('*, tests(*)')
        .eq('student_id', userId)
        .order('submitted_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<List<Map<String, dynamic>>> getTeacherTestAttempts() async {
    final teacherId = currentUser!.id;
    final response = await supabase
        .from('attempts')
        .select('*, tests!inner(*), users!student_id(email, name, class, student_group)')
        .eq('tests.teacher_id', teacherId)
        .order('submitted_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<Map<String, String>> getAttemptAnswers(String attemptId) async {
    final response = await supabase
        .from('answers')
        .select('question_id, selected_answer')
        .eq('attempt_id', attemptId);
        
    final map = <String, String>{};
    for (var row in (response as List)) {
      map[row['question_id'] as String] = row['selected_answer'] as String;
    }
    return map;
  }
}
