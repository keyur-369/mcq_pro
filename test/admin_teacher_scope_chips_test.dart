import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/utils/academic_year_utils.dart';
import 'package:mcq_test_app/features/admin/screens/admin_create_teacher_screen.dart';
import 'package:mcq_test_app/models/app_user.dart';

void main() {
  group('Admin Teacher & Scope - Institution and Division Chips UI', () {
    testWidgets('Renders fields in exact required layout order', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCreateTeacherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check field headers exist
      expect(find.text('Standards (Classes)'), findsOneWidget);
      expect(find.text('Institution'), findsOneWidget);
      expect(find.text('Academic Year'), findsOneWidget);
      expect(find.text('Divisions / Groups'), findsOneWidget);
      expect(find.text('Mediums'), findsOneWidget);
      expect(find.text('Assigned Subjects'), findsOneWidget);

      // Verify vertical layout order:
      // Standards < Institution < Academic Year < Divisions / Groups < Mediums < Assigned Subjects
      final stdY = tester.getTopLeft(find.text('Standards (Classes)')).dy;
      final instY = tester.getTopLeft(find.text('Institution')).dy;
      final acadY = tester.getTopLeft(find.text('Academic Year')).dy;
      final divY = tester.getTopLeft(find.text('Divisions / Groups')).dy;
      final medY = tester.getTopLeft(find.text('Mediums')).dy;
      final subY = tester.getTopLeft(find.text('Assigned Subjects')).dy;

      expect(stdY < instY, isTrue, reason: 'Standards should be above Institution');
      expect(instY < acadY, isTrue, reason: 'Institution should be above Academic Year');
      expect(acadY < divY, isTrue, reason: 'Academic Year should be above Divisions');
      expect(divY < medY, isTrue, reason: 'Divisions should be above Mediums');
      expect(medY < subY, isTrue, reason: 'Mediums should be above Subjects');
    });

    testWidgets('Requires institution selection before displaying divisions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCreateTeacherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Institution chips are visible
      expect(find.text('Sharda mandir'), findsOneWidget);
      expect(find.text('Tuition ACC'), findsOneWidget);

      // Before selecting institution, placeholder is shown
      expect(find.text('Please select an institution above to choose divisions'), findsOneWidget);
      expect(find.text('Div A'), findsNothing);
      expect(find.text('ACC'), findsNothing);
    });

    testWidgets('Selecting Sharda mandir shows only Div A, Div B, Div C and allows multiple selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCreateTeacherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sharda mandir
      await tester.tap(find.text('Sharda mandir'));
      await tester.pumpAndSettle();

      // Sharda mandir chip should be selected with white text
      final shardaChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sharda mandir'));
      final accChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tuition ACC'));
      expect(shardaChip.selected, isTrue);
      expect(shardaChip.labelStyle?.color, equals(Colors.white));
      expect(accChip.selected, isFalse);
      expect(accChip.labelStyle?.color, equals(AppColors.textSecondary));

      // Divisions for Sharda Mandir appear
      expect(find.text('Div A'), findsOneWidget);
      expect(find.text('Div B'), findsOneWidget);
      expect(find.text('Div C'), findsOneWidget);

      // Excluded divisions must NOT appear
      expect(find.text('Div AB'), findsNothing);
      expect(find.text('Div Science'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'ACC'), findsNothing);

      // Select multiple divisions (Div A and Div B)
      await tester.tap(find.text('Div A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Div B'));
      await tester.pumpAndSettle();

      final chipA = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Div A'));
      final chipB = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Div B'));
      final chipC = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Div C'));

      expect(chipA.selected, isTrue);
      expect(chipA.labelStyle?.color, equals(Colors.white));
      expect(chipB.selected, isTrue);
      expect(chipB.labelStyle?.color, equals(Colors.white));
      expect(chipC.selected, isFalse);
      expect(chipC.labelStyle?.color, equals(AppColors.textSecondary));
    });

    testWidgets('Switching to Tuition ACC clears previously selected divisions and displays only ACC chip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCreateTeacherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Sharda mandir and Div A, Div B
      await tester.tap(find.text('Sharda mandir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Div A'));
      await tester.tap(find.text('Div B'));
      await tester.pumpAndSettle();

      // Switch to Tuition ACC
      await tester.tap(find.text('Tuition ACC'));
      await tester.pumpAndSettle();

      // Tuition ACC is selected, Sharda mandir is not
      final shardaChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sharda mandir'));
      final accChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tuition ACC'));
      expect(shardaChip.selected, isFalse);
      expect(accChip.selected, isTrue);

      // Div A, B, C are gone
      expect(find.text('Div A'), findsNothing);
      expect(find.text('Div B'), findsNothing);
      expect(find.text('Div C'), findsNothing);

      // Only ACC chip is shown
      expect(find.text('ACC'), findsOneWidget);
      final accDivChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'ACC'));
      expect(accDivChip.selected, isFalse, reason: 'Division selection must be cleared on institution change');

      // Select ACC
      await tester.tap(find.text('ACC'));
      await tester.pumpAndSettle();

      final accDivChipSelected = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'ACC'));
      expect(accDivChipSelected.selected, isTrue);
    });

    testWidgets('Restores saved selections when editing teacher', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      final existingTeacher = AppUser(
        id: 'teacher-101',
        role: 'teacher',
        email: 'prof.sharma@school.org',
        name: 'Prof. Sharma',
        institution: 'Tuition ACC',
        academicYear: '2026-2027',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateTeacherScreen(teacher: existingTeacher),
        ),
      );
      await tester.pumpAndSettle();

      // Name & Email restored
      expect(find.text('Prof. Sharma'), findsOneWidget);
      expect(find.text('prof.sharma@school.org'), findsOneWidget);

      // Institution restored as Tuition ACC
      final accChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tuition ACC'));
      final shardaChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sharda mandir'));
      expect(accChip.selected, isTrue);
      expect(shardaChip.selected, isFalse);

      // Screen title adapts to editing
      expect(find.text('Edit Teacher & Scope'), findsOneWidget);
      expect(find.text('Update Teacher & Scope'), findsOneWidget);
    });
  });

  group('Backend Validation - Institution and Division Compatibility', () {
    test('Throws error when assigning invalid division to Sharda Mandir in createTeacher', () async {
      final service = SupabaseService();

      expect(
        () => service.createTeacher(
          name: 'Test Teacher',
          email: 'test@school.org',
          temporaryPassword: 'Password123',
          standards: ['11'],
          divisions: ['ACC'], // Invalid for Sharda Mandir
          mediums: ['English'],
          subjects: ['Physics'],
          institution: 'Sharda Mandir',
        ),
        throwsA(contains('Invalid division "ACC" for Sharda Mandir')),
      );
    });

    test('Throws error when assigning invalid division to Tuition ACC in createTeacher', () async {
      final service = SupabaseService();

      expect(
        () => service.createTeacher(
          name: 'Test Teacher',
          email: 'test@school.org',
          temporaryPassword: 'Password123',
          standards: ['11'],
          divisions: ['A'], // Invalid for Tuition ACC
          mediums: ['English'],
          subjects: ['Physics'],
          institution: 'Tuition ACC',
        ),
        throwsA(contains('Invalid division "A" for Tuition ACC')),
      );
    });

    test('Throws error when assigning invalid division to Sharda Mandir in updateTeacher', () async {
      final service = SupabaseService();

      expect(
        () => service.updateTeacher(
          teacherId: 't-123',
          name: 'Test Teacher',
          standards: ['12'],
          divisions: ['Science'], // Invalid
          mediums: ['English'],
          subjects: ['Physics'],
          institution: 'Sharda Mandir',
        ),
        throwsA(contains('Invalid division "Science" for Sharda Mandir')),
      );
    });

    test('Throws error when assigning invalid division to Tuition ACC in updateTeacher', () async {
      final service = SupabaseService();

      expect(
        () => service.updateTeacher(
          teacherId: 't-123',
          name: 'Test Teacher',
          standards: ['12'],
          divisions: ['B'], // Invalid for Tuition ACC
          mediums: ['English'],
          subjects: ['Physics'],
          institution: 'Tuition ACC',
        ),
        throwsA(contains('Invalid division "B" for Tuition ACC')),
      );
    });
  });

  group('Dynamic Academic Year & Calendar Picker', () {
    test('AcademicYearUtils generates future years beyond 2027-2028 dynamically', () {
      final years = AcademicYearUtils.getDynamicAcademicYears();
      expect(years.contains('2026-2027'), isTrue);
      expect(years.contains('2027-2028'), isTrue);
      expect(years.contains('2028-2029'), isTrue);
      expect(years.contains('2029-2030'), isTrue);
      expect(years.contains('2030-2031'), isTrue);
      expect(years.contains('2031-2032'), isTrue);
    });

    test('AcademicYearUtils formats start year correctly', () {
      expect(AcademicYearUtils.formatFromStartYear(2028), equals('2028-2029'));
      expect(AcademicYearUtils.formatFromStartYear(2032), equals('2032-2033'));
    });

    testWidgets('Academic year dropdown includes future batches and calendar picker button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCreateTeacherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Calendar button is present
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Open dropdown
      await tester.tap(find.text('2026-2027'));
      await tester.pumpAndSettle();

      // Check future batches are available in the dropdown
      expect(find.text('2027-2028').hitTestable(), findsOneWidget);
      expect(find.text('2028-2029').hitTestable(), findsOneWidget);
      expect(find.text('2029-2030').hitTestable(), findsOneWidget);
      expect(find.text('2030-2031').hitTestable(), findsOneWidget);
      expect(find.text('+ Custom Batch / Year...').hitTestable(), findsOneWidget);

      // Select 2028-2029
      await tester.tap(find.text('2028-2029').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('2028-2029'), findsOneWidget);
    });
  });
}
