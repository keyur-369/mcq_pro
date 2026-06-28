import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AiGeneratorService {
  static const int _batchSize = 10;
  static const int _maxConcurrency = 3;
  static const int _maxRetries = 3;

  // ── Error helpers ──────────────────────────────────────────────────────────

  bool _isModelNotAvailableError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('not found') ||
        msg.contains('404') ||
        msg.contains('unsupported') ||
        msg.contains('is not found');
  }

  bool _isQuotaOrRateLimitError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('quota exceeded') ||
        msg.contains('rate limit') ||
        msg.contains('resource_exhausted') ||
        msg.contains('429');
  }

  bool _isTransientError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('503') ||
        msg.contains('unavailable') ||
        msg.contains('500') ||
        msg.contains('internal') ||
        msg.contains('overloaded');
  }

  bool _shouldTryNextModel(Object error) =>
      _isModelNotAvailableError(error) || _isQuotaOrRateLimitError(error);

  List<String> _modelFallbackChain(String preferred) =>
      <String>[preferred, 'gemini-2.5-flash', 'gemini-2.5-flash-lite']
          .toSet()
          .toList();

  // ── JSON decode ────────────────────────────────────────────────────────────

  List<dynamic> _decodeJsonArray(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s*```$'), '').trim();

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } catch (_) {}

    final s = text.indexOf('['), e = text.lastIndexOf(']');
    if (s != -1 && e > s) {
      final decoded = jsonDecode(text.substring(s, e + 1));
      if (decoded is List) return decoded;
    }

    final os = text.indexOf('{'), oe = text.lastIndexOf('}');
    if (os != -1 && oe > os) {
      final decoded = jsonDecode(text.substring(os, oe + 1));
      if (decoded is Map) return [decoded];
    }

    throw FormatException('Model did not return valid JSON.');
  }

  // ── Text helpers ───────────────────────────────────────────────────────────

  String _compactText(String input) => input
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  List<String> _splitTextIntoChunks(String text, int batchCount) {
    if (batchCount <= 1) return [text];
    final chunkSize = (text.length / batchCount).ceil();
    final chunks = <String>[];
    for (int i = 0; i < batchCount; i++) {
      final start = i * chunkSize;
      if (start >= text.length) break;
      chunks.add(text.substring(start, (start + chunkSize).clamp(0, text.length)));
    }
    return chunks;
  }

  // ── Model → Question ───────────────────────────────────────────────────────

  Question _mapToQuestion(dynamic item, String testId) => Question(
    id: '',
    testId: testId,
    questionText: item['question'] ?? 'No question text',
    optionA: item['a'] ?? '',
    optionB: item['b'] ?? '',
    optionC: item['c'] ?? '',
    optionD: item['d'] ?? '',
    correctAnswer: item['answer'] ?? 'A',
    explanation: item['explanation'] ?? '',
  );

  // ── Single batch with retry + model fallback ───────────────────────────────

  Future<List<Question>> _generateBatch({
    required String prompt,
    required String systemInstruction,
    required String testId,
    required String apiKey,
    required String modelName,
    required int batchNumber,
    required int totalBatches,
    void Function(int count)? onBatchComplete,
  }) async {
    final fallbacks = _modelFallbackChain(modelName);
    Object? lastError;

    for (final candidateModel in fallbacks) {
      int attempt = 0;
      while (attempt < _maxRetries) {
        try {
          debugPrint(
            '🔄 Batch $batchNumber/$totalBatches | Model: $candidateModel | Attempt: ${attempt + 1}',
          );

          final model = GenerativeModel(
            model: candidateModel,
            apiKey: apiKey,
            systemInstruction: Content.system(systemInstruction),
            generationConfig: GenerationConfig(responseMimeType: 'application/json'),
          );

          final response = await model.generateContent([Content.text(prompt)]);
          final text = response.text;
          if (text == null || text.trim().isEmpty) {
            throw Exception('Empty response from AI model');
          }

          final data = _decodeJsonArray(text);
          final questions = data.map((item) => _mapToQuestion(item, testId)).toList();

          debugPrint('✅ Batch $batchNumber/$totalBatches — ${questions.length} questions');

          // 🔔 Notify caller with actual count generated
          onBatchComplete?.call(questions.length);

          return questions;
        } catch (e) {
          lastError = e;

          if (_isTransientError(e) && attempt < _maxRetries - 1) {
            final backoff = Duration(seconds: (1 << attempt));
            debugPrint(
              '⚠️ Batch $batchNumber transient error, retrying in ${backoff.inSeconds}s...',
            );
            await Future.delayed(backoff);
            attempt++;
            continue;
          }

          if (_shouldTryNextModel(e) && candidateModel != fallbacks.last) {
            debugPrint('🔁 Switching from $candidateModel to next fallback...');
            break;
          }

          debugPrint('❌ Batch $batchNumber error: $e');
          throw 'Batch $batchNumber failed: $e';
        }
      }
    }

    throw 'Batch $batchNumber failed after all retries. Last error: $lastError';
  }

  // ── Parallel runner with controlled concurrency ────────────────────────────

  Future<List<T>> _runConcurrent<T>(
      List<Future<T> Function()> tasks, {
        int maxConcurrent = 3,
      }) async {
    final results = List<T?>.filled(tasks.length, null);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= tasks.length) return;
        results[index] = await tasks[index]();
      }
    }

    final workers = List.generate(
      maxConcurrent.clamp(1, tasks.length),
          (_) => worker(),
    );
    await Future.wait(workers);

    return results.cast<T>();
  }

  // ── PUBLIC: Generate from topic ────────────────────────────────────────────

  Future<List<Question>> generateQuestions({
    required String subject,
    required String topic,
    required String level,
    required int count,
    required String testId,
    required String medium,
    required String apiKey,
    String modelName = 'gemini-2.5-flash',
    void Function(int generatedSoFar)? onProgress,
  }) async {
    final totalBatches = (count / _batchSize).ceil();

    debugPrint(
      '📋 Generating $count questions | $totalBatches batches | $_maxConcurrency parallel',
    );

    final systemInstruction =
        'You are an expert exam paper setter for Class 11-12 Science. '
        'Language: ${medium.toUpperCase()}. '
        'Generate high-quality, UNIQUE Multiple Choice Questions (MCQs) '
        'for subject "$subject" on topic "$topic" at $level level. '
        'All questions must be distinct within this batch. '
        'Output MUST be a valid JSON ARRAY. '
        'Each object MUST have keys: "question", "a", "b", "c", "d", "answer", "explanation". '
        '"answer" must be one of "A", "B", "C", or "D". '
        'All text must be in ${medium.toUpperCase()}.';

    // Shared counter — safe because Dart is single-threaded
    int generatedSoFar = 0;

    final tasks = List.generate(totalBatches, (i) {
      final batchCount =
      (i == totalBatches - 1) ? count - (i * _batchSize) : _batchSize;
      final prompt =
          'Generate $batchCount UNIQUE MCQs for subject "$subject", '
          'topic "$topic", level "$level". '
          'Batch ${i + 1} of $totalBatches — cover different aspects to avoid repetition.';

      return () => _generateBatch(
        prompt: prompt,
        systemInstruction: systemInstruction,
        testId: testId,
        apiKey: apiKey,
        modelName: modelName,
        batchNumber: i + 1,
        totalBatches: totalBatches,
        onBatchComplete: (batchCount) {
          generatedSoFar += batchCount;
          onProgress?.call(generatedSoFar);
        },
      );
    });

    final batchResults = await _runConcurrent(tasks, maxConcurrent: _maxConcurrency);
    final allQuestions = batchResults.expand((q) => q).toList();

    debugPrint('🎉 Total questions generated: ${allQuestions.length}');
    return allQuestions;
  }

  // ── PUBLIC: Generate from PDF ──────────────────────────────────────────────

  Future<List<Question>> generateQuestionsFromPdf({
    required String subject,
    required String topic,
    required String level,
    required int count,
    required String testId,
    required String medium,
    required List<int> pdfBytes,
    required String apiKey,
    String modelName = 'gemini-2.5-flash',
    void Function(int generatedSoFar)? onProgress,
  }) async {
    // Step 1: Extract PDF text
    String extractedText = '';
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      if (extractedText.trim().isEmpty) {
        throw 'The PDF appears to be empty or contains only images.';
      }
    } catch (e) {
      throw 'Failed to read PDF: $e';
    }

    final compactedText = _compactText(extractedText);
    final totalBatches = (count / _batchSize).ceil();

    debugPrint(
      '📄 PDF: ${compactedText.length} chars | $count questions | '
          '$totalBatches batches | $_maxConcurrency parallel',
    );

    final textChunks = _splitTextIntoChunks(compactedText, totalBatches);
    final hintLine = topic.trim().isEmpty ? '' : '\nTopic hint: "$topic"';

    final systemInstruction =
        'You are an expert exam paper setter for Class 11-12 Science. '
        'Language: ${medium.toUpperCase()}. '
        'Generate high-quality MCQs STRICTLY based on the provided PDF content. '
        'Subject: $subject. Level: $level.$hintLine '
        'Do NOT use knowledge outside the provided content. '
        'Output MUST be a valid JSON ARRAY. '
        'Each object MUST have keys: "question", "a", "b", "c", "d", "answer", "explanation". '
        '"answer" must be one of "A", "B", "C", or "D". '
        'All text must be in ${medium.toUpperCase()}.';

    // Shared counter — safe because Dart is single-threaded
    int generatedSoFar = 0;

    final tasks = List.generate(totalBatches, (i) {
      final batchCount =
      (i == totalBatches - 1) ? count - (i * _batchSize) : _batchSize;
      final pdfChunk = textChunks[i % textChunks.length];
      final prompt =
          'Generate $batchCount UNIQUE MCQs based ONLY on the PDF content below. '
          'Batch ${i + 1} of $totalBatches.$hintLine\n\n'
          'PDF Content:\n$pdfChunk';

      return () => _generateBatch(
        prompt: prompt,
        systemInstruction: systemInstruction,
        testId: testId,
        apiKey: apiKey,
        modelName: modelName,
        batchNumber: i + 1,
        totalBatches: totalBatches,
        onBatchComplete: (batchCount) {
          generatedSoFar += batchCount;
          onProgress?.call(generatedSoFar);
        },
      );
    });

    final batchResults = await _runConcurrent(tasks, maxConcurrent: _maxConcurrency);
    final allQuestions = batchResults.expand((q) => q).toList();

    debugPrint('🎉 Total questions generated from PDF: ${allQuestions.length}');
    return allQuestions;
  }
}