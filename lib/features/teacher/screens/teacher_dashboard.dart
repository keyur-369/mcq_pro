import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/app_section_title.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/create_test_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_results_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_tests_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcq_test_app/core/providers/api_key_provider.dart';
import 'package:mcq_test_app/models/api_key.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeysAsync = ref.watch(apiKeysProvider);
    final selectedKey = ref.watch(selectedApiKeyProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
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
        child: AnimatedPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            children: [
              _buildWelcomeBanner(context),
              const SizedBox(height: 10),
              const AppSectionTitle(title: 'AI Configuration'),
              const SizedBox(height: 16),
              _buildApiKeySelector(context, ref, apiKeysAsync, selectedKey),
              const SizedBox(height: 32),
              const AppSectionTitle(title: 'Quick Actions'),
              const SizedBox(height: 32),
              GridView.count(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
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
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Drafts',
                    subtitle: 'In Progress',
                    icon: Icons.edit_document,
                    gradient: [AppColors.secondary, Color(0xFFF472B6)],
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
                    gradient: [AppColors.success, Color(0xFF34D399)],
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
                    gradient: [AppColors.accent, Color(0xFF67E8F9)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherResultsScreen(),
                      ),
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back,',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Educator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.school_rounded,
            color: Colors.white.withOpacity(0.5),
            size: 80,
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
        // Initialize selected key if null
        if (selectedKey == null && keys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedApiKeyProvider.notifier).state = keys.first;
          });
        }

        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.vpn_key_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Key:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              if (keys.isEmpty)
                const Expanded(
                  child: Text(
                    'No keys added',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
              else
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ApiKey>(
                      value: (selectedKey != null && keys.contains(selectedKey))
                          ? selectedKey
                          : (keys.isNotEmpty ? keys.first : null),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: keys.map((key) {
                        return DropdownMenuItem(
                          value: key,
                          child: Text(
                            key.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(selectedApiKeyProvider.notifier).state = val;
                        }
                      },
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => _showAddKeyDialog(context, ref),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Add New AI Key',
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
                    // Refresh the provider
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
