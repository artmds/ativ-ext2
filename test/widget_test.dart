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

  testWidgets('classifies an expense and shows its carbon estimate', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo gasto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '50,00');
    await tester.ensureVisible(find.byType(SwitchListTile).at(1));
    await tester.tap(find.byType(SwitchListTile).at(1));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(1)).value,
      isTrue,
    );
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extrato'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Menor pegada'), findsWidgets);
    expect(find.textContaining('0,75 kg CO₂e'), findsWidgets);
  });

  testWidgets('starts a 72-hour timer for a purchase wish', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desafios'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Fone novo');
    await tester.tap(find.text('Iniciar 72 horas'));
    await tester.pumpAndSettle();

    expect(find.text('Fone novo'), findsOneWidget);
    expect(find.textContaining('Disponível em'), findsOneWidget);
    expect(find.text('Registrar como gasto'), findsNothing);
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
