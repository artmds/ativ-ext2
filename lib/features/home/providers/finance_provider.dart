import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../domain/finance_models.dart';
import '../domain/finance_rules.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._repository);

  final FinanceRepository _repository;
  List<Expense> _expenses = const [];
  List<PurchaseWish> _wishes = const [];
  List<ConsciousSaving> _savings = const [];
  Map<String, double> _budgets = const {};
  bool _isLoading = true;
  Object? _loadError;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<PurchaseWish> get wishes => List.unmodifiable(_wishes);
  List<ConsciousSaving> get savings => List.unmodifiable(_savings);
  Map<String, double> get budgets => Map.unmodifiable(_budgets);
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final data = await _repository.load();
      _expenses = data.expenses;
      _wishes = data.wishes;
      _savings = data.savings;
      _budgets = {
        ...defaultMonthlyBudgets,
        ...data.budgets,
      };
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    await _repository.addExpense(expense);
    _expenses = [expense, ..._expenses];
    notifyListeners();
  }

  Future<void> addWish(PurchaseWish wish) async {
    await _repository.addWish(wish);
    _wishes = [wish, ..._wishes];
    notifyListeners();
  }

  Future<void> removeWish(String id) async {
    await _repository.removeWish(id);
    _wishes = _wishes.where((wish) => wish.id != id).toList();
    notifyListeners();
  }

  Future<void> addSaving(ConsciousSaving saving) async {
    await _repository.addSaving(saving);
    _savings = [saving, ..._savings];
    notifyListeners();
  }

  Future<void> removeSaving(String id) async {
    await _repository.removeSaving(id);
    _savings = _savings.where((saving) => saving.id != id).toList();
    notifyListeners();
  }

  Future<void> setBudget(String category, double amount) async {
    await _repository.setBudget(category, amount);
    _budgets = {..._budgets, category: amount};
    notifyListeners();
  }
}
