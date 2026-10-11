import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/models/app_user.dart';

class AdminPasswordVaultScreen extends StatefulWidget {
  const AdminPasswordVaultScreen({super.key});

  @override
  State<AdminPasswordVaultScreen> createState() => _AdminPasswordVaultScreenState();
}

class _AdminPasswordVaultScreenState extends State<AdminPasswordVaultScreen> {
  final _supabase = SupabaseService();
  final _searchController = TextEditingController();

  List<AppUser> _allUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _filterRole = 'all'; // 'all', 'teacher', 'student', 'admin'
  final Set<String> _revealedPasswords = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _supabase.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = list;
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

  List<AppUser> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _allUsers.where((u) {
      // Role filter
      if (_filterRole != 'all' && u.role.toLowerCase() != _filterRole) {
        return false;
      }

      // Query filter
      if (query.isEmpty) return true;
      final name = (u.name ?? '').toLowerCase();
      final email = u.email.toLowerCase();
      final roll = (u.rollNo ?? '').toLowerCase();
      final tempPw = (u.temporaryPassword ?? '').toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          roll.contains(query) ||
          tempPw.contains(query);
    }).toList();
  }

  void _showSetPasswordDialog(AppUser user) {
    String generateSimplePass() {
      const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
      final rnd = Random();
      return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
    }

    final passController = TextEditingController(text: generateSimplePass());
    bool requirePasswordChange = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.key_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set Password: ${user.name ?? user.email}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign a known password for ${user.email}. You can immediately give this to the user for login.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: passController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {
                      setDialogState(() {
                        passController.text = generateSimplePass();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Regenerate',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: requirePasswordChange,
                title: const Text(
                  'Prompt user to change on next login',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                onChanged: (val) {
                  setDialogState(() => requirePasswordChange = val ?? true);
                },
                controlAffinity: ListTileControlAffinity.leading,
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
                final newPass = passController.text.trim();
                if (newPass.isEmpty) return;

                Navigator.pop(ctx);
                try {
                  await _supabase.adminSetUserPassword(
                    userId: user.id,
                    email: user.email,
                    newPassword: newPass,
                    mustChangePassword: requirePasswordChange,
                  );

                  // Copy to clipboard immediately
                  Clipboard.setData(ClipboardData(
                    text: 'Login Credentials\nEmail: ${user.email}\nPassword: $newPass',
                  ));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ New password set for ${user.email}! Copied to clipboard.'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                  _loadUsers();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating password: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save & Copy'),
            ),
          ],
        ),
      ),
    );
  }

  void _copyCredentials(AppUser user, String password) {
    Clipboard.setData(ClipboardData(
      text: 'Login Credentials\nRole: ${user.role.toUpperCase()}\nEmail: ${user.email}\nPassword: $password',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied login credentials for ${user.email} to clipboard!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final total = _allUsers.length;
    final teachers = _allUsers.where((u) => u.role == 'teacher').length;
    final students = _allUsers.where((u) => u.role == 'student').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Passwords & Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: AnimatedPage(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Info Notice Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Admin Password Vault',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'View active temporary passwords or immediately reissue a known password for any student or teacher who forgot their login credentials.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search user by name, email, roll no...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All Users ($total)'),
                        const SizedBox(width: 8),
                        _buildFilterChip('teacher', 'Teachers ($teachers)'),
                        const SizedBox(width: 8),
                        _buildFilterChip('student', 'Students ($students)'),
                        const SizedBox(width: 8),
                        _buildFilterChip('admin', 'Admins (${total - teachers - students})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content States
                  if (_isLoading && _allUsers.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ] else if (_errorMessage != null && _allUsers.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text('Error: $_errorMessage', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  ] else if (filtered.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text('No matching accounts found', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ...filtered.map((user) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildVaultUserCard(user),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVaultUserCard(AppUser user) {
    final role = user.role.toLowerCase();
    final isTeacher = role == 'teacher';
    final isStudent = role == 'student';
    final isAdmin = role == 'admin';

    final roleColor = isTeacher
        ? AppColors.primary
        : isStudent
            ? AppColors.success
            : AppColors.accent;

    final hasTempPassword = user.temporaryPassword != null && user.temporaryPassword!.trim().isNotEmpty;
    final isRevealed = _revealedPasswords.contains(user.id);
    final passwordText = hasTempPassword ? user.temporaryPassword! : null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withOpacity(0.15),
                child: Text(
                  (user.name?.isNotEmpty == true ? user.name![0] : role[0]).toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Credentials Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  hasTempPassword ? Icons.key_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: hasTempPassword ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasTempPassword
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Known / Temporary Password:',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isRevealed ? passwordText! : '••••••••••••',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isRevealed ? AppColors.primaryDark : AppColors.textPrimary,
                                letterSpacing: isRevealed ? 1.0 : 2.0,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Permanent Password Set',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Stored as secure hash. Click "Reissue Pass" to assign a new known password.',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                ),

                if (hasTempPassword) ...[
                  IconButton(
                    icon: Icon(
                      isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: isRevealed ? 'Hide' : 'Show',
                    onPressed: () {
                      setState(() {
                        if (isRevealed) {
                          _revealedPasswords.remove(user.id);
                        } else {
                          _revealedPasswords.add(user.id);
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Copy Credentials',
                    onPressed: () => _copyCredentials(user, passwordText!),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showSetPasswordDialog(user),
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: Text(hasTempPassword ? 'Change Password' : 'Reissue / Set Password'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterRole == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filterRole = value);
      },
    );
  }
}
