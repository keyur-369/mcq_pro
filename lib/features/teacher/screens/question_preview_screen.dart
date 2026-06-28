import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/animated_page.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/core/widgets/formula_text.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class QuestionPreviewScreen extends StatefulWidget {
  final Test test;
  final List<Question> questions;
  const QuestionPreviewScreen({
    super.key,
    required this.test,
    required this.questions,
  });

  @override
  State<QuestionPreviewScreen> createState() => _QuestionPreviewScreenState();
}

class _QuestionPreviewScreenState extends State<QuestionPreviewScreen>
    with TickerProviderStateMixin {
  late List<Question> _questions;
  bool _isLoading = false;

  // Which question cards are expanded
  late List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
    // First card open by default
    _expanded = List.generate(_questions.length, (i) => i == 0);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _saveTest(TestStatus status) async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService();
      String testId;

      if (widget.test.id.isNotEmpty) {
        testId = widget.test.id;
        await supabase.updateTest(testId, status);
      } else {
        final testToSave = Test(
          teacherId: widget.test.teacherId,
          studentClass: widget.test.studentClass,
          medium: widget.test.medium,
          subject: widget.test.subject,
          topic: widget.test.topic,
          level: widget.test.level,
          duration: widget.test.duration,
          testCode: widget.test.testCode,
          status: status,
        );
        testId = await supabase.createTest(testToSave);

        final finalQuestions = _questions
            .map((q) => Question(
          testId: testId,
          questionText: q.questionText,
          optionA: q.optionA,
          optionB: q.optionB,
          optionC: q.optionC,
          optionD: q.optionD,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
        ))
            .toList();
        await supabase.saveQuestions(finalQuestions);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == TestStatus.published
                  ? '🎉 Test published successfully!'
                  : '📝 Saved as draft',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Review Questions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Expand/collapse all toggle
          TextButton.icon(
            onPressed: () {
              final allExpanded = _expanded.every((e) => e);
              setState(() {
                _expanded = List.filled(_questions.length, !allExpanded);
              });
            },
            icon: Icon(
              _expanded.every((e) => e)
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              _expanded.every((e) => e) ? 'Collapse' : 'Expand',
              style: const TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: AnimatedPage(
                child: CustomScrollView(
                  slivers: [
                    // ── Summary header ────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _buildSummaryHeader(),
                      ),
                    ),

                    // ── Question count badge ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.quiz_rounded,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_questions.length} Questions',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_rounded,
                                      size: 14, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.test.duration} min',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Question cards ────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      sliver: SliverList.separated(
                        itemCount: _questions.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _buildQuestionCard(_questions[i], i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Summary header ────────────────────────────────────────────────────────

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: subject + topic
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.test.subject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.test.topic.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.test.topic,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                // Test code chip
                GestureDetector(
                  onTap: () {
                    if (widget.test.testCode != null) {
                      Clipboard.setData(
                          ClipboardData(text: widget.test.testCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Test code copied!'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          widget.test.testCode ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded,
                            color: Colors.white70, size: 13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: class + level badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _whiteBadge('Std ${widget.test.studentClass}'),
              const SizedBox(height: 6),
              _whiteBadge(widget.test.level.toUpperCase()),
              const SizedBox(height: 6),
              _whiteBadge(widget.test.medium.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whiteBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Question card ─────────────────────────────────────────────────────────

  Widget _buildQuestionCard(Question question, int index) {
    final isExpanded = _expanded[index];
    final correctLetter = question.correctAnswer; // 'A','B','C','D'

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? AppColors.primary.withOpacity(0.06)
                : Colors.black.withOpacity(0.03),
            blurRadius: isExpanded ? 12 : 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent strip with question number ──
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded[index] = !_expanded[index]),
                child: Container(
                  width: 42,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.08),
                  ),
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'Q ${index + 1}',
                      style: TextStyle(
                        color: isExpanded
                            ? Colors.white
                            : AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Card content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: question preview + chevron
                    GestureDetector(
                      onTap: () => setState(
                              () => _expanded[index] = !_expanded[index]),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FormulaText(
                                question.questionText,
                                style: TextStyle(
                                  fontSize: isExpanded ? 15 : 14,
                                  fontWeight: isExpanded
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Collapsed: just show correct answer pill
                    if (!isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        child: Row(
                          children: [
                            _answerPill(correctLetter,
                                _optionText(question, correctLetter)),
                          ],
                        ),
                      ),

                    // Expanded: full options + explanation
                    if (isExpanded) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [
                            _buildOption('A', question.optionA,
                                question.correctAnswer == 'A'),
                            _buildOption('B', question.optionB,
                                question.correctAnswer == 'B'),
                            _buildOption('C', question.optionC,
                                question.correctAnswer == 'C'),
                            _buildOption('D', question.optionD,
                                question.correctAnswer == 'D'),
                          ],
                        ),
                      ),
                      if (question.explanation.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_rounded,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FormulaText(
                                    question.explanation,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _optionText(Question q, String letter) {
    return switch (letter) {
      'A' => q.optionA,
      'B' => q.optionB,
      'C' => q.optionC,
      'D' => q.optionD,
      _ => '',
    };
  }

  Widget _answerPill(String letter, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: FormulaText(
              text,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(String label, String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCorrect
              ? AppColors.success.withOpacity(0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect
                ? AppColors.success.withOpacity(0.5)
                : AppColors.border,
            width: isCorrect ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.success : AppColors.cardLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isCorrect ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormulaText(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isCorrect
                      ? AppColors.success
                      : AppColors.textPrimary,
                  fontWeight:
                  isCorrect ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Draft button
          Expanded(
            child: SizedBox(
              height: 72,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _saveTest(TestStatus.draft),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.save_outlined,
                        size: 19,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Save Draft',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Publish button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _showPublishConfirm(),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Publish Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Publish this test?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Students will be able to join using the test code. You have ${_questions.length} questions ready.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveTest(TestStatus.published);
                    },
                    child: const Text('Yes, Publish!'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Loading overlay ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.85),
      child: const Center(
        child: SpinKitFadingCube(color: AppColors.primary, size: 40.0),
      ),
    );
  }
}