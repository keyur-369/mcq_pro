import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/models/test.dart';

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
  bool _onlyNeedsSupport = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppGradientBackground(
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildFilters(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: SupabaseService().getTeacherTestAttempts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  }

                  final allAttempts = snapshot.data ?? [];
                  final attempts = allAttempts.where((attempt) {
                    final userData = attempt['users'];
                    if (userData == null) return false;

                    final studentName = (userData['name'] ?? userData['email'] ?? '').toString().toLowerCase();
                    final studentClass = (userData['class'] ?? '').toString();
                    final studentGroup = (userData['student_group'] ?? '').toString();
                    final score = attempt['score'] as int? ?? 0;

                    final matchesSearch = studentName.contains(_searchQuery);
                    final matchesClass = _selectedClass == 'All' || studentClass == _selectedClass;
                    final matchesGroup = _selectedGroup == 'All' || studentGroup == _selectedGroup;
                    final matchesSupport = !_onlyNeedsSupport || score < 5;

                    return matchesSearch && matchesClass && matchesGroup && matchesSupport;
                  }).toList();

                  if (attempts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 80,
                            color: AppColors.textMuted.withOpacity(0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty && _selectedClass == 'All' && _selectedGroup == 'All' && !_onlyNeedsSupport
                                ? 'No student attempts yet'
                                : 'No matching results found',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return AnimatedPage(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: attempts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildAttemptCard(attempts[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search student name...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedClass,
                      isExpanded: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      icon: const Icon(
                        Icons.filter_list_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      items: ['All', '11', '12']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 'All' ? 'All Classes' : 'Class $e'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedClass = val!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroup,
                      isExpanded: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      icon: const Icon(
                        Icons.science_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      items: ['All', 'Biology', 'Maths']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 'All' ? 'All Groups' : e),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedGroup = val!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Students Needing Support (<50%)'),
            selected: _onlyNeedsSupport,
            selectedColor: AppColors.error.withOpacity(0.15),
            labelStyle: TextStyle(
              color: _onlyNeedsSupport ? AppColors.error : AppColors.textSecondary,
              fontWeight: _onlyNeedsSupport ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (val) => setState(() => _onlyNeedsSupport = val),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final testData = attempt['tests'];
    final userData = attempt['users'];
    if (testData == null) return const SizedBox.shrink();

    final attemptId = attempt['id'] as String;
    final testId = testData['id'] as String;
    final subject = testData['subject'] as String? ?? 'Unknown Subject';
    final topic = testData['topic'] as String? ?? 'Unknown Topic';
    final score = attempt['score'] as int? ?? 0;
    final submittedAtStr = attempt['submitted_at'] as String?;
    final studentDisplayName = userData != null
        ? (userData['name'] ?? userData['email'] ?? 'Unknown')
        : 'Unknown';
    final rollNo = userData != null ? userData['roll_no']?.toString() : null;

    DateTime? submittedAt;
    if (submittedAtStr != null) submittedAt = DateTime.tryParse(submittedAtStr);

    final testModel = testData is Map<String, dynamic> ? Test.fromMap(testData) : null;

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: score < 5 ? AppColors.error.withOpacity(0.1) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person_rounded,
              color: score < 5 ? AppColors.error : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      studentDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (rollNo != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Roll #$rollNo',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$subject: $topic',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (submittedAt != null)
                  Text(
                    DateFormat.yMMMd().format(submittedAt.toLocal()),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score pts',
                style: TextStyle(
                  color: score >= 8
                      ? AppColors.success
                      : (score >= 5 ? AppColors.primary : AppColors.error),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _openResultPreview(context, attemptId, testId, score, test: testModel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Review & PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openResultPreview(
    BuildContext context,
    String attemptId,
    String testId,
    int score, {
    Test? test,
  }) async {
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
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: score,
              total: questions.length,
              questions: questions,
              selectedAnswers: selectedAnswers,
              test: test,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
