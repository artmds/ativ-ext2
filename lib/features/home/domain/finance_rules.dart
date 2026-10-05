import 'finance_models.dart';

const expenseCategories = <String>[
  'Alimentação',
  'Transporte',
  'Moradia',
  'Saúde',
  'Lazer',
  'Compras',
  'Outros',
];

const defaultMonthlyBudgets = <String, double>{
  'Alimentação': 900,
  'Transporte': 450,
  'Moradia': 1600,
  'Saúde': 300,
  'Lazer': 350,
  'Compras': 300,
  'Outros': 250,
};

const carbonKgPerRealByCategory = <String, double>{
  'Alimentação': 0.15,
  'Transporte': 0.25,
  'Moradia': 0.08,
  'Saúde': 0.08,
  'Lazer': 0.10,
  'Compras': 0.18,
  'Outros': 0.10,
};

class FinanceRules {
  const FinanceRules._();

  static bool isInMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  static double spentInCategory(
    Iterable<Expense> expenses,
    String category, {
    DateTime? month,
  }) => expenses
      .where(
        (expense) =>
            expense.category == category &&
            (month == null || isInMonth(expense.date, month)),
      )
      .fold(0, (total, expense) => total + expense.amount);

  static Map<String, double> totalsByCategory(
    Iterable<Expense> expenses, {
    DateTime? month,
  }) => {
    for (final category in expenseCategories)
      category: spentInCategory(expenses, category, month: month),
  };

  static double carbonKg(Expense expense) {
    return carbonEstimate(
      amount: expense.amount,
      category: expense.category,
      isSustainable: expense.isSustainable,
    );
  }

  static double carbonEstimate({
    required double amount,
    required String category,
    required bool isSustainable,
  }) {
    final factor = carbonKgPerRealByCategory[category] ?? 0.10;
    return amount * factor * (isSustainable ? 0.1 : 1);
  }

  static double carbonInMonth(
    Iterable<Expense> expenses,
    DateTime month,
  ) => expenses
      .where((expense) => isInMonth(expense.date, month))
      .fold(0, (total, expense) => total + carbonKg(expense));

  static double expensesByNecessity(
    Iterable<Expense> expenses, {
    required bool necessary,
  }) => expenses
      .where((expense) => expense.isNecessary == necessary)
      .fold(0, (total, expense) => total + expense.amount);

  static double savingsInMonth(
    Iterable<ConsciousSaving> savings,
    DateTime month,
  ) => savings
      .where((saving) => isInMonth(saving.date, month))
      .fold(0, (total, saving) => total + saving.amount);

  static double total(Iterable<double> amounts) =>
      amounts.fold(0, (sum, amount) => sum + amount);
}
