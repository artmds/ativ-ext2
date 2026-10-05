import 'package:flutter_test/flutter_test.dart';

import 'package:ativ_ext2/features/home/domain/finance_models.dart';
import 'package:ativ_ext2/features/home/domain/finance_rules.dart';

void main() {
  group('FinanceRules', () {
    test('totals expenses by category and conscious classification', () {
      final expenses = [
        Expense(
          id: 'necessary',
          amount: 80,
          date: DateTime(2026, 10, 5),
          category: 'Alimentação',
          paymentMethod: 'Pix',
        ),
        Expense(
          id: 'impulse',
          amount: 20,
          date: DateTime(2026, 10, 6),
          category: 'Lazer',
          paymentMethod: 'Crédito',
          isNecessary: false,
        ),
        Expense(
          id: 'older-month',
          amount: 55,
          date: DateTime(2026, 9, 30),
          category: 'Alimentação',
          paymentMethod: 'Pix',
        ),
      ];

      expect(
        FinanceRules.totalsByCategory(
          expenses,
          month: DateTime(2026, 10),
        )['Alimentação'],
        80,
      );
      expect(
        FinanceRules.expensesByNecessity(expenses, necessary: false),
        20,
      );
      expect(
        FinanceRules.expensesByNecessity(expenses, necessary: true),
        135,
      );
    });

    test('calculates sustainable carbon estimates and monthly savings', () {
      final month = DateTime(2026, 10);
      final standardExpense = Expense(
        id: 'standard',
        amount: 50,
        date: DateTime(2026, 10, 5),
        category: 'Transporte',
        paymentMethod: 'Pix',
      );
      final sustainableExpense = Expense(
        id: 'sustainable',
        amount: 50,
        date: DateTime(2026, 10, 5),
        category: 'Transporte',
        paymentMethod: 'Pix',
        isSustainable: true,
      );
      final savings = [
        ConsciousSaving(
          id: 'current',
          amount: 25,
          description: 'Almoço em casa',
          type: 'Escolha sustentável',
          date: DateTime(2026, 10, 5),
        ),
        ConsciousSaving(
          id: 'previous',
          amount: 12,
          description: 'Compra evitada',
          type: 'Compra por impulso evitada',
          date: DateTime(2026, 9, 30),
        ),
      ];

      expect(FinanceRules.carbonKg(standardExpense), 12.5);
      expect(FinanceRules.carbonKg(sustainableExpense), 1.25);
      expect(FinanceRules.carbonInMonth([standardExpense], month), 12.5);
      expect(FinanceRules.savingsInMonth(savings, month), 25);
    });
  });
}
