import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mcq_test_app/core/constants/app_colors.dart';

class ProgressPoint {
  final String testId;
  final String title;
  final String subject;
  final int score;
  final int totalQuestions;
  final double percentage;
  final DateTime date;

  ProgressPoint({
    required this.testId,
    required this.title,
    required this.subject,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.date,
  });
}

class StudentProgressChart extends StatefulWidget {
  final List<ProgressPoint> dataPoints;

  const StudentProgressChart({
    super.key,
    required this.dataPoints,
  });

  @override
  State<StudentProgressChart> createState() => _StudentProgressChartState();
}

class _StudentProgressChartState extends State<StudentProgressChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  String _selectedSubject = 'All';
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant StudentProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataPoints.length != widget.dataPoints.length) {
      _selectedIndex = null;
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<String> get _availableSubjects {
    final set = <String>{'All'};
    for (final p in widget.dataPoints) {
      if (p.subject.trim().isNotEmpty) {
        set.add(p.subject.trim());
      }
    }
    return set.toList();
  }

  List<ProgressPoint> get _filteredPoints {
    if (_selectedSubject == 'All') return widget.dataPoints;
    return widget.dataPoints
        .where((p) => p.subject.toLowerCase() == _selectedSubject.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _filteredPoints;

    if (widget.dataPoints.isEmpty) {
      return _buildEmptyState();
    }

    // Compute stats
    final avgScore = points.isNotEmpty
        ? (points.map((e) => e.percentage).reduce((a, b) => a + b) / points.length)
        : 0.0;
    final highestScore = points.isNotEmpty
        ? points.map((e) => e.percentage).reduce(math.max)
        : 0.0;
    final lowestScore = points.isNotEmpty
        ? points.map((e) => e.percentage).reduce(math.min)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Score progression across attempted tests',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Trend indicator badge
              if (points.length >= 2) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (points.last.percentage >= points.first.percentage)
                        ? AppColors.success.withOpacity(0.12)
                        : AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (points.last.percentage >= points.first.percentage)
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: (points.last.percentage >= points.first.percentage)
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(points.last.percentage - points.first.percentage).abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (points.last.percentage >= points.first.percentage)
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Subject filter chips if multiple subjects
          if (_availableSubjects.length > 2) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _availableSubjects.map((sub) {
                  final isSel = _selectedSubject == sub;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSubject = sub;
                          _selectedIndex = null;
                        });
                        _animController.forward(from: 0);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel
                                ? AppColors.primary
                                : AppColors.border.withOpacity(0.6),
                          ),
                        ),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Quick stat summaries
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Average', '${avgScore.toStringAsFixed(1)}%', AppColors.primary),
                _buildDivider(),
                _buildSummaryItem('Highest', '${highestScore.toStringAsFixed(0)}%', AppColors.success),
                _buildDivider(),
                _buildSummaryItem('Lowest', '${lowestScore.toStringAsFixed(0)}%', AppColors.textSecondary),
                _buildDivider(),
                _buildSummaryItem('Tests', '${points.length}', AppColors.textPrimary),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Chart Display
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No tests found for $_selectedSubject',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) {
                      _handleTapDown(details, constraints.maxWidth, points);
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(constraints.maxWidth, 190),
                          painter: _ProgressChartPainter(
                            points: points,
                            progress: _animation.value,
                            selectedIndex: _selectedIndex,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Active Tooltip Info Card
            if (_selectedIndex != null && _selectedIndex! < points.length) ...[
              const SizedBox(height: 12),
              _buildSelectedTooltip(points[_selectedIndex!]),
            ] else ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Tap on any point to view test details',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.border,
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTooltip(ProgressPoint point) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${point.subject} • ${DateFormat('dd MMM yyyy').format(point.date)}',
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${point.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Score: ${point.score}/${point.totalQuestions}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTapDown(
    TapDownDetails details,
    double totalWidth,
    List<ProgressPoint> points,
  ) {
    if (points.isEmpty) return;

    const leftPadding = 38.0;
    const rightPadding = 20.0;
    final chartWidth = totalWidth - leftPadding - rightPadding;

    if (points.length == 1) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final xStep = chartWidth / (points.length - 1);
    final tapX = details.localPosition.dx - leftPadding;

    int nearestIdx = (tapX / xStep).round().clamp(0, points.length - 1);
    setState(() => _selectedIndex = nearestIdx);
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Progress Data Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This student has not yet taken any tests. Once tests are attempted, a progress curve, accuracy analytics, and performance insights will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChartPainter extends CustomPainter {
  final List<ProgressPoint> points;
  final double progress;
  final int? selectedIndex;

  _ProgressChartPainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 38.0;
    const rightPad = 20.0;
    const topPad = 20.0;
    const bottomPad = 28.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.7)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal benchmark grid lines: 0%, 25%, 50%, 75%, 100%
    const gridLevels = [0, 25, 50, 75, 100];
    for (final level in gridLevels) {
      final y = topPad + chartHeight - (level / 100.0) * chartHeight;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      // Y-axis label
      textPainter.text = TextSpan(
        text: '$level%',
        style: TextStyle(
          color: AppColors.textMuted.withOpacity(0.9),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2));
    }

    if (points.isEmpty) return;

    // Calculate (x, y) for each point
    final List<Offset> pixelPoints = [];
    final xStep = points.length > 1 ? chartWidth / (points.length - 1) : 0.0;

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPad + chartWidth / 2
          : leftPad + i * xStep;
      final clampedPct = points[i].percentage.clamp(0.0, 100.0);
      final rawY = topPad + chartHeight - (clampedPct / 100.0) * chartHeight;
      // Animate from baseline
      final animatedY = (topPad + chartHeight) - ((topPad + chartHeight) - rawY) * progress;
      pixelPoints.add(Offset(x, animatedY));
    }

    // Draw X-axis test labels (T1, T2, T3... or date)
    for (int i = 0; i < points.length; i++) {
      final offset = pixelPoints[i];
      final label = 'T${i + 1}';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: selectedIndex == i ? AppColors.primary : AppColors.textSecondary,
          fontSize: 10,
          fontWeight: selectedIndex == i ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(offset.dx - textPainter.width / 2, size.height - bottomPad + 8),
      );
    }

    if (pixelPoints.length == 1) {
      // Single point
      _drawSinglePoint(canvas, pixelPoints[0]);
      return;
    }

    // Build smooth Bezier path
    final linePath = Path();
    linePath.moveTo(pixelPoints.first.dx, pixelPoints.first.dy);

    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p0 = pixelPoints[i];
      final p1 = pixelPoints[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // Gradient area under curve
    final fillPath = Path.from(linePath);
    fillPath.lineTo(pixelPoints.last.dx, topPad + chartHeight);
    fillPath.lineTo(pixelPoints.first.dx, topPad + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withOpacity(0.28),
          AppColors.primary.withOpacity(0.01),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw points & selection
    for (int i = 0; i < pixelPoints.length; i++) {
      final pt = pixelPoints[i];
      final isSelected = selectedIndex == i;

      // Glow halo
      final haloPaint = Paint()
        ..color = (isSelected ? AppColors.primary : AppColors.primaryLight).withOpacity(isSelected ? 0.35 : 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, isSelected ? 12.0 : 7.0, haloPaint);

      // Outer ring
      final outerRingPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = isSelected ? 3.0 : 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pt, isSelected ? 6.5 : 4.5, outerRingPaint);

      // Inner white dot
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, isSelected ? 4.5 : 2.5, innerPaint);
    }
  }

  void _drawSinglePoint(Canvas canvas, Offset pt) {
    final haloPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pt, 14.0, haloPaint);

    final outerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pt, 8.0, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pt, 5.0, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points;
  }
}
