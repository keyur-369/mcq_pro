import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/create_test_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_results_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_tests_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcq_test_app/core/providers/api_key_provider.dart';
import 'package:mcq_test_app/models/api_key.dart';
import 'package:mcq_test_app/models/teacher_assignment.dart';
import 'package:mcq_test_app/models/test_backup.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  List<TeacherAssignment> _assignments = [];
  List<TestBackup> _backups = [];
  bool _isLoadingScope = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      try {
        final assignments = await SupabaseService().getTeacherAssignments(user.id);
        final backups = await SupabaseService().getTestBackups();
        if (mounted) {
          setState(() {
            _assignments = assignments;
            _backups = backups;
            _isLoadingScope = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingScope = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingScope = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKeysAsync = ref.watch(apiKeysProvider);
    final selectedKey = ref.watch(selectedApiKeyProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
       title: const Text(
        'MCQ Pro',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () async {
              await SupabaseService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                _buildWelcomeBanner(),
                const SizedBox(height: 20),
                _buildTeachingScopeCard(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  title: 'AI Configuration',
                  subtitle: selectedKey == null
                      ? 'No active AI key selected'
                      : 'Active key: ${selectedKey.name}',
                ),
                const SizedBox(height: 16),

                _buildApiKeySelector(context, ref, apiKeysAsync, selectedKey),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  title: 'Quick Actions',
                  subtitle: 'Create, manage and analyze tests',
                ),
                const SizedBox(height: 18),

                GridView.count(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.88,
                  children: [
                    _buildDashboardCard(
                      context,
                      title: 'Create Test',
                      subtitle: 'AI Powered',
                      icon: Icons.add_circle_rounded,
                      gradient: [AppColors.primary, AppColors.primaryLight],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateTestScreen(),
                        ),
                      ).then((_) => _loadTeacherData()),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Drafts',
                      subtitle: 'In Progress',
                      icon: Icons.edit_document,
                      gradient: [AppColors.secondary, const Color(0xFFF472B6)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const TeacherTestsScreen(status: 'draft'),
                        ),
                      ),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Published',
                      subtitle: 'Live Tests',
                      icon: Icons.rocket_launch_rounded,
                      gradient: [AppColors.success, const Color(0xFF34D399)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const TeacherTestsScreen(status: 'published'),
                        ),
                      ),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Analytics',
                      subtitle: 'Student Performance',
                      icon: Icons.analytics_rounded,
                      gradient: [AppColors.accent, const Color(0xFF67E8F9)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherResultsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildDriveBackupCard(context),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeachingScopeCard() {
    if (_isLoadingScope) {
      return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_assignments.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No teaching assignments yet. Contact Main Admin to assign standards and subjects.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final standards = _assignments.map((a) => 'Std ${a.standard}').toSet().join(', ');
    final divisions = _assignments.map((a) => a.division).toSet().join(', ');
    final mediums = _assignments.map((a) => a.medium).toSet().join(', ');
    final subjects = _assignments.map((a) => a.subject).toSet().join(', ');

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_ind_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'My Teaching Permissions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Authorized', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScopeChip(Icons.school_rounded, standards),
              _buildScopeChip(Icons.meeting_room_rounded, 'Div: $divisions'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDriveBackupCard(BuildContext context) {
    final failedCount = _backups.where((b) => b.status == 'failed').length;
    final completedCount = _backups.where((b) => b.status == 'completed').length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => _showBackupStatusModal(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: failedCount > 0 ? AppColors.error.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_sync_rounded,
              color: failedCount > 0 ? AppColors.error : AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Drive Backup Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  failedCount > 0
                      ? '$failedCount failed backup(s) • Tap to review and retry'
                      : '$completedCount tests safely archived in Google Drive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: failedCount > 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }

  void _showBackupStatusModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_to_drive_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      const Text(
                        'Drive Backup Archive',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'All published tests and answer keys are archived in Google Drive under 7-day retention rules.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (_backups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No backup records found yet', style: TextStyle(color: AppColors.textMuted))),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _backups.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (ctx, i) {
                          final b = _backups[i];
                          final isFailed = b.status == 'failed';
                          final isCompleted = b.status == 'completed';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isCompleted ? Icons.check_circle_rounded : (isFailed ? Icons.error_rounded : Icons.hourglass_top_rounded),
                              color: isCompleted ? AppColors.success : (isFailed ? AppColors.error : AppColors.secondary),
                            ),
                            title: Text(
                              b.driveFileName ?? 'Test Backup #${b.testId.substring(0, 6)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              'Status: ${b.status.toUpperCase()} ${b.errorMessage != null ? "• ${b.errorMessage}" : ""}',
                              style: TextStyle(fontSize: 11, color: isFailed ? AppColors.error : AppColors.textSecondary),
                            ),
                            trailing: isFailed
                                ? TextButton.icon(
                                    onPressed: () async {
                                      final success = await SupabaseService().retryBackup(b.id, 'test');
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(success ? 'Retry initiated' : 'Retry failed. Please contact Admin.'),
                                            backgroundColor: success ? AppColors.success : AppColors.error,
                                          ),
                                        );
                                        await _loadTeacherData();
                                        setModalState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Retry', style: TextStyle(fontSize: 12)),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 4,
            child: Icon(
              Icons.school_rounded,
              color: Colors.white.withOpacity(0.18),
              size: 110,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome Back,',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Educator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create and manage AI-powered MCQ tests',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Ready to evaluate?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required List<Color> gradient,
        required VoidCallback onTap,
      }) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withOpacity(0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySelector(
      BuildContext context,
      WidgetRef ref,
      AsyncValue<List<ApiKey>> apiKeysAsync,
      ApiKey? selectedKey,
      ) {
    return apiKeysAsync.when(
      data: (keys) {
        if (selectedKey == null && keys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedApiKeyProvider.notifier).state = keys.first;
          });
        }

        return AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: keys.isEmpty
                    ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Provider',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No keys added',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
                    : DropdownButtonHideUnderline(
                  child: DropdownButton<ApiKey>(
                    value:
                    (selectedKey != null && keys.contains(selectedKey))
                        ? selectedKey
                        : keys.first,
                    isExpanded: true,
                    itemHeight: null,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: keys.map((key) {
                      return DropdownMenuItem<ApiKey>(
                        value: key,
                        child: Text(
                          key.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedApiKeyProvider.notifier).state =
                            val;
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              if (selectedKey != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // child: IconButton(
                  //   onPressed: () async {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(content: Text('Verifying key...')),
                  //     );
                  //     final isValid = await AiGeneratorService().verifyApiKey(selectedKey.key);
                  //     if (context.mounted) {
                  //       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         SnackBar(
                  //           content: Text(isValid ? 'API Key is Valid! ✅' : 'API Key is Invalid or Exhausted ❌'),
                  //           backgroundColor: isValid ? AppColors.success : AppColors.error,
                  //         ),
                  //       );
                  //     }
                  //   },
                  //   // icon: const Icon(
                  //   //   Icons.check_circle_outline_rounded,
                  //   //   color: AppColors.success,
                  //   // ),
                  //   tooltip: 'Verify Key',
                  // ),
                ),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _showAddKeyDialog(context, ref),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Add New AI Key',
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  void _showAddKeyDialog(BuildContext context, WidgetRef ref) {
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Gemini API Key',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste your Gemini API key below. The name will be automatically generated.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'AIzaSy...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (keyController.text.isNotEmpty) {
                try {
                  final currentKeys = ref.read(apiKeysProvider).value ?? [];
                  final nextNumber = currentKeys.length + 1;
                  final autoName = 'Gemini Key $nextNumber';

                  await SupabaseService().addApiKey(
                    autoName,
                    keyController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(apiKeysProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$autoName added successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add key: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Add Key'),
          ),
        ],
      ),
    );
  }
}