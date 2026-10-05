class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.paymentMethod,
    this.note = '',
    this.isNecessary = true,
    this.isSustainable = false,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String category;
  final String paymentMethod;
  final String note;
  final bool isNecessary;
  final bool isSustainable;

  Map<String, Object> toJson() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'paymentMethod': paymentMethod,
    'note': note,
    'isNecessary': isNecessary,
    'isSustainable': isSustainable,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    category: json['category'] as String,
    paymentMethod: json['paymentMethod'] as String,
    note: json['note'] as String? ?? '',
    isNecessary: json['isNecessary'] as bool? ?? true,
    isSustainable: json['isSustainable'] as bool? ?? false,
  );
}

class PurchaseWish {
  const PurchaseWish({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;

  DateTime get availableAt => createdAt.add(const Duration(hours: 72));
  bool get isAvailable => !DateTime.now().isBefore(availableAt);

  Map<String, String> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PurchaseWish.fromJson(Map<String, dynamic> json) => PurchaseWish(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ConsciousSaving {
  const ConsciousSaving({
    required this.id,
    required this.amount,
    required this.description,
    required this.type,
    required this.date,
  });

  final String id;
  final double amount;
  final String description;
  final String type;
  final DateTime date;

  Map<String, Object> toJson() => {
    'id': id,
    'amount': amount,
    'description': description,
    'type': type,
    'date': date.toIso8601String(),
  };

  factory ConsciousSaving.fromJson(Map<String, dynamic> json) =>
      ConsciousSaving(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        type: json['type'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}

class FinanceData {
  const FinanceData({
    this.expenses = const [],
    this.wishes = const [],
    this.savings = const [],
    this.budgets = const {},
  });

  final List<Expense> expenses;
  final List<PurchaseWish> wishes;
  final List<ConsciousSaving> savings;
  final Map<String, double> budgets;
}
