import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';

class TeacherResultsScreen extends StatefulWidget {
  const TeacherResultsScreen({super.key});

  @override
  State<TeacherResultsScreen> createState() => _TeacherResultsScreenState();
}

class _TeacherResultsScreenState extends State<TeacherResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClass = 'All';
  String _selectedGroup = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Results'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by student name...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClass,
                            isExpanded: true,
                            icon: const Icon(Icons.filter_list, size: 18),
                            items: ['All', '11', '12']
                                .map((e) => DropdownMenuItem(value: e, child: Text('Class $e')))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedClass = val!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGroup,
                            isExpanded: true,
                            icon: const Icon(Icons.science_outlined, size: 18),
                            items: ['All', 'Biology', 'Maths']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedGroup = val!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService().getTeacherTestAttempts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allAttempts = snapshot.data ?? [];
          final attempts = allAttempts.where((attempt) {
            final userData = attempt['users'];
            if (userData == null) return false;

            final studentName = (userData['name'] ?? userData['email'] ?? '').toString().toLowerCase();
            final studentClass = (userData['class'] ?? '').toString();
            final studentGroup = (userData['student_group'] ?? '').toString();

            final matchesSearch = studentName.contains(_searchQuery);
            final matchesClass = _selectedClass == 'All' || studentClass == _selectedClass;
            final matchesGroup = _selectedGroup == 'All' || studentGroup == _selectedGroup;

            return matchesSearch && matchesClass && matchesGroup;
          }).toList();

          if (attempts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text(
                  _searchQuery.isEmpty && _selectedClass == 'All' && _selectedGroup == 'All'
                      ? 'No student attempts yet.' 
                      : 'No students found matching your filters.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              final testData = attempt['tests']; 
              final userData = attempt['users'];
              
              if (testData == null) return const SizedBox.shrink(); 

              final attemptId = attempt['id'] as String;
              final testId = testData['id'] as String;
              final subject = testData['subject'] as String? ?? 'Unknown Subject';
              final topic = testData['topic'] as String? ?? 'Unknown Topic';
              final score = attempt['score'] as int? ?? 0;
              final submittedAtStr = attempt['submitted_at'] as String?;
              
              String studentDisplayName = 'Unknown Student';
              if (userData != null) {
                studentDisplayName = userData['name'] ?? userData['email'] ?? 'Unknown Student';
              }

              DateTime? submittedAt;
              if (submittedAtStr != null) {
                submittedAt = DateTime.tryParse(submittedAtStr);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$subject: $topic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'Student: $studentDisplayName',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: $score',
                              style: const TextStyle(color: AppColors.boardGreen, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (submittedAt != null)
                              Text(
                                'Date: ${DateFormat.yMMMd().add_jm().format(submittedAt.toLocal())}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openResultPreview(context, attemptId, testId, score),
                        icon: const Icon(Icons.remove_red_eye, size: 18),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openResultPreview(BuildContext context, String attemptId, String testId, int score) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = SupabaseService();
      final questions = await supabase.getTestQuestions(testId);
      final selectedAnswers = await supabase.getAttemptAnswers(attemptId);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: score,
              total: questions.length,
              questions: questions,
              selectedAnswers: selectedAnswers,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load test details: $e')),
        );
      }
    }
  }
}
