import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/finance_models.dart';
import '../domain/finance_rules.dart';

abstract interface class FinanceRepository {
  Future<FinanceData> load();
  Future<void> addExpense(Expense expense);
  Future<void> addWish(PurchaseWish wish);
  Future<void> removeWish(String id);
  Future<void> addSaving(ConsciousSaving saving);
  Future<void> removeSaving(String id);
  Future<void> setBudget(String category, double amount);
}

class HiveFinanceRepository implements FinanceRepository {
  HiveFinanceRepository._({
    required this._expensesBox,
    required this._wishesBox,
    required this._savingsBox,
    required this._budgetsBox,
    required this._settingsBox,
    required this._legacyReader,
  });

  static const _legacyMigrationKey = 'legacySharedPreferencesImported';
  static const _legacyExpensesKey = 'raiz.expenses.v1';
  static const _legacyBudgetsKey = 'raiz.budgets.v1';
  static const _legacyWishesKey = 'raiz.purchase_wishes.v1';
  static const _legacySavingsKey = 'raiz.conscious_savings.v1';

  final Box<Map> _expensesBox;
  final Box<Map> _wishesBox;
  final Box<Map> _savingsBox;
  final Box<double> _budgetsBox;
  final Box<dynamic> _settingsBox;
  final Future<String?> Function(String key) _legacyReader;

  static Future<HiveFinanceRepository> open({
    Future<String?> Function(String key)? legacyReader,
  }) async {
    final repository = HiveFinanceRepository._(
      expensesBox: await Hive.openBox<Map>('finance.expenses'),
      wishesBox: await Hive.openBox<Map>('finance.wishes'),
      savingsBox: await Hive.openBox<Map>('finance.savings'),
      budgetsBox: await Hive.openBox<double>('finance.budgets'),
      settingsBox: await Hive.openBox<dynamic>('finance.settings'),
      legacyReader: legacyReader ?? _readLegacyPreference,
    );
    await repository._migrateLegacyData();
    return repository;
  }

  @override
  Future<FinanceData> load() async {
    final expenses = _expensesBox.values
        .map((value) => Expense.fromJson(_asJsonMap(value)))
        .toList();
    final wishes = _wishesBox.values
        .map((value) => PurchaseWish.fromJson(_asJsonMap(value)))
        .toList();
    final savings = _savingsBox.values
        .map((value) => ConsciousSaving.fromJson(_asJsonMap(value)))
        .toList();
    return FinanceData(
      expenses: expenses,
      wishes: wishes,
      savings: savings,
      budgets: {
        for (final category in _budgetsBox.keys)
          category.toString(): _budgetsBox.get(category)!,
      },
    );
  }

  @override
  Future<void> addExpense(Expense expense) =>
      _expensesBox.put(expense.id, expense.toJson());

  @override
  Future<void> addWish(PurchaseWish wish) =>
      _wishesBox.put(wish.id, wish.toJson());

  @override
  Future<void> removeWish(String id) => _wishesBox.delete(id);

  @override
  Future<void> addSaving(ConsciousSaving saving) =>
      _savingsBox.put(saving.id, saving.toJson());

  @override
  Future<void> removeSaving(String id) => _savingsBox.delete(id);

  @override
  Future<void> setBudget(String category, double amount) =>
      _budgetsBox.put(category, amount);

  Future<void> _migrateLegacyData() async {
    if (_settingsBox.get(_legacyMigrationKey) == true) return;

    final expenseData = await _legacyReader(_legacyExpensesKey);
    if (expenseData != null) {
      final decoded = jsonDecode(expenseData) as List<dynamic>;
      for (final value in decoded) {
        final expense = Expense.fromJson(value as Map<String, dynamic>);
        if (!_expensesBox.containsKey(expense.id)) {
          await addExpense(expense);
        }
      }
    }

    final budgetData = await _legacyReader(_legacyBudgetsKey);
    if (budgetData != null) {
      final decoded = jsonDecode(budgetData) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (expenseCategories.contains(entry.key) &&
            !_budgetsBox.containsKey(entry.key)) {
          await setBudget(entry.key, (entry.value as num).toDouble());
        }
      }
    }

    final wishesData = await _legacyReader(_legacyWishesKey);
    if (wishesData != null) {
      final decoded = jsonDecode(wishesData) as List<dynamic>;
      for (final value in decoded) {
        final wish = PurchaseWish.fromJson(value as Map<String, dynamic>);
        if (!_wishesBox.containsKey(wish.id)) await addWish(wish);
      }
    }

    final savingsData = await _legacyReader(_legacySavingsKey);
    if (savingsData != null) {
      final decoded = jsonDecode(savingsData) as List<dynamic>;
      for (final value in decoded) {
        final saving = ConsciousSaving.fromJson(value as Map<String, dynamic>);
        if (!_savingsBox.containsKey(saving.id)) await addSaving(saving);
      }
    }

    await _settingsBox.put(_legacyMigrationKey, true);
  }

  Map<String, dynamic> _asJsonMap(Map value) =>
      Map<String, dynamic>.from(value);

  static Future<String?> _readLegacyPreference(String key) =>
      SharedPreferencesAsync().getString(key);
}

class InMemoryFinanceRepository implements FinanceRepository {
  FinanceData _data;

  InMemoryFinanceRepository({FinanceData initialData = const FinanceData()})
    : _data = initialData;

  @override
  Future<FinanceData> load() async => _data;

  @override
  Future<void> addExpense(Expense expense) async {
    _data = FinanceData(
      expenses: [expense, ..._data.expenses],
      wishes: _data.wishes,
      savings: _data.savings,
      budgets: _data.budgets,
    );
  }

  @override
  Future<void> addWish(PurchaseWish wish) async {
    _data = FinanceData(
      expenses: _data.expenses,
      wishes: [wish, ..._data.wishes],
      savings: _data.savings,
      budgets: _data.budgets,
    );
  }

  @override
  Future<void> removeWish(String id) async {
    _data = FinanceData(
      expenses: _data.expenses,
      wishes: _data.wishes.where((wish) => wish.id != id).toList(),
      savings: _data.savings,
      budgets: _data.budgets,
    );
  }

  @override
  Future<void> addSaving(ConsciousSaving saving) async {
    _data = FinanceData(
      expenses: _data.expenses,
      wishes: _data.wishes,
      savings: [saving, ..._data.savings],
      budgets: _data.budgets,
    );
  }

  @override
  Future<void> removeSaving(String id) async {
    _data = FinanceData(
      expenses: _data.expenses,
      wishes: _data.wishes,
      savings: _data.savings.where((saving) => saving.id != id).toList(),
      budgets: _data.budgets,
    );
  }

  @override
  Future<void> setBudget(String category, double amount) async {
    _data = FinanceData(
      expenses: _data.expenses,
      wishes: _data.wishes,
      savings: _data.savings,
      budgets: {..._data.budgets, category: amount},
    );
  }
}
