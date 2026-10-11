import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';

class AdminDiagnosticsCard extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const AdminDiagnosticsCard({super.key, this.onRefreshRequested});

  @override
  State<AdminDiagnosticsCard> createState() => _AdminDiagnosticsCardState();
}

class _AdminDiagnosticsCardState extends State<AdminDiagnosticsCard> {
  bool _isExpanded = false;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;
  Map<String, dynamic> _diagData = {};

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    _gatherBasicInfo();
  }

  void _gatherBasicInfo() {
    final user = _supabase.currentUser;
    setState(() {
      _diagData = {
        'authenticated': user != null,
        'email': user?.email ?? 'Not logged in',
        'userId': user?.id ?? 'N/A',
      };
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final logs = <String>[];
    bool success = true;

    try {
      final user = _supabase.currentUser;
      logs.add('👤 Current Auth User: ${user?.email ?? "None"} (${user?.id ?? "None"})');

      if (user == null) {
        logs.add('❌ Not authenticated with Supabase Auth!');
        success = false;
      } else {
        // 1. Check user profile in public.users
        try {
          final profile = await _supabase.getUserProfile(user.id);
          if (profile != null) {
            final role = profile;'role';
            final isActive = profile;'is_active';
            logs.add('🔑 DB Role: "$role" (is_active: $isActive)');
            if (role != 'admin') {
              logs.add('⚠️ WARNING: Role is "$role", not "admin"! Supabase RLS may prevent querying other users.');
            }
          } else {
            logs.add('⚠️ No profile row found in public.users for auth id: ${user.id}');
          }
        } catch (e) {
          logs.add('⚠️ Error checking own profile: $e');
        }

        // 2. Test querying teachers from public.users
        try {
          final rawTeachers = await _supabase.supabase
              .from('users')
              .select('id, name, email, role, is_active')
              .eq('role', 'teacher');

          final list = rawTeachers as List;
          logs.add('🧑‍🏫 Teachers Query: SUCCESS (${list.length} rows found)');
          for (var i = 0; i < list.length && i < 3; i++) {
            final row = list[i];
            logs.add('   • ${row["name"] ?? row["email"]} (${row["email"]}) [active: ${row["is_active"]}]');
          }
          if (list.length > 3) {
            logs.add('   • ... and ${list.length - 3} more');
          }
          if (list.isEmpty) {
            logs.add('ℹ️ Table returned 0 teacher rows. Check if any users have role="teacher".');
          }
        } catch (e) {
          logs.add('❌ Teachers Query Error: $e');
          success = false;
        }

        // 3. Test querying student count
        try {
          final rawStudents = await _supabase.supabase
              .from('users')
              .select('id')
              .eq('role', 'student');
          logs.add('🎓 Students in DB: ${(rawStudents as List).length}');
        } catch (e) {
          logs.add('⚠️ Students count query error: $e');
        }
      }
    } catch (e) {
      logs.add('💥 Diagnostic execution failed: $e');
      success = false;
    }

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = success;
        _testResult = logs.join('\n');
      });
    }
  }

  void _copyToClipboard() {
    if (_testResult != null) {
      Clipboard.setData(ClipboardData(text: _testResult!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostic report copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bug_report_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Diagnostics & Bug Hunter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Signed in: ${_diagData["email"] ?? "..."}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                tooltip: _isExpanded ? 'Collapse' : 'Expand Diagnostics',
              ),
            ],
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isTesting ? null : _runDiagnostics,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(_isTesting ? 'Running Checks...' : 'Run Query Tests'),
                  ),
                ),
                if (_testResult != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy'),
                  ),
                ],
              ],
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? AppColors.success.withOpacity(0.08)
                      : AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
