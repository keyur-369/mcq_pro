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
import 'package:mcq_test_app/core/services/ai_generator_service.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const SizedBox(height: 30),
                _buildSectionHeader(
                  title: 'AI Configuration',
                  subtitle: selectedKey == null
                      ? 'No active AI key selected'
                      : 'Active key: ${selectedKey.name}',
                ),
                const SizedBox(height: 16),

                _buildApiKeySelector(context, ref, apiKeysAsync, selectedKey),
                const SizedBox(height: 20),
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
                      ),
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

                const SizedBox(height: 30),

              ],
            ),
          ),
        ),
      ),
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