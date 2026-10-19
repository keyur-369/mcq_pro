import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/core/services/pdf_export_service.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfExportService renders complete Gujarati solution and test paper PDFs', () async {
    final sampleTest = Test(
      id: 'test_123',
      teacherId: 'teacher_1',
      studentClass: '12',
      division: 'A',
      medium: 'Gujarati',
      subject: 'રસાયણ વિજ્ઞાન (Chemistry)',
      topic: 'વાન્ટ હોફ અવયવ (Van\'t Hoff Factor)',
      level: 'Boards',
      duration: 30,
      testCode: 'a8e7q1',
      status: TestStatus.published,
      createdAt: DateTime.now(),
    );

    final questions = [
      Question(
        id: 'q1',
        testId: 'test_123',
        questionText: 'નીચેનામાંથી કયા 0.1 M જલીય દ્રાવણ માટે વાન્ટ હોફ અવયવ (i) નું મૂલ્ય સૌથી વધુ હશે?',
        optionA: '0.1 M NaCl',
        optionB: '0.1 M K2SO4',
        optionC: '0.1 M AlCl3',
        optionD: '0.1 M ગ્લુકોઝ (C6H12O6)',
        correctAnswer: 'C',
        explanation: 'AlCl3 સંપૂર્ણ વિયોજન પામી 4 આયનો (Al^3+ + 3Cl-) આપે છે, તેથી i = 4. જ્યારે NaCl માટે i = 2, K2SO4 માટે i = 3 અને ગ્લુકોઝ બિન-વિદ્યુતવિભાજ્ય હોવાથી i = 1 છે.',
      ),
      Question(
        id: 'q2',
        testId: 'test_123',
        questionText: 'જો કોઈ પદાર્થ સુયોજન પામી દ્વિઅણુક (dimer) બનાવે, તો વાન્ટ હોફ અવયવ (i) નું મૂલ્ય શું થાય?',
        optionA: 'i > 1',
        optionB: 'i = 1',
        optionC: 'i < 1',
        optionD: 'i = 0',
        correctAnswer: 'C',
        explanation: 'સુયોજન થવાથી દ્રાવણમાં કણોની સંખ્યા ઘટે છે, તેથી i નું મૂલ્ય 1 કરતાં ઓછું (i < 1) થાય છે.',
      ),
    ];

    final selectedAnswers = {
      'q1': 'C',
      'q2': 'A',
    };

    // Test Solution PDF bytes export
    final solutionBytes = await PdfExportService.generateSolutionPdfBytes(
      test: sampleTest,
      questions: questions,
      selectedAnswers: selectedAnswers,
      score: 1,
      total: 2,
      studentName: 'સાક્ષી પંડ્યા (Sakshi Pandya)',
      rollNumber: '6',
      submissionDate: DateTime.now(),
    );

    expect(solutionBytes.isNotEmpty, isTrue);

    // Test Teacher Test Paper PDF bytes export
    final testPaperBytes = await PdfExportService.generateTestPaperPdfBytes(
      test: sampleTest,
      questions: questions,
      includeAnswerKey: true,
    );

    expect(testPaperBytes.isNotEmpty, isTrue);
  });
}
