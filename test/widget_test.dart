import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/core/widgets/app_card.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';

void main() {
  testWidgets('AppCard renders child and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCard(
            onTap: () => tapped = true,
            child: const Text('MCQ Pro Card Content'),
          ),
        ),
      ),
    );

    expect(find.text('MCQ Pro Card Content'), findsOneWidget);
    await tester.tap(find.text('MCQ Pro Card Content'));
    expect(tapped, isTrue);
  });

  test('AppColors brand constants check', () {
    expect(AppColors.primary, isNotNull);
    expect(AppColors.secondary, isNotNull);
    expect(AppColors.cardBackground, equals(const Color(0xFFFFFFFF)));
  });
}
