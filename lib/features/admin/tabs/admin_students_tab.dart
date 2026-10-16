import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/features/admin/widgets/student_card.dart';
import 'package:mcq_test_app/models/app_user.dart';

class AdminStudentsTab extends StatefulWidget {
  final List<AppUser> students;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  const AdminStudentsTab({
    super.key,
    required this.students,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
  });

  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'active', 'disabled'
  String _filterClass = 'all'; // 'all', '11', '12'
  String _filterMedium = 'all'; // 'all', 'English', 'Gujarati'
  final _supabase = SupabaseService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────── Logic (unchanged) ─────────────────────────

  List<AppUser> get _filteredStudents {
    final query = _searchController.text.trim().toLowerCase();
    return widget.students.where((s) {
      if (_filterStatus == 'active' && !s.isActive) return false;
      if (_filterStatus == 'disabled' && s.isActive) return false;

      if (_filterClass != 'all' && s.studentClass != _filterClass) return false;

      if (_filterMedium != 'all' &&
          (s.medium ?? '').toLowerCase() != _filterMedium.toLowerCase()) {
        return false;
      }

      if (query.isEmpty) return true;
      final name = (s.name ?? '').toLowerCase();
      final email = s.email.toLowerCase();
      final roll = (s.rollNo ?? '').toLowerCase();
      final div = (s.division ?? '').toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          roll.contains(query) ||
          div.contains(query);
    }).toList();
  }

  int get _activeFilterCount =>
      (_filterStatus != 'all' ? 1 : 0) +
          (_filterClass != 'all' ? 1 : 0) +
          (_filterMedium != 'all' ? 1 : 0);

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _filterStatus = 'all';
      _filterClass = 'all';
      _filterMedium = 'all';
    });
  }

  Future<void> _toggleStudentStatus(AppUser student, bool newStatus) async {
    try {
      await _supabase.setStudentStatus(student.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.name ?? student.email} is now ${newStatus ? "Active" : "Disabled"}',
            ),
            backgroundColor: newStatus ? AppColors.success : AppColors.warning,
          ),
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update student status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showResetPasswordDialog(AppUser student) {
    final passController = TextEditingController(text: 'Pass@1234');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: ${student.name ?? student.email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a temporary password. The student will be prompted to set a new password upon login:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: passController,
                    decoration: const InputDecoration(
                      labelText: 'Temporary Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: passController.text.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final newPass = passController.text.trim();
              try {
                await _supabase.adminSetUserPassword(
                  userId: student.id,
                  email: student.email,
                  newPassword: newPass,
                  mustChangePassword: true,
                );
                Clipboard.setData(
                  ClipboardData(text: 'Email: ${student.email}\nTemporary Password: $newPass'),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Password reset! Copied ${student.email} credentials to clipboard.'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                widget.onRefresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting password: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Reset & Copy'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Details sheet ─────────────────────────

  void _showStudentDetails(AppUser student) {
    final initial =
    (student.name?.isNotEmpty == true ? student.name![0] : 'S')
        .toUpperCase();
    final statusColor = student.isActive ? AppColors.success : AppColors.error;

    final details = <_Detail>[
      _Detail(Icons.tag_rounded, 'Roll No', '${student.rollNo ?? "-"}'),
      _Detail(Icons.class_rounded, 'Standard', '${student.studentClass ?? "-"}'),
      _Detail(Icons.groups_rounded, 'Division', '${student.division ?? "-"}'),
      _Detail(Icons.translate_rounded, 'Medium', '${student.medium ?? "-"}'),
      if (student.studentGroup != null && student.studentGroup!.isNotEmpty)
        _Detail(Icons.category_rounded, 'Selected Group', student.studentGroup!),
      _Detail(Icons.collections_bookmark_rounded, 'Enrolled Subjects', student.enrolledSubjects.join(', ')),
      if (student.academicYear != null && student.academicYear!.isNotEmpty)
        _Detail(Icons.event_rounded, 'Academic Year', student.academicYear!),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Profile header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        student.name ?? 'Student',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              student.isActive ? 'Active' : 'Disabled',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'Enrollment details',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Detail grid (2 columns)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: details
                      .map((d) => _DetailTile(detail: d))
                      .toList(),
                ),

                if (student.institution != null &&
                    student.institution!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailTile(
                    detail: _Detail(
                      Icons.apartment_rounded,
                      'Institution',
                      student.institution!,
                    ),
                    fullWidth: true,
                  ),
                ],

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _toggleStudentStatus(student, !student.isActive);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: student.isActive
                                ? AppColors.error
                                : AppColors.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            student.isActive
                                ? Icons.block_rounded
                                : Icons.check_circle_rounded,
                            size: 18,
                          ),
                          label: Text(student.isActive ? 'Disable' : 'Enable'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isLoading && widget.students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.errorMessage != null && widget.students.isEmpty) {
      return _buildErrorState();
    }

    final filtered = _filteredStudents;
    final total = widget.students.length;
    final active = widget.students.where((s) => s.isActive).length;
    final disabled = total - active;
    final std11 = widget.students.where((s) => s.studentClass == '11').length;
    final std12 = widget.students.where((s) => s.studentClass == '12').length;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final isFiltering = hasQuery || _activeFilterCount > 0;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        children: [
          // ── Summary tiles ──
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total',
                  value: '$total',
                  icon: Icons.groups_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Active',
                  value: '$active',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Disabled',
                  value: '$disabled',
                  icon: Icons.block_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Search ──
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name, email, roll no, division',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: hasQuery
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: true,
              fillColor: AppColors.surface,
              border: _searchBorder(AppColors.border),
              enabledBorder: _searchBorder(AppColors.border),
              focusedBorder: _searchBorder(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),

          // ── Minimal Filter Bar ──
          _buildMinimalFilterBar(
            total: total,
            active: active,
            disabled: disabled,
            std11: std11,
            std12: std12,
            isFiltering: isFiltering,
          ),
          const SizedBox(height: 14),

          // ── Result header ──
          if (widget.students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    isFiltering
                        ? '${filtered.length} of $total students'
                        : 'All students ($total)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: widget.onRefresh,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── List / empty states ──
          if (widget.students.isEmpty)
            _buildEmptyState(
              icon: Icons.person_add_alt_1_rounded,
              title: 'No students yet',
              message:
              'Students who register on the Student Registration screen will show up here automatically.',
            )
          else if (filtered.isEmpty)
            _buildEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching students',
              message: 'Try a different search or clear the filters.',
              actionLabel: 'Clear filters',
              onAction: _clearAllFilters,
            )
          else
            ...filtered.map(
                  (student) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StudentCard(
                  student: student,
                  onToggleStatus: (newStatus) =>
                      _toggleStudentStatus(student, newStatus),
                  onViewDetails: () => _showStudentDetails(student),
                  onResetPassword: () => _showResetPasswordDialog(student),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── Pieces ─────────────────────────

  OutlineInputBorder _searchBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );

  Widget _buildMinimalFilterBar({
    required int total,
    required int active,
    required int disabled,
    required int std11,
    required int std12,
    required bool isFiltering,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Filter button with active count
          _buildFilterButton(
            total: total,
            active: active,
            disabled: disabled,
            std11: std11,
            std12: std12,
          ),
          const SizedBox(width: 8),

          // 2. Status Dropdown Pill
          _buildFilterDropdownPill(
            label: 'Status',
            currentValue: _filterStatus,
            displayValue: _filterStatus == 'all'
                ? null
                : (_filterStatus == 'active' ? 'Active' : 'Disabled'),
            items: [
              _FilterOption('all', 'All Status ($total)'),
              _FilterOption('active', 'Active ($active)'),
              _FilterOption('disabled', 'Disabled ($disabled)'),
            ],
            onSelected: (v) => setState(() => _filterStatus = v),
          ),
          const SizedBox(width: 8),

          // 3. Class Dropdown Pill
          _buildFilterDropdownPill(
            label: 'Class',
            currentValue: _filterClass,
            displayValue: _filterClass == 'all' ? null : 'Std $_filterClass',
            items: [
              const _FilterOption('all', 'All Classes'),
              _FilterOption('11', 'Std 11 ($std11)'),
              _FilterOption('12', 'Std 12 ($std12)'),
            ],
            onSelected: (v) => setState(() => _filterClass = v),
          ),
          const SizedBox(width: 8),

          // 4. Medium Dropdown Pill
          _buildFilterDropdownPill(
            label: 'Medium',
            currentValue: _filterMedium,
            displayValue: _filterMedium == 'all' ? null : _filterMedium,
            items: const [
              _FilterOption('all', 'All Mediums'),
              _FilterOption('English', 'English'),
              _FilterOption('Gujarati', 'Gujarati'),
            ],
            onSelected: (v) => setState(() => _filterMedium = v),
          ),

          // 5. Reset button if filtering
          if (isFiltering) ...[
            const SizedBox(width: 8),
            _buildClearFiltersPill(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required int total,
    required int active,
    required int disabled,
    required int std11,
    required int std12,
  }) {
    final count = _activeFilterCount;
    final isActive = count > 0;
    return InkWell(
      onTap: () => _showFilterBottomSheet(
        total: total,
        active: active,
        disabled: disabled,
        std11: std11,
        std12: std12,
      ),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: isActive ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 5),
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdownPill({
    required String label,
    required String currentValue,
    required String? displayValue,
    required List<_FilterOption> items,
    required ValueChanged<String> onSelected,
  }) {
    final isActive = currentValue != 'all';
    final title = isActive ? '$label: $displayValue' : label;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        tooltip: 'Filter by $label',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        itemBuilder: (ctx) => items.map((item) {
          final isItemSelected = item.value == currentValue;
          return PopupMenuItem<String>(
            value: item.value,
            height: 38,
            child: Row(
              children: [
                Icon(
                  isItemSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isItemSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isItemSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isItemSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary.withOpacity(0.4) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearFiltersPill() {
    return InkWell(
      onTap: _clearAllFilters,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 4),
            Text(
              'Reset',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet({
    required int total,
    required int active,
    required int disabled,
    required int std11,
    required int std12,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearAllFilters();
                          setSheetState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Account Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sheetChip('All', _filterStatus == 'all', () {
                        setState(() => _filterStatus = 'all');
                        setSheetState(() {});
                      }),
                      _sheetChip('Active ($active)', _filterStatus == 'active', () {
                        setState(() => _filterStatus = 'active');
                        setSheetState(() {});
                      }),
                      _sheetChip('Disabled ($disabled)', _filterStatus == 'disabled', () {
                        setState(() => _filterStatus = 'disabled');
                        setSheetState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Class / Standard',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sheetChip('All', _filterClass == 'all', () {
                        setState(() => _filterClass = 'all');
                        setSheetState(() {});
                      }),
                      _sheetChip('Std 11 ($std11)', _filterClass == '11', () {
                        setState(() => _filterClass = '11');
                        setSheetState(() {});
                      }),
                      _sheetChip('Std 12 ($std12)', _filterClass == '12', () {
                        setState(() => _filterClass = '12');
                        setSheetState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Medium',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sheetChip('All', _filterMedium == 'all', () {
                        setState(() => _filterMedium = 'all');
                        setSheetState(() {});
                      }),
                      _sheetChip('English', _filterMedium == 'English', () {
                        setState(() => _filterMedium = 'English');
                        setSheetState(() {});
                      }),
                      _sheetChip('Gujarati', _filterMedium == 'Gujarati', () {
                        setState(() => _filterMedium = 'Gujarati');
                        setSheetState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Show ${_filteredStudents.length} Students',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardLight,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 12.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 36,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't load students",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Small widgets & models ─────────────────────────

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption(this.value, this.label);
}

class _Detail {
  final IconData icon;
  final String label;
  final String value;
  const _Detail(this.icon, this.label, this.value);
}

class _DetailTile extends StatelessWidget {
  final _Detail detail;
  final bool fullWidth;

  const _DetailTile({required this.detail, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    final width = fullWidth
        ? double.infinity
        : (MediaQuery.of(context).size.width - 40 - 10) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(detail.icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}