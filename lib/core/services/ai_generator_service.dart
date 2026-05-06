import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AiGeneratorService {


  bool _isModelNotAvailableError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('not found') ||
        message.contains('404') ||
        message.contains('unsupported') ||
        message.contains('is not found');
  }

  bool _isQuotaOrRateLimitError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('quota exceeded') ||
        message.contains('rate limit') ||
        message.contains('resource_exhausted') ||
        message.contains('429');
  }

  bool _shouldTryNextModel(Object error) {
    return _isModelNotAvailableError(error) || _isQuotaOrRateLimitError(error);
  }

  List<String> _modelFallbackChain(String preferred) {
    final ordered = <String>[
      preferred,
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
    ];

    return ordered.toSet().toList();
  }

  List<dynamic> _decodeJsonArray(String raw) {
    var text = raw.trim();

    // Remove common markdown fences if the model returns them.
    // Example: ```json\n[ ... ]\n```
    text = text.replaceAll(
      RegExp(r'^```(?:json)?\s*', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\s*```$'), '');
    text = text.trim();

    // Try exact decode first.
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } catch (_) {
      // fallthrough to substring extraction
    }

    // Fallback: extract the first JSON array in the text.
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      final candidate = text.substring(start, end + 1);
      final decoded = jsonDecode(candidate);
      if (decoded is List) return decoded;
    }

    // Fallback: extract the first JSON object in the text and wrap it.
    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
      final candidate = text.substring(objStart, objEnd + 1);
      final decoded = jsonDecode(candidate);
      if (decoded is Map) return [decoded];
    }

    throw FormatException('Model did not return valid JSON.');
  }

  String _compactText(String input, {required int maxChars}) {
    final collapsed = input
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (collapsed.length <= maxChars) return collapsed;

    // Keep start + end; the end often contains summaries/exercises.
    final head = collapsed.substring(0, (maxChars * 0.7).floor());
    final tail = collapsed.substring(
      collapsed.length - (maxChars * 0.3).floor(),
    );
    return '$head\n\n...[truncated]...\n\n$tail';
  }

  Future<List<Question>> generateQuestions({
    required String subject,
    required String topic,
    required String level,
    required int count,
    required String testId,
    required String medium,
    required String apiKey,
    String modelName = 'gemini-2.5-flash',
  }) async {
    final prompt = 'Generate $count unique MCQs in a JSON array format.';
    final fallbacks = _modelFallbackChain(modelName);
    Object? lastError;

    for (final candidateModel in fallbacks) {
      try {
        final model = GenerativeModel(
          model: candidateModel,
          apiKey: apiKey,
          systemInstruction: Content.system(
            'You are an expert exam paper setter for Class 11-12 Science. '
            'Language: ${medium.toUpperCase()}. '
            'Your task is to generate high-quality, UNIQUE Multiple Choice Questions (MCQs) for the subject $subject on the topic "$topic" at $level level. '
            'IMPORTANT: Ensure all questions are distinct and do not repeat within the generated set. '
            'Output MUST be a valid JSON ARRAY of objects. '
            'Each object MUST contain the following keys exactly: "question", "a", "b", "c", "d", "answer", "explanation". '
            'The "answer" must be one of "A", "B", "C", or "D". '
            'Ensure all text content is in ${medium.toUpperCase()}.',
          ),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);

        final text = response.text;
        if (text == null) throw Exception('AI failed to generate questions');

        final List<dynamic> data = _decodeJsonArray(text);

        return data
            .map(
              (item) => Question(
                id: '',
                testId: testId,
                questionText: item['question'] ?? 'No question text',
                optionA: item['a'] ?? '',
                optionB: item['b'] ?? '',
                optionC: item['c'] ?? '',
                optionD: item['d'] ?? '',
                correctAnswer: item['answer'] ?? 'A',
                explanation: item['explanation'] ?? '',
              ),
            )
            .toList();
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e) && candidateModel != fallbacks.last) {
          debugPrint(
            'Model $candidateModel failed (${e.runtimeType}), trying next fallback...',
          );
          continue;
        }

        debugPrint('AI Error with model $candidateModel: $e');
        throw 'Failed to generate questions using AI. Error: $e';
      }
    }

    throw 'Failed to generate questions using AI. Last error: $lastError';
  }

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
  }) async {
    // 1. Extract text from PDF locally
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

    // 1b. Compact / limit PDF text to avoid model input overflow.
    // Gemini models have context limits, but the SDK will still fail if you send huge prompts.
    final limitedText = _compactText(extractedText, maxChars: 24000);

    // 3. Create prompt with extracted text
    final hintLine = topic.trim().isEmpty ? '' : '\nTopic hint: "$topic"\n';
    final prompt =
        'Generate $count UNIQUE MCQs based only on the PDF content below.'
        '$hintLine'
        '\nPDF content:\n$limitedText';

    final fallbacks = _modelFallbackChain(modelName);
    Object? lastError;

    for (final candidateModel in fallbacks) {
      try {
        final model = GenerativeModel(
          model: candidateModel,
          apiKey: apiKey,
          systemInstruction: Content.system(
            'You are an expert exam paper setter for Class 11-12 Science. '
            'Language: ${medium.toUpperCase()}. '
            'Your task is to generate high-quality Multiple Choice Questions (MCQs) BASED STRICTLY ON THE PROVIDED CONTENT. '
            'Subject: $subject, Topic/Hint: "$topic", Level: $level. '
            'IMPORTANT: Do not use knowledge outside the provided content. '
            'Output MUST be a valid JSON ARRAY of objects. '
            'Each object MUST contain the following keys exactly: "question", "a", "b", "c", "d", "answer", "explanation". '
            'The "answer" must be one of "A", "B", "C", or "D". '
            'Ensure all text content is in ${medium.toUpperCase()}.',
          ),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

        final response = await model.generateContent([Content.text(prompt)]);

        final text = response.text;
        if (text == null) {
          throw Exception(
            'AI failed to generate questions from extracted text',
          );
        }

        final List<dynamic> data = _decodeJsonArray(text);

        return data
            .map(
              (item) => Question(
                id: '',
                testId: testId,
                questionText: item['question'] ?? 'No question text',
                optionA: item['a'] ?? '',
                optionB: item['b'] ?? '',
                optionC: item['c'] ?? '',
                optionD: item['d'] ?? '',
                correctAnswer: item['answer'] ?? 'A',
                explanation: item['explanation'] ?? '',
              ),
            )
            .toList();
      } catch (e) {
        lastError = e;
        if (_shouldTryNextModel(e) && candidateModel != fallbacks.last) {
          debugPrint(
            'Model $candidateModel failed (${e.runtimeType}), trying next fallback...',
          );
          continue;
        }

        debugPrint('AI PDF Error with model $candidateModel: $e');
        throw 'Failed to generate questions. Error: $e';
      }
    }

    throw 'Failed to generate questions from PDF. Last error: $lastError';
  }
}
