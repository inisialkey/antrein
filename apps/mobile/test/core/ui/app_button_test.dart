import 'package:antrein/core/theme/app_theme.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: the button theme used Size.fromHeight, which pins the *minimum
  // width* to infinity. A Row hands non-flex children unbounded main-axis
  // constraints, so every inline button asserted "forces an infinite width".
  testWidgets('a non-expanded button lays out inside a Row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Haircut')),
              AppButton(label: 'Book', expanded: false, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).width.isFinite, isTrue);
  });

  testWidgets('an expanded button still fills its parent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AppButton(label: 'Confirm', onPressed: () {}),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(FilledButton)).width, 300);
  });
}
