import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:ativ_ext2/features/home/data/finance_repository.dart';
import 'package:ativ_ext2/features/home/domain/finance_models.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('raiz-hive-test-');
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'persists finance records to Hive between repository instances',
    () async {
      final repository = await HiveFinanceRepository.open(
        legacyReader: (_) async => null,
      );
      final expense = Expense(
        id: 'expense-1',
        amount: 45.5,
        date: DateTime(2026, 10, 5),
        category: 'Alimentação',
        paymentMethod: 'Pix',
        isNecessary: false,
      );
      final wish = PurchaseWish(
        id: 'wish-1',
        title: 'Fone',
        createdAt: DateTime(2026, 10, 1),
      );
      final saving = ConsciousSaving(
        id: 'saving-1',
        amount: 18,
        description: 'Almoço preparado em casa',
        type: 'Escolha sustentável',
        date: DateTime(2026, 10, 5),
      );

      await repository.addExpense(expense);
      await repository.addWish(wish);
      await repository.addSaving(saving);
      await repository.setBudget('Alimentação', 700);
      await Hive.close();

      Hive.init(hiveDirectory.path);
      final reopenedRepository = await HiveFinanceRepository.open();
      final data = await reopenedRepository.load();

      expect(data.expenses.single.toJson(), expense.toJson());
      expect(data.wishes.single.toJson(), wish.toJson());
      expect(data.savings.single.toJson(), saving.toJson());
      expect(data.budgets['Alimentação'], 700);
    },
  );

  test('imports existing SharedPreferences data once', () async {
    final legacyData = {
      'raiz.expenses.v1': jsonEncode([
        {
          'id': 'legacy',
          'amount': 32,
          'date': '2026-10-05T12:00:00.000',
          'category': 'Alimentação',
          'paymentMethod': 'Pix',
          'note': 'Feira',
        },
      ]),
      'raiz.budgets.v1': jsonEncode({'Alimentação': 600}),
    };

    final repository = await HiveFinanceRepository.open(
      legacyReader: (key) async => legacyData[key],
    );
    final imported = await repository.load();
    expect(imported.expenses.single.id, 'legacy');
    expect(imported.expenses.single.isNecessary, isTrue);
    expect(imported.budgets['Alimentação'], 600);

    await repository.setBudget('Alimentação', 500);
    await Hive.close();
    Hive.init(hiveDirectory.path);
    final reopenedRepository = await HiveFinanceRepository.open(
      legacyReader: (key) async => legacyData[key],
    );
    final reopened = await reopenedRepository.load();

    expect(reopened.expenses, hasLength(1));
    expect(reopened.budgets['Alimentação'], 500);
  });
}
