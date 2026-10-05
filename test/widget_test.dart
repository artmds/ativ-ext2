import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ativ_ext2/main.dart';

void main() {
  testWidgets('shows the conscious spending dashboard', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Gastos no mês'), findsOneWidget);
    expect(find.text('Limites por categoria'), findsOneWidget);
    expect(find.text('Novo gasto'), findsOneWidget);
  });

  testWidgets('registers a new expense', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo gasto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '20,00');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();

    expect(find.text('Alimentação'), findsWidgets);
    expect(find.textContaining('20,00'), findsWidgets);
  });

  testWidgets('alerts when an expense crosses both budget thresholds', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final foodCategory = find.text('Alimentação').first;
    await tester.ensureVisible(foodCategory);
    await tester.tap(foodCategory);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10,00');
    await tester.tap(find.text('Salvar limite'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '20,00');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('20,00'), findsWidgets);
    expect(find.text('Limite atingido'), findsOneWidget);
  });
}
