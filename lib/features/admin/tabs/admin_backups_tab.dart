import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/models/test_backup.dart';

class AdminBackupsTab extends StatefulWidget {
  final List<TestBackup> backups;
  final Future<void> Function() onRefresh;

  const AdminBackupsTab({
    super.key,
    required this.backups,
    required this.onRefresh,
  });

  @override
  State<AdminBackupsTab> createState() => _AdminBackupsTabState();
}

class _AdminBackupsTabState extends State<AdminBackupsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _supabase = SupabaseService();
  bool _isSyncing = false;

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking and syncing missing backups...')),
    );
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _retryBackup(TestBackup backup) async {
    final ok = await _supabase.retryBackup(backup.id, 'test');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Backup retried!' : 'Retry scheduled.'),
          backgroundColor: ok ? AppColors.success : AppColors.warning,
        ),
      );
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Drive Policy Banner
          AppCard(
            padding: const EdgeInsets.all(18),
            color: AppColors.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.add_to_drive_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Google Drive Sync & Retention Policy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tests and Question Solution PDFs are automatically backed up to Google Drive. '
                  'Records older than 30 days are eligible for cleanup only after verified Drive upload.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSyncing ? null : _triggerManualSync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync All Backups Now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Backups (${widget.backups.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Backups',
                onPressed: widget.onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (widget.backups.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_done_outlined, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'No backup records found yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Newly published tests and solution PDFs will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...widget.backups.map((b) {
              final statusColor = b.isCompleted
                  ? AppColors.success
                  : (b.isFailed ? AppColors.error : AppColors.warning);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.12),
                    child: Icon(
                      b.isCompleted
                          ? Icons.check_circle_rounded
                          : (b.isFailed ? Icons.error_rounded : Icons.pending_rounded),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    b.filename,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Status: ${b.status.toUpperCase()}${b.errorMessage != null ? " • ${b.errorMessage}" : ""}',
                    style: TextStyle(fontSize: 11, color: statusColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: b.isFailed || b.needsConfig
                      ? IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                          tooltip: 'Retry Backup',
                          onPressed: () => _retryBackup(b),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
