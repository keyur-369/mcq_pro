import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/student/screens/result_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test.dart';

/// ---------------------------------------------------------------------------
/// Liquid glass primitive (same look as the dashboard and create-test screens).
/// Tip: move this into core/widgets/glass_card.dart and share it everywhere.
/// ---------------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.blur = 22,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final innerBr = BorderRadius.circular(radius - 1.2);
    final base = tint ?? Colors.white;
    final glow = tint ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.15),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.55),
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: innerBr,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          base.withOpacity(0.50),
                          base.withOpacity(0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -40,
                  bottom: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glow.withOpacity(0.16),
                            glow.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 56,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.32),
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
                    borderRadius: innerBr,
                    splashColor: Colors.white.withOpacity(0.25),
                    highlightColor: Colors.white.withOpacity(0.10),
                    child: Padding(padding: padding, child: child),
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
    final isAAcc = aInst.contains('acc');
    final isSAcc = sInst.contains('acc');
    if (isAAcc != isSAcc) {
      return false;
    }
    if (!isAAcc && aInst.isNotEmpty && sInst.isNotEmpty && aInst != sInst) {
      return false;
    }

    // 2. Standard (std) check
    final aStd = a.standard.trim();
    final sStd = (student.studentClass ?? '').trim();
    if (aStd != sStd) {
      return false;
    }

    // 3. Division (div) check
    var aDiv = a.division.trim().toUpperCase();
    var sDiv = (student.division ?? '').trim().toUpperCase();
    if (aDiv.startsWith('DIV ')) aDiv = aDiv.substring(4).trim();
    if (sDiv.startsWith('DIV ')) sDiv = sDiv.substring(4).trim();

    // If both belong to Tuition ACC, all students in Tuition ACC belong to ACC division
    if (isAAcc && isSAcc) {
      // Tuition ACC only has ACC division, match!
    } else if (aDiv != 'ALL' && aDiv != sDiv) {
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
    // Default subjects (Physics & Chemistry) are compulsory for all science students
    // Elective stream (Biology or Math) is checked based on student's selected subject/group
    final sub = a.subject.trim().toLowerCase();
    final grp = (student.studentGroup ?? '').trim().toLowerCase();

    final isPhysics = sub == 'physics' || sub == 'physical';
    final isChemistry = sub == 'chemistry';
    final isBiology = sub == 'biology' || sub == 'bio';
    final isMath = sub == 'math' || sub == 'maths' || sub == 'mathematics';

    // Physics and Chemistry are default compulsory subjects for all students
    if (isPhysics || isChemistry) {
      return true;
    }

    // Biology: only matches if student's group is Biology (or default/general)
    if (isBiology) {
      return grp.isEmpty || grp == 'biology' || grp == 'bio' || grp == 'b' || grp == 'science';
    }

    // Math: only matches if student's group is Math/Maths
    if (isMath) {
      return grp == 'math' || grp == 'maths' || grp == 'a';
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
        if (!subs.any(
              (s) => s.toLowerCase() == _selectedSubject.toLowerCase(),
        )) {
          return false;
        }
      }

      // Standard / Class filter
      if (_selectedClass != 'all' && student.studentClass != _selectedClass) {
        return false;
      }

      // Division filter
      if (_selectedDivision != 'all' &&
          (student.division ?? '').toUpperCase() !=
              _selectedDivision.toUpperCase()) {
        return false;
      }

      // Medium / Language filter
      if (_selectedMedium != 'all' &&
          (student.medium ?? '').toLowerCase() !=
              _selectedMedium.toLowerCase()) {
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

        final matches =
            name.contains(query) ||
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            // Ambient colour blobs so the glass has something to refract.
            _ambientBlob(
              top: -60,
              left: -70,
              size: 260,
              color: AppColors.primary,
              opacity: 0.35,
            ),
            _ambientBlob(
              top: 340,
              right: -90,
              size: 260,
              color: AppColors.secondary,
              opacity: 0.26,
            ),
            _ambientBlob(
              bottom: 30,
              left: -80,
              size: 240,
              color: AppColors.accent,
              opacity: 0.26,
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingView()
                        : _errorMessage != null
                        ? _buildErrorView()
                        : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: _buildBodyContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ambientBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(opacity), color.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    String subtitle = 'Directory & roster';
    if (!_isLoading && _errorMessage == null && _assignments.isNotEmpty) {
      final n = _teacherStudents.length;
      subtitle = '$n ${n == 1 ? 'student' : 'students'} in your scope';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: _GlassCard(
        radius: 26,
        blur: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Tooltip(
              message: 'Back',
              child: _GlassCard(
                radius: 15,
                blur: 12,
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Students',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Refresh',
              child: _GlassCard(
                radius: 15,
                blur: 12,
                padding: const EdgeInsets.all(10),
                onTap: _loadData,
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / error
  // ---------------------------------------------------------------------------
  Widget _buildLoadingView() {
    return Center(
      child: _GlassCard(
        radius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your students...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassCard(
          tint: AppColors.error,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconOrb(Icons.error_outline_rounded, AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Unable to load students',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _gradientButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                onTap: _loadData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconOrb(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.28), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main body content
  // ---------------------------------------------------------------------------
  Widget _buildBodyContent() {
    // Case 1: Teacher has no teaching assignments set by Admin
    if (_assignments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _buildScopeOverviewCard(),
          const SizedBox(height: 22),
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
    final std11Count = totalTeacherStudents
        .where((s) => s.studentClass == '11')
        .length;
    final std12Count = totalTeacherStudents
        .where((s) => s.studentClass == '12')
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _buildScopeOverviewCard(),
        const SizedBox(height: 14),
        _buildHeaderHero(
          totalCount: totalCount,
          activeCount: activeCount,
          std11Count: std11Count,
          std12Count: std12Count,
        ),
        const SizedBox(height: 18),
        _buildSearchAndFilters(),
        const SizedBox(height: 18),
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
  // Scope overview card
  // ---------------------------------------------------------------------------
  Widget _buildScopeOverviewCard() {
    final institutions = _assignments
        .map((a) => a.institution)
        .toSet()
        .join(', ');
    final standards = _assignments
        .map((a) => 'Std ${a.standard}')
        .toSet()
        .join(', ');
    final divisions = _assignments
        .map((a) => 'Div ${a.division}')
        .toSet()
        .join(', ');
    final mediums = _assignments.map((a) => a.medium).toSet().join(', ');
    final subjects = _assignments.map((a) => a.subject).toSet().join(', ');

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withOpacity(0.75)),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.35)),
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
            spacing: 8,
            runSpacing: 8,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.60),
                Colors.white.withOpacity(0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.75)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------
  Widget _buildHeaderHero({
    required int totalCount,
    required int activeCount,
    required int std11Count,
    required int std12Count,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Total',
            value: '$totalCount',
            icon: Icons.groups_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Active',
            value: '$activeCount',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Std 11',
            value: '$std11Count',
            icon: Icons.school_rounded,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Std 12',
            value: '$std12Count',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _GlassCard(
      radius: 20,
      blur: 16,
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & filters
  // ---------------------------------------------------------------------------
  Widget _buildSearchAndFilters() {
    // Unique options derived strictly from the teacher's active assignments
    final assignedSubjects = _assignments
        .map((a) => a.subject.trim())
        .toSet()
        .toList();
    final assignedStandards = _assignments
        .map((a) => a.standard.trim())
        .toSet()
        .toList();
    final assignedDivisions = _assignments
        .map((a) => a.division.trim().toUpperCase())
        .toSet()
        .toList();
    final assignedMediums = _assignments
        .map((a) => a.medium.trim())
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          radius: 20,
          blur: 18,
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
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
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.6),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (_activeFilterCount > 0) ...[
                _buildClearPill(),
                const SizedBox(width: 8),
              ],

              if (assignedSubjects.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Subject',
                  icon: Icons.menu_book_rounded,
                  currentValue: _selectedSubject,
                  options: [
                    {'val': 'all', 'label': 'All Subjects'},
                    ...assignedSubjects.map((s) => {'val': s, 'label': s}),
                  ],
                  onSelected: (val) => setState(() => _selectedSubject = val),
                ),
                const SizedBox(width: 8),
              ],

              if (assignedStandards.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Standard',
                  icon: Icons.school_rounded,
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

              if (assignedDivisions.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Division',
                  icon: Icons.meeting_room_rounded,
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

              if (assignedMediums.length > 1) ...[
                _buildFilterDropdown(
                  label: 'Language',
                  icon: Icons.translate_rounded,
                  currentValue: _selectedMedium,
                  options: [
                    {'val': 'all', 'label': 'All Languages'},
                    ...assignedMediums.map((m) => {'val': m, 'label': m}),
                  ],
                  onSelected: (val) => setState(() => _selectedMedium = val),
                ),
                const SizedBox(width: 8),
              ],

              _buildFilterDropdown(
                label: 'Status',
                icon: Icons.toggle_on_rounded,
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

  Widget _buildClearPill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: AppColors.error.withOpacity(0.14),
          child: InkWell(
            onTap: _clearAllFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.filter_alt_off_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Clear ($_activeFilterCount)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
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
      color: Colors.white.withOpacity(0.97),
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.9)),
      ),
      itemBuilder: (context) {
        return options.map((opt) {
          final isItemActive = opt['val'] == currentValue;
          return PopupMenuItem<String>(
            value: opt['val'],
            child: Row(
              children: [
                if (isItemActive)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight: isItemActive
                        ? FontWeight.w800
                        : FontWeight.w500,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [
                  AppColors.primary.withOpacity(0.24),
                  AppColors.primary.withOpacity(0.08),
                ]
                    : [
                  Colors.white.withOpacity(0.60),
                  Colors.white.withOpacity(0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.55)
                    : Colors.white.withOpacity(0.8),
                width: isSelected ? 1.4 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'Student' : 'Students'} Found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
          ),
          child: const Text(
            'Under Your Scope',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Student card
  // ---------------------------------------------------------------------------
  Widget _buildAvatar(String initial, bool active, {double size = 50}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? AppColors.primaryGradient
                    : [
                  AppColors.textMuted.withOpacity(0.55),
                  AppColors.textMuted.withOpacity(0.35),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.85)),
              boxShadow: [
                BoxShadow(
                  color: (active ? AppColors.primary : AppColors.textMuted)
                      .withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: size * 0.38,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: active ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      onTap: () => _showStudentDetailsSheet(student),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(initial, student.isActive),
          const SizedBox(width: 14),
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
                          fontSize: 15.5,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Roll #$rollNo',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _buildBadge('Std $std • $div', AppColors.accent),
                    _buildBadge(medium, AppColors.secondary),
                    if (group != null && group.isNotEmpty)
                      _buildBadge('Group: $group', const Color(0xFF6366F1)),
                    if (assignedSubjects.isNotEmpty)
                      _buildBadge(
                        'Assigned: ${assignedSubjects.join(', ')}',
                        AppColors.success,
                      ),
                    if (!student.isActive)
                      _buildBadge('Disabled', AppColors.error),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.45),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Simple message component
  // ---------------------------------------------------------------------------
  Widget _buildSimpleMessageCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    bool showResetButton = false,
  }) {
    return _GlassCard(
      tint: iconColor,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconOrb(icon, iconColor),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
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
              const SizedBox(height: 20),
              _gradientButton(
                label: 'Reset All Filters',
                icon: Icons.refresh_rounded,
                onTap: _clearAllFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Student details bottom sheet
  // ---------------------------------------------------------------------------
  void _showStudentDetailsSheet(AppUser student) {
    final displayName =
    (student.name != null && student.name!.trim().isNotEmpty)
        ? student.name!.trim()
        : 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';
    final assignedSubjects = _getTeachingSubjectsForStudent(student);

    // Created once so the list doesn't refetch if the sheet rebuilds.
    final attemptsFuture = _supabase.getTeacherTestAttemptsForStudent(
      student.id,
    );

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
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.88),
                    Colors.white.withOpacity(0.74),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.9),
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
                        _buildAvatar(initial, student.isActive, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.6),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            AppColors.textMuted.withOpacity(0.35),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildSectionTitle('Academic Information'),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: [
                            _buildInfoTile(
                              'Roll Number',
                              '#${student.rollNo ?? "-"}',
                              Icons.tag_rounded,
                            ),
                            _buildInfoTile(
                              'Class & Div',
                              'Std ${student.studentClass ?? "-"} - ${student.division ?? "-"}',
                              Icons.school_rounded,
                            ),
                            _buildInfoTile(
                              'Language',
                              student.medium ?? '-',
                              Icons.translate_rounded,
                            ),
                            _buildInfoTile(
                              'Selected Group',
                              student.studentGroup ?? 'Biology',
                              Icons.category_rounded,
                            ),
                            _buildInfoTile(
                              'Enrolled Subjects',
                              student.enrolledSubjects.join(', '),
                              Icons.collections_bookmark_rounded,
                            ),
                            _buildInfoTile(
                              'Institution',
                              student.institution ?? 'Sharda Mandir',
                              Icons.account_balance_rounded,
                            ),
                            _buildInfoTile(
                              'Academic Year',
                              student.academicYear ?? '2026-2027',
                              Icons.event_rounded,
                            ),
                            _buildInfoTile(
                              'Teaching Subject',
                              assignedSubjects.isNotEmpty
                                  ? assignedSubjects.join(', ')
                                  : 'Assigned',
                              Icons.menu_book_rounded,
                            ),
                            _buildInfoTile(
                              'Account Status',
                              student.isActive ? 'Active' : 'Disabled',
                              student.isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.block_rounded,
                              valueColor: student.isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _buildSectionTitle('Recent Tests by You'),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: attemptsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final attempts = snapshot.data ?? [];
                            if (attempts.isEmpty) {
                              return _glassPanel(
                                padding: const EdgeInsets.all(22),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 38,
                                      color: AppColors.textMuted,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'No tests attempted yet',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
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
                                    ? DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(submittedAt)
                                    : 'Recent';

                                return _glassPanel(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: AppColors.primaryGradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.30),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.quiz_rounded,
                                          color: Colors.white,
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
                                                fontWeight: FontWeight.w800,
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
                                                color: AppColors.textSecondary,
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
                                              horizontal: 9,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withOpacity(0.16),
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.success
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                            child: Text(
                                              'Score: $score',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _openResultPreview(
                                                att['id'],
                                                att['test_id'],
                                                score,
                                                test: test,
                                              );
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'View Paper',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 10,
                                                  color: AppColors.primary,
                                                ),
                                              ],
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

  /// Lightweight glass surface for items inside the (already blurred) sheet.
  Widget _glassPanel({required Widget child, required EdgeInsetsGeometry padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.85),
            Colors.white.withOpacity(0.50),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
      String label,
      String value,
      IconData icon, {
        Color? valueColor,
      }) {
    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Uses the State's own context (not the sheet's) so it stays valid after the
  // sheet has been popped.
  void _openResultPreview(
      String attemptId,
      String testId,
      int score, {
        Test? test,
      }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: _GlassCard(
          radius: 26,
          padding: const EdgeInsets.all(24),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );

    try {
      final questions = await _supabase.getTestQuestions(testId);
      final selectedAnswers = await _supabase.getAttemptAnswers(attemptId);

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
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