import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mcq_test_app/core/utils/scientific_formatter.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';

class _RenderedBlock {
  final Uint8List pngBytes;
  final double height;
  _RenderedBlock({required this.pngBytes, required this.height});
}

class PdfExportService {
  static const String _fontFamily = 'NotoSansGujarati';
  static const List<String> _fontFallback = [_fontFamily, 'Roboto', 'sans-serif'];
  static bool _fontLoaded = false;

  /// Ensures Noto Sans Gujarati font is loaded and registered in Flutter's engine.
  static Future<void> _ensureFontLoaded() async {
    if (_fontLoaded) return;
    try {
      final fontData = await rootBundle.load('asset/NotoSansGujarati.ttf');
      final fontLoader = FontLoader(_fontFamily);
      fontLoader.addFont(Future.value(fontData));
      await fontLoader.load();
      _fontLoaded = true;
    } catch (e) {
      // Font may already be loaded via pubspec.yaml
      _fontLoaded = true;
      debugPrint('FontLoader info: $e');
    }
  }

  /// Loads image from base64 data URI, raw base64, or network HTTP URL for canvas rendering
  static Future<ui.Image?> _loadCanvasImage(String? imageSource) async {
    if (imageSource == null || imageSource.trim().isEmpty) return null;
    try {
      Uint8List bytes;
      final trimmed = imageSource.trim();
      if (trimmed.startsWith('data:image')) {
        final commaIdx = trimmed.indexOf(',');
        final b64 = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        bytes = base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final res = await http.get(Uri.parse(trimmed));
        if (res.statusCode == 200) {
          bytes = res.bodyBytes;
        } else {
          return null;
        }
      } else if (trimmed.length > 50 && !trimmed.contains(' ')) {
        bytes = base64Decode(trimmed);
      } else {
        return null;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Failed to load canvas question diagram: $e');
      return null;
    }
  }

  /// Cleans invisible characters, zero-width marks, and normalizes rare typography
  /// while PRESERVING Unicode subscripts (H₂SO₄), superscripts (sp², sp³), chemistry arrows (→, ⇌),
  /// Gujarati characters, English, numbers, and symbols.
  static String _cleanText(String? input) {
    if (input == null || input.isEmpty) return '';

    // Step 1: Pre-format scientific expressions (H2SO4 -> H₂SO₄, sp2 -> sp², etc.)
    final formatted = ScientificFormatter.format(input);

    return formatted
        // Remove directional marks, zero-width spaces, BOM, soft hyphens
        .replaceAll(RegExp(r'[\u200B-\u200F\uFEFF\u00AD\u202A-\u202E\u2060]'), '')
        // Single & double quotes
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u02BC\u02B9]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F]'), '"')
        // Dashes and hyphens (preserving standard minus for math)
        .replaceAll(RegExp(r'[\u2010-\u2015\u2212]'), '-')
        // Bullets & dots
        .replaceAll(RegExp(r'[\u2022\u2023\u25E6\u2043\u2219]'), '-')
        // Ellipsis
        .replaceAll('\u2026', '...')
        // Checkmarks & crosses
        .replaceAll(RegExp(r'[\u2713\u2714]'), '[CORRECT]')
        .replaceAll(RegExp(r'[\u2717\u2718]'), '[X]')
        // Non-breaking spaces and other whitespace variations
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200A\u202F\u205F\u3000]'), ' ')
        // Math & science symbols normalization
        .replaceAll('\u2264', '<=')
        .replaceAll('\u2265', '>=')
        .replaceAll('\u2260', '!=')
        .replaceAll('\u00D7', 'x')
        .replaceAll('\u00F7', '/')
        .replaceAll('\u00B1', '+/-')
        .replaceAll('\u00B0', '°')
        .replaceAll('\u221A', 'sqrt')
        .trim();
  }

  // ==========================================
  // STUDENT SOLUTION REPORT PDF
  // ==========================================

  static Future<Uint8List> generateSolutionPdfBytes({
    required Test test,
    required List<Question> questions,
    required Map<String, String> selectedAnswers,
    required int score,
    required int total,
    required String studentName,
    required String rollNumber,
    DateTime? submissionDate,
  }) async {
    await _ensureFontLoaded();

    final subDate = submissionDate ?? DateTime.now();
    final percentage = total > 0 ? ((score / total) * 100).toStringAsFixed(1) : '0';

    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    // Pure ASCII footer for vector rendering on every page
    final footer = PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 540, 20));
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final textSecondary = PdfColor(100, 116, 139);
    footer.graphics.drawString(
      'MCQ Pro - Smart Tests. Strong Outcomes.  |  Confidential Student Report',
      smallFont,
      brush: PdfSolidBrush(textSecondary),
      bounds: const Rect.fromLTWH(0, 0, 540, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    document.template.bottom = footer;

    var page = document.pages.add();
    final clientWidth = page.getClientSize().width;
    final clientHeight = page.getClientSize().height;
    double y = 10;

    // 1. Render Header Block
    final headerBlock = await _renderSolutionHeader(
      test: test,
      studentName: studentName,
      rollNumber: rollNumber,
      score: score,
      total: total,
      percentage: percentage,
      subDate: subDate,
      width: clientWidth,
    );

    final headerBitmap = PdfBitmap(headerBlock.pngBytes);
    page.graphics.drawImage(headerBitmap, Rect.fromLTWH(0, y, clientWidth, headerBlock.height));
    y += headerBlock.height + 10;

    // 2. Render Questions
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = selectedAnswers[q.id];

      final cardBlock = await _renderSolutionQuestionCard(
        questionIndex: i,
        question: q,
        userAns: userAns,
        width: clientWidth,
      );

      // Check pagination
      if (y + cardBlock.height > clientHeight - 20) {
        page = document.pages.add();
        y = 10;
      }

      final cardBitmap = PdfBitmap(cardBlock.pngBytes);
      page.graphics.drawImage(cardBitmap, Rect.fromLTWH(0, y, clientWidth, cardBlock.height));
      y += cardBlock.height + 6;
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<String?> generateAndSaveSolutionPdf({
    required Test test,
    required List<Question> questions,
    required Map<String, String> selectedAnswers,
    required int score,
    required int total,
    required String studentName,
    required String rollNumber,
    DateTime? submissionDate,
  }) async {
    try {
      final bytes = await generateSolutionPdfBytes(
        test: test,
        questions: questions,
        selectedAnswers: selectedAnswers,
        score: score,
        total: total,
        studentName: studentName,
        rollNumber: rollNumber,
        submissionDate: submissionDate,
      );

      final safeRoll = rollNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
      final filename = 'MCQPro_Solution_${test.testCode ?? "TEST"}_Roll_$safeRoll.pdf';

      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Test Solutions PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (output != null) {
        try {
          final file = File(output);
          if (!file.existsSync() || file.lengthSync() == 0) {
            await file.writeAsBytes(bytes);
          }
        } catch (_) {}
      }
      return output ?? filename;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }

  // ==========================================
  // TEACHER TEST PAPER PDF
  // ==========================================

  static Future<Uint8List> generateTestPaperPdfBytes({
    required Test test,
    required List<Question> questions,
    bool includeAnswerKey = true,
  }) async {
    await _ensureFontLoaded();

    final document = PdfDocument();
    document.pageSettings.margins.all = 36;

    final footer = PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 540, 20));
    final numFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final textSecondary = PdfColor(70, 80, 95);
    final pageNumber = PdfPageNumberField(font: numFont, brush: PdfSolidBrush(textSecondary));
    final composite = PdfCompositeField(
      font: numFont,
      brush: PdfSolidBrush(textSecondary),
      text: '{0}',
      fields: [pageNumber],
    );
    composite.bounds = const Rect.fromLTWH(0, 4, 540, 15);
    composite.stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center);
    composite.draw(footer.graphics, const Offset(0, 0));
    document.template.bottom = footer;

    var page = document.pages.add();
    final clientWidth = page.getClientSize().width;
    final clientHeight = page.getClientSize().height;
    double y = 10;

    // 1. Render Header Block
    final headerBlock = await _renderTestPaperHeader(
      test: test,
      questionCount: questions.length,
      width: clientWidth,
    );

    final headerBitmap = PdfBitmap(headerBlock.pngBytes);
    page.graphics.drawImage(headerBitmap, Rect.fromLTWH(0, y, clientWidth, headerBlock.height));
    y += headerBlock.height + 10;

    // 2. Render Questions
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      final cardBlock = await _renderTestPaperQuestionCard(
        questionIndex: i,
        question: q,
        includeAnswerKey: includeAnswerKey,
        width: clientWidth,
      );

      // Check pagination
      if (y + cardBlock.height > clientHeight - 20) {
        page = document.pages.add();
        y = 10;
        final topBanner = await _renderRunningExamHeader(test: test, width: clientWidth);
        final bannerBitmap = PdfBitmap(topBanner.pngBytes);
        page.graphics.drawImage(bannerBitmap, Rect.fromLTWH(0, y, clientWidth, topBanner.height));
        y += topBanner.height + 8;
      }

      final cardBitmap = PdfBitmap(cardBlock.pngBytes);
      page.graphics.drawImage(cardBitmap, Rect.fromLTWH(0, y, clientWidth, cardBlock.height));
      y += cardBlock.height + 6;
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<String?> generateAndSaveTestPaperPdf({
    required Test test,
    required List<Question> questions,
    bool includeAnswerKey = true,
  }) async {
    try {
      final bytes = await generateTestPaperPdfBytes(
        test: test,
        questions: questions,
        includeAnswerKey: includeAnswerKey,
      );

      final filename = 'MCQPro_Test_${test.testCode ?? "TEST"}_Std${test.studentClass}.pdf';

      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Test Question Paper PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (output != null) {
        try {
          final file = File(output);
          if (!file.existsSync() || file.lengthSync() == 0) {
            await file.writeAsBytes(bytes);
          }
        } catch (_) {}
      }
      return output ?? filename;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }

  // ==========================================
  // HIGH-FIDELITY FLUTTER CANVAS RENDERERS
  // ==========================================

  static Future<_RenderedBlock> _renderSolutionHeader({
    required Test test,
    required String studentName,
    required String rollNumber,
    required int score,
    required int total,
    required String percentage,
    required DateTime subDate,
    required double width,
    double scale = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    double y = 0;

    // Title
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'MCQ PRO',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4F46E5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width);
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, y));
    y += titlePainter.height + 4;

    // Subtitle
    final subPainter = TextPainter(
      text: const TextSpan(
        text: 'Test Assessment & Detailed Solutions Report',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width);
    subPainter.paint(canvas, Offset((width - subPainter.width) / 2, y));
    y += subPainter.height + 10;

    // Divider
    final pen = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(width, y), pen);
    y += 8;

    // Metadata Table (2 columns, 5 rows)
    final isPassed = score >= (total * 0.5);
    final metaRows = [
      ['Student Name: ${_cleanText(studentName)}', 'Roll Number: ${_cleanText(rollNumber)}'],
      ['Class & Division: Std ${test.studentClass} - ${test.division ?? "All"}', 'Medium: ${_cleanText(test.medium).toUpperCase()}'],
      ['Subject: ${_cleanText(test.subject)}', 'Topic: ${_cleanText(test.topic)}'],
      ['Test Code: ${test.testCode ?? "N/A"}', 'Submission Date: ${DateFormat.yMMMd().add_jm().format(subDate)}'],
      ['Score Obtained: $score / $total ($percentage%)', 'Performance: ${isPassed ? "PASSED" : "NEEDS PRACTICE"}'],
    ];

    final colWidth = width / 2;
    for (int r = 0; r < metaRows.length; r++) {
      final row = metaRows[r];
      final isLastRow = r == metaRows.length - 1;

      final p1 = TextPainter(
        text: TextSpan(
          text: row[0],
          style: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: 9.0,
            fontWeight: isLastRow ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF1E293B),
            height: 1.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: colWidth - 12);

      final p2 = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: isLastRow ? 'Performance: ' : row[1],
              style: TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.0,
                fontWeight: isLastRow ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
            if (isLastRow)
              TextSpan(
                text: isPassed ? 'PASSED' : 'NEEDS PRACTICE',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontFamilyFallback: _fontFallback,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  color: isPassed ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  height: 1.3,
                ),
              ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: colWidth - 12);

      final rowH = (p1.height > p2.height ? p1.height : p2.height) + 6;
      final cellPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      canvas.drawRect(Rect.fromLTWH(0, y, colWidth, rowH), cellPaint);
      canvas.drawRect(Rect.fromLTWH(colWidth, y, colWidth, rowH), cellPaint);

      p1.paint(canvas, Offset(6, y + 3));
      p2.paint(canvas, Offset(colWidth + 6, y + 3));
      y += rowH;
    }
    y += 12;

    // Section title
    final secPainter = TextPainter(
      text: const TextSpan(
        text: 'QUESTIONS, SELECTED ANSWERS & SOLUTIONS',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4F46E5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width);
    secPainter.paint(canvas, Offset(0, y));
    y += secPainter.height + 6;

    final picture = recorder.endRecording();
    final img = await picture.toImage((width * scale).ceil(), (y * scale).ceil());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return _RenderedBlock(pngBytes: pngData!.buffer.asUint8List(), height: y);
  }

  static Future<_RenderedBlock> _renderSolutionQuestionCard({
    required int questionIndex,
    required Question question,
    required String? userAns,
    required double width,
    double scale = 2.0,
  }) async {
    final cleanAns = userAns?.trim();
    final cleanCorrect = question.correctAnswer.trim();
    final isCorrect = cleanAns != null &&
        cleanAns.isNotEmpty &&
        (cleanAns.toUpperCase() == cleanCorrect.toUpperCase() || cleanAns == cleanCorrect);
    final isUnanswered = cleanAns == null || cleanAns.isEmpty;

    final statusText = isCorrect ? '[CORRECT]' : (isUnanswered ? '[UNANSWERED]' : '[INCORRECT]');
    final statusColor = isCorrect
        ? const Color(0xFF059669)
        : (isUnanswered ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    double y = 0;

    // Status badge
    final badgePainter = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: statusColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: 100);

    // Question title & text
    final questionPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${questionIndex + 1}. ',
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          TextSpan(
            text: _cleanText(question.questionText),
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width - badgePainter.width - 12);

    questionPainter.paint(canvas, Offset(0, y));
    badgePainter.paint(canvas, Offset(width - badgePainter.width, y));
    y += (questionPainter.height > badgePainter.height ? questionPainter.height : badgePainter.height) + 6;

    // Optional Diagram / Reaction Mechanism Image
    if (question.imageUrl != null && question.imageUrl!.trim().isNotEmpty) {
      final qImage = await _loadCanvasImage(question.imageUrl);
      if (qImage != null) {
        final imgW = qImage.width.toDouble();
        final imgH = qImage.height.toDouble();
        final maxW = width - 40;
        const maxH = 150.0;
        double renderW = imgW;
        double renderH = imgH;
        if (renderW > maxW) {
          renderH = (renderH * maxW) / renderW;
          renderW = maxW;
        }
        if (renderH > maxH) {
          renderH = (renderH * maxH) / renderH;
          renderH = maxH;
        }
        final imgX = (width - renderW) / 2;
        canvas.drawImageRect(
          qImage,
          Rect.fromLTWH(0, 0, imgW, imgH),
          Rect.fromLTWH(imgX, y, renderW, renderH),
          Paint(),
        );
        y += renderH + 8;
        qImage.dispose();
      }
    }

    // Adaptive Options Grid (1 row x 4 cols, 2 rows x 2 cols, or 4 rows stacked)
    y = _renderOptionsGrid(
      canvas: canvas,
      startY: y,
      width: width,
      question: question,
      isSolutionReport: true,
      includeAnswerKey: false,
      userAns: cleanAns,
    );
    y += 4;

    // Selection Summary
    final ansPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '   Your Selection: ',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          TextSpan(
            text: cleanAns != null ? 'Option $cleanAns' : 'None (Unanswered)',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const TextSpan(
            text: '   |   Correct Answer: ',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          TextSpan(
            text: 'Option ${question.correctAnswer}',
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width - 10);

    ansPainter.paint(canvas, Offset(0, y));
    y += ansPainter.height + 6;

    // Explanation Box
    final cleanExp = _cleanText(question.explanation);
    if (cleanExp.isNotEmpty) {
      final expPainter = TextPainter(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Explanation: ',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            TextSpan(
              text: cleanExp,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.0,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 24);

      final expBoxH = expPainter.height + 12;
      final expRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(6, y, width - 12, expBoxH),
        const Radius.circular(6),
      );
      final expBgPaint = Paint()..color = const Color(0xFFF8FAFC);
      final expBorderPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      canvas.drawRRect(expRRect, expBgPaint);
      canvas.drawRRect(expRRect, expBorderPaint);
      expPainter.paint(canvas, Offset(12, y + 6));
      y += expBoxH + 6;
    }

    // Divider line
    final divPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, y), Offset(width, y), divPaint);
    y += 8;

    final picture = recorder.endRecording();
    final img = await picture.toImage((width * scale).ceil(), (y * scale).ceil());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return _RenderedBlock(pngBytes: pngData!.buffer.asUint8List(), height: y);
  }

  static Future<_RenderedBlock> _renderTestPaperHeader({
    required Test test,
    required int questionCount,
    required double width,
    double scale = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    double y = 0;

    // Top Exam Assignment Banner (as shown in standard exam papers)
    final subjectStr = _cleanText(test.subject).toUpperCase();
    final classStr = 'Std-${test.studentClass} (${test.medium.toUpperCase()})';
    final topicStr = _cleanText(test.topic).toUpperCase();

    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);
    y += 5;

    final bannerColW = width / 3;

    final bLeft = TextPainter(
      text: TextSpan(
        text: subjectStr,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          letterSpacing: 0.8,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: bannerColW);
    bLeft.paint(canvas, Offset(0, y));

    final bCenter = TextPainter(
      text: TextSpan(
        text: classStr,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: bannerColW);
    bCenter.paint(canvas, Offset(bannerColW + (bannerColW - bCenter.width) / 2, y));

    final bRight = TextPainter(
      text: TextSpan(
        text: topicStr.contains('ASSIGN') ? topicStr : 'ASSIGNMENT',
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          letterSpacing: 0.8,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: bannerColW);
    bRight.paint(canvas, Offset(width - bRight.width, y));

    final bannerH = [bLeft.height, bCenter.height, bRight.height].reduce((a, b) => a > b ? a : b);
    y += bannerH + 5;
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);
    y += 10;

    // Title
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'MCQ PRO - TEST QUESTION PAPER',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4F46E5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width);
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, y));
    y += titlePainter.height + 4;

    // Subtitle
    final subPainter = TextPainter(
      text: TextSpan(
        text: 'Subject: ${_cleanText(test.subject)}   |   Topic: ${_cleanText(test.topic)}',
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width);
    subPainter.paint(canvas, Offset((width - subPainter.width) / 2, y));
    y += subPainter.height + 10;

    // Divider
    final pen = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(width, y), pen);
    y += 8;

    // Metadata Table (2 columns, 3 rows)
    final metaRows = [
      ['Class: Standard ${test.studentClass} (${test.division ?? "All"})', 'Medium: ${_cleanText(test.medium).toUpperCase()}'],
      ['Total Questions: $questionCount', 'Duration: ${test.duration} Minutes'],
      ['Test Code: ${test.testCode ?? "N/A"}', 'Date: ${DateFormat("dd MMM yyyy").format(test.createdAt ?? DateTime.now())}'],
    ];

    final colWidth = width / 2;
    for (final row in metaRows) {
      final p1 = TextPainter(
        text: TextSpan(
          text: row[0],
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: 9.0,
            color: Color(0xFF1E293B),
            height: 1.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: colWidth - 12);

      final p2 = TextPainter(
        text: TextSpan(
          text: row[1],
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: 9.0,
            color: Color(0xFF1E293B),
            height: 1.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: colWidth - 12);

      final rowH = (p1.height > p2.height ? p1.height : p2.height) + 6;
      final cellPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      canvas.drawRect(Rect.fromLTWH(0, y, colWidth, rowH), cellPaint);
      canvas.drawRect(Rect.fromLTWH(colWidth, y, colWidth, rowH), cellPaint);

      p1.paint(canvas, Offset(6, y + 3));
      p2.paint(canvas, Offset(colWidth + 6, y + 3));
      y += rowH;
    }
    y += 12;

    // Section title
    final secPainter = TextPainter(
      text: const TextSpan(
        text: 'QUESTIONS & OPTIONS',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4F46E5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width);
    secPainter.paint(canvas, Offset(0, y));
    y += secPainter.height + 6;

    final picture = recorder.endRecording();
    final img = await picture.toImage((width * scale).ceil(), (y * scale).ceil());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return _RenderedBlock(pngBytes: pngData!.buffer.asUint8List(), height: y);
  }

  /// Running header at the top of each test assignment page (as shown in standard exam papers)
  static Future<_RenderedBlock> _renderRunningExamHeader({
    required Test test,
    required double width,
    double scale = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    double y = 0;

    final subjectStr = _cleanText(test.subject).toUpperCase();
    final classStr = 'Std-${test.studentClass} ${test.medium.toUpperCase()}';
    final topicStr = _cleanText(test.topic).toUpperCase();

    // Top border line
    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);
    y += 4;

    final colWidth = width / 3;

    // Left: Subject
    final leftPainter = TextPainter(
      text: TextSpan(
        text: subjectStr,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          letterSpacing: 0.6,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: colWidth);
    leftPainter.paint(canvas, Offset(0, y));

    // Center: Class
    final centerPainter = TextPainter(
      text: TextSpan(
        text: classStr,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: colWidth);
    centerPainter.paint(canvas, Offset(colWidth + (colWidth - centerPainter.width) / 2, y));

    // Right: Assignment Title
    final rightPainter = TextPainter(
      text: TextSpan(
        text: topicStr.contains('ASSIGN') ? topicStr : 'ASSIGNMENT',
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          letterSpacing: 0.6,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: colWidth);
    rightPainter.paint(canvas, Offset(width - rightPainter.width, y));

    final bannerH = [leftPainter.height, centerPainter.height, rightPainter.height].reduce((a, b) => a > b ? a : b);
    y += bannerH + 4;

    // Bottom border line
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);
    y += 6;

    final picture = recorder.endRecording();
    final img = await picture.toImage((width * scale).ceil(), (y * scale).ceil());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return _RenderedBlock(pngBytes: pngData!.buffer.asUint8List(), height: y);
  }

  /// Adaptive grid renderer for Options A, B, C, D:
  /// - 1 row (4 columns) if short (e.g. Q43 in real exam papers)
  /// - 2 rows (2 columns) if medium (e.g. Q44, Q45 in real exam papers)
  /// - 4 rows (vertical) for long text
  static double _renderOptionsGrid({
    required Canvas canvas,
    required double startY,
    required double width,
    required Question question,
    required bool isSolutionReport,
    required bool includeAnswerKey,
    String? userAns,
  }) {
    double y = startY;
    final options = [
      ('A', question.optionA),
      ('B', question.optionB),
      ('C', question.optionC),
      ('D', question.optionD),
    ];

    final cleanCorrect = question.correctAnswer.trim();
    final optPainters = options.map((opt) {
      final isCorrect = (includeAnswerKey || isSolutionReport) &&
          (opt.$1.toUpperCase() == cleanCorrect.toUpperCase() ||
              opt.$2.trim() == cleanCorrect);
      final isSelectedByUser = isSolutionReport && userAns != null &&
          (opt.$1.toUpperCase() == userAns.trim().toUpperCase() ||
              opt.$2.trim() == userAns.trim());

      Color textColor = const Color(0xFF1E293B);
      FontWeight fontWeight = FontWeight.w500;
      if (isCorrect) {
        textColor = const Color(0xFF059669);
        fontWeight = FontWeight.w700;
      } else if (isSelectedByUser && !isCorrect) {
        textColor = const Color(0xFFDC2626);
        fontWeight = FontWeight.w600;
      }

      return TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '(${opt.$1}) ',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.5,
                fontWeight: isCorrect ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
            TextSpan(
              text: _cleanText(opt.$2),
              style: TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.5,
                fontWeight: fontWeight,
                color: textColor,
                height: 1.3,
              ),
            ),
            if (isCorrect && includeAnswerKey)
              const TextSpan(
                text: ' [CORRECT]',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontFamilyFallback: _fontFallback,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      );
    }).toList();

    // 1. Try 4-Column Layout (single horizontal line)
    final col4W = (width - 24) / 4;
    bool canFit4Col = true;
    for (final p in optPainters) {
      p.layout(maxWidth: col4W);
      if (p.height > 22) {
        canFit4Col = false;
        break;
      }
    }

    if (canFit4Col) {
      double maxH = 0;
      for (int i = 0; i < 4; i++) {
        optPainters[i].paint(canvas, Offset(i * (col4W + 8), y));
        if (optPainters[i].height > maxH) maxH = optPainters[i].height;
      }
      return y + maxH + 4;
    }

    // 2. Try 2-Column Layout (2 rows x 2 columns)
    final col2W = (width - 16) / 2;
    bool canFit2Col = true;
    for (final p in optPainters) {
      p.layout(maxWidth: col2W);
      if (p.height > 36) {
        canFit2Col = false;
        break;
      }
    }

    if (canFit2Col) {
      // Row 1: Option A and Option B
      final row1H = optPainters[0].height > optPainters[1].height
          ? optPainters[0].height
          : optPainters[1].height;
      optPainters[0].paint(canvas, Offset(0, y));
      optPainters[1].paint(canvas, Offset(col2W + 16, y));
      y += row1H + 4;

      // Row 2: Option C and Option D
      final row2H = optPainters[2].height > optPainters[3].height
          ? optPainters[2].height
          : optPainters[3].height;
      optPainters[2].paint(canvas, Offset(0, y));
      optPainters[3].paint(canvas, Offset(col2W + 16, y));
      y += row2H + 4;

      return y;
    }

    // 3. Vertical 1-Column Layout (stacked, for long questions)
    for (final p in optPainters) {
      p.layout(maxWidth: width - 10);
      p.paint(canvas, Offset(0, y));
      y += p.height + 4;
    }
    return y;
  }

  static Future<_RenderedBlock> _renderTestPaperQuestionCard({
    required int questionIndex,
    required Question question,
    required bool includeAnswerKey,
    required double width,
    double scale = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);
    double y = 0;

    // Question number & text (Exam style: "43. Question Text")
    final questionPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${questionIndex + 1}. ',
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          TextSpan(
            text: _cleanText(question.questionText),
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width);

    questionPainter.paint(canvas, Offset(0, y));
    y += questionPainter.height + 6;

    // Optional Diagram / Reaction Mechanism Image
    if (question.imageUrl != null && question.imageUrl!.trim().isNotEmpty) {
      final qImage = await _loadCanvasImage(question.imageUrl);
      if (qImage != null) {
        final imgW = qImage.width.toDouble();
        final imgH = qImage.height.toDouble();
        final maxW = width - 40;
        const maxH = 150.0;
        double renderW = imgW;
        double renderH = imgH;
        if (renderW > maxW) {
          renderH = (renderH * maxW) / renderW;
          renderW = maxW;
        }
        if (renderH > maxH) {
          renderW = (renderW * maxH) / renderH;
          renderH = maxH;
        }
        final imgX = (width - renderW) / 2;
        canvas.drawImageRect(
          qImage,
          Rect.fromLTWH(0, 0, imgW, imgH),
          Rect.fromLTWH(imgX, y, renderW, renderH),
          Paint(),
        );
        y += renderH + 8;
        qImage.dispose();
      }
    }

    // Adaptive Options Grid (1 row x 4 cols, 2 rows x 2 cols, or 4 rows stacked)
    y = _renderOptionsGrid(
      canvas: canvas,
      startY: y,
      width: width,
      question: question,
      isSolutionReport: false,
      includeAnswerKey: includeAnswerKey,
    );

    // Explanation Box (if includeAnswerKey)
    final cleanExp = _cleanText(question.explanation);
    if (includeAnswerKey && cleanExp.isNotEmpty) {
      y += 2;
      final expPainter = TextPainter(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Explanation: ',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            TextSpan(
              text: cleanExp,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: _fontFallback,
                fontSize: 9.0,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 24);

      final expBoxH = expPainter.height + 12;
      final expRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(6, y, width - 12, expBoxH),
        const Radius.circular(6),
      );
      final expBgPaint = Paint()..color = const Color(0xFFF8FAFC);
      final expBorderPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      canvas.drawRRect(expRRect, expBgPaint);
      canvas.drawRRect(expRRect, expBorderPaint);
      expPainter.paint(canvas, Offset(12, y + 6));
      y += expBoxH + 6;
    }

    // Divider line
    final divPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, y), Offset(width, y), divPaint);
    y += 8;

    final picture = recorder.endRecording();
    final img = await picture.toImage((width * scale).ceil(), (y * scale).ceil());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return _RenderedBlock(pngBytes: pngData!.buffer.asUint8List(), height: y);
  }
}

