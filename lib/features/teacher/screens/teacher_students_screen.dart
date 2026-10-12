import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test.dart';

/// ---------------------------------------------------------------------------
/// Liquid glass card for Teacher Students Screen
/// ---------------------------------------------------------------------------
class _TeacherGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const _TeacherGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = 20,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: (tint ?? AppColors.primary).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        base.withOpacity(0.40),
                        base.withOpacity(0.12),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 50,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.28),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: br,
                  splashColor: Colors.white.withOpacity(0.25),
                  highlightColor: Colors.white.withOpacity(0.10),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _allStudents = [];
  List<TeacherAssignment> _assignments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String _selectedSubject = 'all';
  String _selectedClass = 'all';
  String _selectedDivision = 'all';
  String _selectedMedium = 'all';
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      final assignmentsFuture = user != null
          ? _supabase.getTeacherAssignments(user.id)
          : Future.value(<TeacherAssignment>[]);
      final studentsFuture = _supabase.getAllStudents();

      final results = await Future.wait([assignmentsFuture, studentsFuture]);
      final assignments = results[0] as List<TeacherAssignment>;
      final students = results[1] as List<AppUser>;

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _allStudents = students;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Checks if a student matches a single teacher assignment
  /// based on Institution, Standard, Division, Medium/Language, and Subject compatibility
  bool _matchesAssignment(AppUser student, TeacherAssignment a) {
    // 1. Institution check
    final aInst = a.institution.trim().toLowerCase();
    final sInst = (student.institution ?? 'Sharda Mandir').trim().toLowerCase();
    if (aInst.isNotEmpty && sInst.isNotEmpty && aInst != sInst) {
      return false;
    }

    // 2. Standard (std) check
    final aStd = a.standard.trim();
    final sStd = (student.studentClass ?? '').trim();
    if (aStd != sStd) {
      return false;
    }

    // 3. Division (div) check
    final aDiv = a.division.trim().toUpperCase();
    final sDiv = (student.division ?? '').trim().toUpperCase();
    if (aDiv != 'ALL' && aDiv != sDiv) {
      return false;
    }

    // 4. Medium / Language check
    final aMed = a.medium.trim().toLowerCase();
    final sMed = (student.medium ?? 'English').trim().toLowerCase();
    if (aMed.isNotEmpty &&
        sMed.isNotEmpty &&
        aMed != 'both' &&
        aMed != 'all' &&
        aMed != sMed) {
      return false;
    }

    // 5. Subject & Group compatibility check
    final sub = a.subject.trim().toLowerCase();
    final grp = (student.studentGroup ?? '').trim().toLowerCase();
    if (grp.isNotEmpty) {
      // Biology group students do not take Math
      if ((grp == 'biology' || grp == 'b') &&
          (sub == 'math' || sub == 'maths' || sub == 'mathematics')) {
        return false;
      }
      // Maths group students do not take Biology
      if ((grp == 'math' || grp == 'maths' || grp == 'a') && sub == 'biology') {
        return false;
      }
    }

    return true;
  }

  /// Checks if student is under this teacher across any of the teacher's assignments
  bool _isStudentUnderTeacher(AppUser student) {
    if (_assignments.isEmpty) return false;
    return _assignments.any((a) => _matchesAssignment(student, a));
  }

  /// Retrieves list of subjects this teacher is assigned to teach this student
  List<String> _getTeachingSubjectsForStudent(AppUser student) {
    return _assignments
        .where((a) => _matchesAssignment(student, a))
        .map((a) => a.subject)
        .toSet()
        .toList();
  }

  /// All students that belong to this teacher under their assigned scope
  List<AppUser> get _teacherStudents {
    if (_assignments.isEmpty) return [];
    return _allStudents.where((s) => _isStudentUnderTeacher(s)).toList();
  }

  /// Filtered students for display based on search and dropdown filters
  List<AppUser> get _filteredStudents {
    final baseList = _teacherStudents;
    final query = _searchQuery.trim().toLowerCase();

    return baseList.where((student) {
      // Subject filter
      if (_selectedSubject != 'all') {
        final subs = _getTeachingSubjectsForStudent(student);
        if (!subs.any((s) => s.toLowerCase() == _selectedSubject.toLowerCase())) {
          return false;
        }
      }

      // Standard / Class filter
      if (_selectedClass != 'all' && student.studentClass != _selectedClass) {
        return false;
      }

      // Division filter
      if (_selectedDivision != 'all' &&
          (student.division ?? '').toUpperCase() != _selectedDivision.toUpperCase()) {
        return false;
      }

      // Medium / Language filter
      if (_selectedMedium != 'all' &&
          (student.medium ?? '').toLowerCase() != _selectedMedium.toLowerCase()) {
        return false;
      }

      // Status filter
      if (_selectedStatus == 'active' && !student.isActive) return false;
      if (_selectedStatus == 'disabled' && student.isActive) return false;

      // Text search
      if (query.isNotEmpty) {
        final name = (student.name ?? '').toLowerCase();
        final email = student.email.toLowerCase();
        final roll = (student.rollNo ?? '').toLowerCase();
        final div = (student.division ?? '').toLowerCase();

        final matches = name.contains(query) ||
            email.contains(query) ||
            roll.contains(query) ||
            div.contains(query);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSubject = 'all';
      _selectedClass = 'all';
      _selectedDivision = 'all';
      _selectedMedium = 'all';
      _selectedStatus = 'all';
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedSubject != 'all') count++;
    if (_selectedClass != 'all') count++;
    if (_selectedDivision != 'all') count++;
    if (_selectedMedium != 'all') count++;
    if (_selectedStatus != 'all') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _TeacherGlassCard(
              radius: 14,
              blur: 16,
              padding: const EdgeInsets.all(8),
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        title: const Text(
          'My Students',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _TeacherGlassCard(
              radius: 14,
              blur: 16,
              padding: const EdgeInsets.all(8),
              onTap: _loadData,
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text(
                        'Loading your students...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: _buildBodyContent(),
                    ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main Body Content
  // ---------------------------------------------------------------------------
  Widget _buildBodyContent() {
    // Case 1: Teacher has no teaching assignments set by Admin
    if (_assignments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          _buildSimpleMessageCard(
            icon: Icons.assignment_late_outlined,
            iconColor: AppColors.warning,
            title: 'No Teaching Assignments',
            message:
                'You have not been assigned any subjects, division, language, standard, or institution yet.\n\nPlease contact the administrator to assign your classes.',
          ),
        ],
      );
    }

    final totalTeacherStudents = _teacherStudents;

    // Case 2: Teacher has assignments, but NO students are enrolled under their scope
    if (totalTeacherStudents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildScopeOverviewCard(),
          const SizedBox(height: 30),
          _buildSimpleMessageCard(
            icon: Icons.people_outline_rounded,
            iconColor: AppColors.secondary,
            title: 'No Students Found',
            message:
                'There are currently no students enrolled under your assigned subjects, division, language, standard, and institution.',
          ),
        ],
      );
    }

    // Case 3: Teacher has students under their assigned scope
    final filtered = _filteredStudents;
    final totalCount = totalTeacherStudents.length;
    final activeCount = totalTeacherStudents.where((s) => s.isActive).length;
    final std11Count =
        totalTeacherStudents.where((s) => s.studentClass == '11').length;
    final std12Count =
        totalTeacherStudents.where((s) => s.studentClass == '12').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _buildScopeOverviewCard(),
        const SizedBox(height: 16),
        _buildHeaderHero(
          totalCount: totalCount,
          activeCount: activeCount,
          std11Count: std11Count,
          std12Count: std12Count,
        ),
        const SizedBox(height: 18),
        _buildSearchAndFilters(),
        const SizedBox(height: 16),
        _buildListHeader(filtered.length),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _buildSimpleMessageCard(
            icon: Icons.search_off_rounded,
            iconColor: AppColors.textMuted,
            title: 'No Matching Students',
            message: _searchQuery.isNotEmpty
                ? 'No students matched "$_searchQuery" in your assigned classes.'
                : 'No students matched the selected filters.',
            showResetButton: true,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildStudentCard(filtered[index]);
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Scope Overview Card (Shows assigned Institution, Subjects, Div, Lang, Std)
  // ---------------------------------------------------------------------------
  Widget _buildScopeOverviewCard() {
    final institutions =
        _assignments.map((a) => a.institution).toSet().join(', ');
    final standards =
        _assignments.map((a) => 'Std ${a.standard}').toSet().join(', ');
    final divisions =
        _assignments.map((a) => 'Div ${a.division}').toSet().join(', ');
    final mediums =
        _assignments.map((a) => a.medium).toSet().join(', ');
    final subjects =
        _assignments.map((a) => a.subject).toSet().join(', ');

    return _TeacherGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Assigned Teaching Scope',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active Scope',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildScopeChip(Icons.account_balance_rounded, institutions),
              _buildScopeChip(Icons.school_rounded, standards),
              _buildScopeChip(Icons.meeting_room_rounded, divisions),
              _buildScopeChip(Icons.translate_rounded, mediums),
              _buildScopeChip(Icons.menu_book_rounded, subjects),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Hero & Metrics
  // ---------------------------------------------------------------------------
  Widget _buildHeaderHero({
    required int totalCount,
    required int activeCount,
    required int std11Count,
    required int std12Count,
  }) {
    return _TeacherGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'Total',
              value: '$totalCount',
              icon: Icons.person_outline_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Active',
              value: '$activeCount',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Std 11',
              value: '$std11Count',
              icon: Icons.school_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Std 12',
              value: '$std12Count',
              icon: Icons.workspace_premium_outlined,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & Filters
  // ---------------------------------------------------------------------------
  Widget _buildSearchAndFilters() {
    // Unique options derived strictly from the teacher's active assignments
    final assignedSubjects =
        _assignments.map((a) => a.subject.trim()).toSet().toList();
    final assignedStandards =
        _assignments.map((a) => a.standard.trim()).toSet().toList();
    final assignedDivisions =
        _assignments.map((a) => a.division.trim().toUpperCase()).toSet().toList();
    final assignedMediums =
        _assignments.map((a) => a.medium.trim()).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        _TeacherGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          radius: 18,
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, roll no, email...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textMuted,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filter Dropdowns Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (_activeFilterCount > 0) ...[
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_rounded, size: 13),
                  label: Text('Clear ($_activeFilterCount)'),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                  backgroundColor: AppColors.error.withOpacity(0.12),
                  side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _clearAllFilters,
                ),
                const SizedBox(width: 8),
              ],

              // Subject Filter
              if (assignedSubjects.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Subject',
                  currentValue: _selectedSubject,
                  options: [
                    {'val': 'all', 'label': 'All Subjects'},
                    ...assignedSubjects.map(
                      (s) => {'val': s, 'label': s},
                    ),
                  ],
                  onSelected: (val) => setState(() => _selectedSubject = val),
                ),
                const SizedBox(width: 8),
              ],

              // Standard Filter
              if (assignedStandards.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Standard',
                  currentValue: _selectedClass,
                  options: [
                    {'val': 'all', 'label': 'All Standards'},
                    ...assignedStandards.map(
                      (s) => {'val': s, 'label': 'Std $s'},
                    ),
                  ],
                  onSelected: (val) => setState(() => _selectedClass = val),
                ),
                const SizedBox(width: 8),
              ],

              // Division Filter
              if (assignedDivisions.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Division',
                  currentValue: _selectedDivision,
                  options: [
                    {'val': 'all', 'label': 'All Divisions'},
                    ...assignedDivisions.map(
                      (d) => {'val': d, 'label': 'Div $d'},
                    ),
                  ],
                  onSelected: (val) => setState(() => _selectedDivision = val),
                ),
                const SizedBox(width: 8),
              ],

              // Medium Filter
              if (assignedMediums.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Language',
                  currentValue: _selectedMedium,
                  options: [
                    {'val': 'all', 'label': 'All Languages'},
                    ...assignedMediums.map(
                      (m) => {'val': m, 'label': m},
                    ),
                  ],
                  onSelected: (val) => setState(() => _selectedMedium = val),
                ),
                const SizedBox(width: 8),
              ],

              // Status Filter
              _buildFilterDropdown(
                label: 'Status',
                currentValue: _selectedStatus,
                options: const [
                  {'val': 'all', 'label': 'All Status'},
                  {'val': 'active', 'label': 'Active Only'},
                  {'val': 'disabled', 'label': 'Disabled Only'},
                ],
                onSelected: (val) => setState(() => _selectedStatus = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String currentValue,
    required List<Map<String, String>> options,
    required ValueChanged<String> onSelected,
  }) {
    final isSelected = currentValue != 'all';
    final currentLabel = options.firstWhere(
      (opt) => opt['val'] == currentValue,
      orElse: () => {'label': label},
    )['label']!;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) {
        return options.map((opt) {
          final isItemActive = opt['val'] == currentValue;
          return PopupMenuItem<String>(
            value: opt['val'],
            child: Row(
              children: [
                if (isItemActive)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight:
                        isItemActive ? FontWeight.bold : FontWeight.normal,
                    color: isItemActive
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.14)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.4)
                : Colors.white.withOpacity(0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      children: [
        Text(
          '$count ${count == 1 ? 'Student' : 'Students'} Found',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Under Your Scope',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Student Card
  // ---------------------------------------------------------------------------
  Widget _buildStudentCard(AppUser student) {
    final displayName =
        (student.name != null && student.name!.trim().isNotEmpty)
            ? student.name!.trim()
            : 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';
    final rollNo = student.rollNo ?? '-';
    final std = student.studentClass ?? '-';
    final div = student.division ?? '-';
    final medium = student.medium ?? '-';
    final group = student.studentGroup;
    final assignedSubjects = _getTeachingSubjectsForStudent(student);

    return _TeacherGlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showStudentDetailsSheet(student),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Active Indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: student.isActive
                    ? AppColors.primarySoft
                    : AppColors.cardLight,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: student.isActive
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: student.isActive
                        ? AppColors.success
                        : AppColors.textMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Roll #$rollNo',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildBadge('Std $std • $div', AppColors.accent),
                    _buildBadge(medium, AppColors.secondary),
                    if (group != null && group.isNotEmpty)
                      _buildBadge(group, const Color(0xFF6366F1)),
                    if (assignedSubjects.isNotEmpty)
                      _buildBadge(
                        'Subject: ${assignedSubjects.join(', ')}',
                        AppColors.success,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        student.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Simple Message Component
  // ---------------------------------------------------------------------------
  Widget _buildSimpleMessageCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    bool showResetButton = false,
  }) {
    return _TeacherGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (showResetButton) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load students',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Student Details Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showStudentDetailsSheet(AppUser student) {
    final displayName =
        (student.name != null && student.name!.trim().isNotEmpty)
            ? student.name!.trim()
            : 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';
    final assignedSubjects = _getTeachingSubjectsForStudent(student);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.92),
                    Colors.white.withOpacity(0.85),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildSectionTitle('Academic Information'),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: [
                            _buildInfoTile(
                                'Roll Number', '#${student.rollNo ?? "-"}'),
                            _buildInfoTile('Class & Div',
                                'Std ${student.studentClass ?? "-"} - ${student.division ?? "-"}'),
                            _buildInfoTile('Language', student.medium ?? '-'),
                            _buildInfoTile(
                                'Group', student.studentGroup ?? 'General'),
                            _buildInfoTile('Institution',
                                student.institution ?? 'Sharda Mandir'),
                            _buildInfoTile('Academic Year',
                                student.academicYear ?? '2026-2027'),
                            _buildInfoTile(
                              'Teaching Subject',
                              assignedSubjects.isNotEmpty
                                  ? assignedSubjects.join(', ')
                                  : 'Assigned',
                            ),
                            _buildInfoTile(
                              'Account Status',
                              student.isActive ? 'Active' : 'Disabled',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Recent Tests by You'),
                        const SizedBox(height: 10),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _supabase
                              .getTeacherTestAttemptsForStudent(student.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            }

                            final attempts = snapshot.data ?? [];
                            if (attempts.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 36,
                                      color: AppColors.textMuted,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No tests attempted yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'This student has not yet submitted any of your tests.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attempts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final att = attempts[index];
                                final test = att['tests'] != null
                                    ? Test.fromMap(att['tests'])
                                    : null;
                                final score = att['score'] as int? ?? 0;
                                final submittedAtStr =
                                    att['submitted_at'] as String?;
                                final submittedAt = submittedAtStr != null
                                    ? DateTime.tryParse(submittedAtStr)
                                    : null;
                                final formattedDate = submittedAt != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a')
                                        .format(submittedAt)
                                    : 'Recent';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.quiz_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              test != null
                                                  ? '${test.subject}: ${test.topic}'
                                                  : 'MCQ Test',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Score: $score',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _openResultPreview(
                                                context,
                                                att['id'],
                                                att['test_id'],
                                                score,
                                                test: test,
                                              );
                                            },
                                            child: const Text(
                                              'View Paper >',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      final questions = await _supabase.getTestQuestions(testId);
      final selectedAnswers = await _supabase.getAttemptAnswers(attemptId);

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
            content: Text('Failed to load attempt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
