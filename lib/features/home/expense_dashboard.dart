import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _categories = <String>[
  'Alimentação',
  'Transporte',
  'Moradia',
  'Saúde',
  'Lazer',
  'Compras',
  'Outros',
];

const _categoryIcons = <String, IconData>{
  'Alimentação': Icons.restaurant_outlined,
  'Transporte': Icons.directions_bus_outlined,
  'Moradia': Icons.home_outlined,
  'Saúde': Icons.health_and_safety_outlined,
  'Lazer': Icons.theater_comedy_outlined,
  'Compras': Icons.shopping_bag_outlined,
  'Outros': Icons.more_horiz,
};

const _paymentMethods = <String>[
  'Pix',
  'Débito',
  'Crédito',
  'Dinheiro',
  'Transferência',
];

const _carbonKgPerRealByCategory = <String, double>{
  'Alimentação': 0.15,
  'Transporte': 0.25,
  'Moradia': 0.08,
  'Saúde': 0.08,
  'Lazer': 0.10,
  'Compras': 0.18,
  'Outros': 0.10,
};

const _defaultBudgets = <String, double>{
  'Alimentação': 900,
  'Transporte': 450,
  'Moradia': 1600,
  'Saúde': 300,
  'Lazer': 350,
  'Compras': 300,
  'Outros': 250,
};

class _Expense {
  const _Expense({
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

  factory _Expense.fromJson(Map<String, dynamic> json) => _Expense(
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

class _PurchaseWish {
  const _PurchaseWish({
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

  factory _PurchaseWish.fromJson(Map<String, dynamic> json) => _PurchaseWish(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ExpenseDashboard extends StatefulWidget {
  const ExpenseDashboard({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<ExpenseDashboard> createState() => _ExpenseDashboardState();
}

class _ExpenseDashboardState extends State<ExpenseDashboard> {
  static const _expensesKey = 'raiz.expenses.v1';
  static const _budgetsKey = 'raiz.budgets.v1';
  static const _wishesKey = 'raiz.purchase_wishes.v1';

  final _notifications = FlutterLocalNotificationsPlugin();
  final Map<String, double> _budgets = Map.of(_defaultBudgets);
  List<_Expense> _expenses = [];
  List<_PurchaseWish> _wishes = [];
  int _selectedTab = 0;
  bool _loading = true;
  Timer? _wishRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeNotifications();
    _wishRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _selectedTab == 3) setState(() {});
    });
  }

  @override
  void dispose() {
    _wishRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final preferences = SharedPreferencesAsync();
      final expensesJson = await preferences.getString(_expensesKey);
      final budgetsJson = await preferences.getString(_budgetsKey);
      final wishesJson = await preferences.getString(_wishesKey);
      if (expensesJson != null) {
        final decoded = jsonDecode(expensesJson) as List<dynamic>;
        _expenses = decoded
            .map((item) => _Expense.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      if (budgetsJson != null) {
        final decoded = jsonDecode(budgetsJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (_categories.contains(entry.key)) {
            _budgets[entry.key] = (entry.value as num).toDouble();
          }
        }
      }
      if (wishesJson != null) {
        final decoded = jsonDecode(wishesJson) as List<dynamic>;
        _wishes = decoded
            .map((item) => _PurchaseWish.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Storage may be unavailable in preview or test environments.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _initializeNotifications() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return;
    }
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } catch (_) {
      // The app remains usable when notifications are unavailable.
    }
  }

  Future<void> _persistData() async {
    try {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        _expensesKey,
        jsonEncode(_expenses.map((expense) => expense.toJson()).toList()),
      );
      await preferences.setString(_budgetsKey, jsonEncode(_budgets));
      await preferences.setString(
        _wishesKey,
        jsonEncode(_wishes.map((wish) => wish.toJson()).toList()),
      );
    } catch (_) {
      if (mounted) _showMessage('Não foi possível salvar neste dispositivo.');
    }
  }

  double _spentInCategory(String category) => _expenses
      .where(
        (expense) =>
            expense.category == category && _isCurrentMonth(expense.date),
      )
      .fold(0, (total, expense) => total + expense.amount);

  double get _spentThisMonth => _expenses
      .where((expense) => _isCurrentMonth(expense.date))
      .fold(0, (total, expense) => total + expense.amount);

  double get _carbonThisMonth => _expenses
      .where((expense) => _isCurrentMonth(expense.date))
      .fold(0, (total, expense) => total + _estimateCarbonKg(expense));

  double get _totalBudget =>
      _budgets.values.fold(0, (total, value) => total + value);

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  double _estimateCarbonKg(_Expense expense) {
    final factor = _carbonKgPerRealByCategory[expense.category] ?? 0.10;
    return expense.amount * factor * (expense.isSustainable ? 0.1 : 1);
  }

  Future<void> _addExpense(_Expense expense) async {
    final previousSpent = _spentInCategory(expense.category);
    setState(() => _expenses = [expense, ..._expenses]);
    await _persistData();

    final budget = _budgets[expense.category] ?? 0;
    final newSpent = previousSpent + expense.amount;
    if (budget > 0 && previousSpent < budget * .8 && newSpent >= budget * .8) {
      await _sendBudgetAlert(expense.category, reachedLimit: false);
    }
    if (budget > 0 && previousSpent < budget && newSpent >= budget) {
      await _sendBudgetAlert(expense.category, reachedLimit: true);
    }
  }

  Future<void> _addWish(String title) async {
    final now = DateTime.now();
    final wish = _PurchaseWish(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
    );
    setState(() => _wishes = [wish, ..._wishes]);
    await _persistData();
  }

  Future<void> _removeWish(_PurchaseWish wish) async {
    setState(() => _wishes.removeWhere((item) => item.id == wish.id));
    await _persistData();
  }

  Future<void> _showWishForm() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _WishEntryDialog(),
    );
    if (title != null && title.trim().isNotEmpty) {
      await _addWish(title.trim());
    }
  }

  Future<void> _showExpenseForm({
    String? initialNote,
    _PurchaseWish? wishToRegister,
  }) async {
    if (wishToRegister != null && !wishToRegister.isAvailable) return;
    final expense = await showModalBottomSheet<_Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ExpenseForm(initialNote: initialNote),
    );
    if (expense != null) {
      await _addExpense(expense);
      if (wishToRegister != null) await _removeWish(wishToRegister);
    }
  }

  Future<void> _sendBudgetAlert(
    String category, {
    required bool reachedLimit,
  }) async {
    final title = reachedLimit
        ? 'Limite mensal atingido'
        : 'Orçamento em atenção';
    final message = reachedLimit
        ? 'Você atingiu o limite de ${_formatCurrency(_budgets[category]!)} em $category.'
        : 'Você já usou 80% do orçamento de $category.';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } catch (_) {}
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}
    }

    try {
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: message,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'budget_alerts',
            'Alertas de orçamento',
            channelDescription: 'Avisos ao se aproximar do limite mensal.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
    if (mounted) _showMessage('$title: $category');
  }

  Future<void> _editBudget(String category) async {
    final saved = await showDialog<double>(
      context: context,
      builder: (_) => _BudgetEditorDialog(
        category: category,
        initialAmount: _budgets[category] ?? 0,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _budgets[category] = saved);
    await _persistData();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      _buildStatement(),
      _buildReports(),
      _buildTips(),
    ];
    final titles = [
      'Visão geral',
      'Lançamentos',
      'Relatórios & impacto',
      'Desafios',
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(
              Icons.eco_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Text(
              titles[_selectedTab],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Ativar tema claro'
                : 'Ativar tema escuro',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _selectedTab, children: pages),
      floatingActionButton: _selectedTab < 2
          ? FloatingActionButton.extended(
              onPressed: _showExpenseForm,
              icon: const Icon(Icons.add),
              label: const Text('Novo gasto'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Extrato',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Relatórios',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Desafios',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final remaining = (_totalBudget - _spentThisMonth)
        .clamp(0, double.infinity)
        .toDouble();
    final progress = _totalBudget == 0
        ? 0.0
        : (_spentThisMonth / _totalBudget).clamp(0.0, 1.0);
    final sortedExpenses = [..._expenses]
      ..sort((a, b) => b.date.compareTo(a.date));
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Text(
          _monthLabel(DateTime.now()),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricPanel(
                label: 'Gastos no mês',
                value: _formatCurrency(_spentThisMonth),
                icon: Icons.south_west,
                tint: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricPanel(
                label: 'Ainda disponível',
                value: _formatCurrency(remaining),
                icon: Icons.savings_outlined,
                tint: colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    progress >= .9
                        ? Icons.park_outlined
                        : Icons.forest_outlined,
                    size: 34,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress >= 1
                            ? 'Hora de rever os limites'
                            : 'Seu mês está criando raízes',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(progress * 100).round()}% do orçamento mensal utilizado',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(6),
                        color: progress >= .8
                            ? colorScheme.secondary
                            : colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
        _SectionHeading(
          title: 'Limites por categoria',
          actionLabel: 'Editar',
          onAction: () => setState(() => _selectedTab = 2),
        ),
        const SizedBox(height: 4),
        ..._categories.map(
          (category) => _BudgetRow(
            category: category,
            spent: _spentInCategory(category),
            budget: _budgets[category] ?? 0,
            onTap: () => _editBudget(category),
          ),
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: 'Últimos lançamentos',
          actionLabel: 'Ver todos',
          onAction: () => setState(() => _selectedTab = 1),
        ),
        const SizedBox(height: 4),
        if (sortedExpenses.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Seu diário começa aqui',
            message:
                'Registre um gasto para acompanhar seus hábitos neste mês.',
          )
        else
          ...sortedExpenses.take(4).map(_expenseTile),
      ],
    );
  }

  Widget _buildStatement() {
    final expenses = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    if (expenses.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhum lançamento ainda',
        message: 'Toque em Novo gasto para registrar sua primeira despesa.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Text(
          '${expenses.length} ${expenses.length == 1 ? 'lançamento' : 'lançamentos'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        ...expenses.map(_expenseTile),
      ],
    );
  }

  Widget _buildReports() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Text(
          'Acompanhamento mensal',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          'Compare seus gastos com os limites definidos.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _ReportTotal(
                    label: 'Gasto no mês',
                    value: _formatCurrency(_spentThisMonth),
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: _ReportTotal(
                    label: 'Limite total',
                    value: _formatCurrency(_totalBudget),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.co2_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pegada estimada no mês',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_formatCarbon(_carbonThisMonth)} kg CO₂e',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimativa educativa por categoria e valor. Compras marcadas com menor pegada recebem uma redução; o resultado não substitui dados reais de produtos ou deslocamentos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ..._categories.map(
          (category) => _BudgetRow(
            category: category,
            spent: _spentInCategory(category),
            budget: _budgets[category] ?? 0,
            onTap: () => _editBudget(category),
          ),
        ),
      ],
    );
  }

  Widget _buildTips() {
    final mostUsed = _categories
        .map((category) => MapEntry(category, _spentInCategory(category)))
        .reduce((a, b) => a.value >= b.value ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Pequenas escolhas,',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'impacto que cresce.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_outlined),
                const SizedBox(height: 16),
                Text(
                  'Desafio da semana',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Anote um desejo e espere 72 horas. Se ainda fizer sentido, você poderá registrá-lo como gasto.',
                ),
                const SizedBox(height: 18),
                Text(
                  'ODS 12 · Consumo e produção responsáveis',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Desejos de compra',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showWishForm,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_wishes.isEmpty)
          const _EmptyState(
            icon: Icons.hourglass_empty,
            title: 'Nenhum desejo por enquanto',
            message: 'Registre um item supérfluo para começar a contagem de 72 horas.',
          )
        else
          ..._wishes.map(_wishCard),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(height: 12),
                Text(
                  'Uma dica para hoje',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  mostUsed.value == 0
                      ? 'Planejar as compras da semana ajuda a evitar desperdício de alimentos e dinheiro.'
                      : 'Sua maior categoria neste mês é ${mostUsed.key.toLowerCase()}. Planejar antes de gastar ajuda a consumir com intenção.',
                ),
                const SizedBox(height: 12),
                Text(
                  'ODS 13 · Ação contra a mudança global do clima',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _wishCard(_PurchaseWish wish) {
    final remaining = wish.availableAt.difference(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_bottom),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    wish.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover desejo',
                  onPressed: () => _removeWish(wish),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (wish.isAvailable)
              FilledButton.icon(
                onPressed: () => _showExpenseForm(
                  initialNote: wish.title,
                  wishToRegister: wish,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Registrar como gasto'),
              )
            else
              Text(
                'Disponível em ${_formatRemaining(remaining)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(_Expense expense) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: .12),
        child: Icon(
          _categoryIcons[expense.category] ?? Icons.more_horiz,
          color: Theme.of(context).colorScheme.primary,
          size: 21,
        ),
      ),
      title: Text(
        expense.note.isEmpty ? expense.category : expense.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${expense.category} · ${_formatDate(expense.date)} · ${expense.paymentMethod}\n'
        '${expense.isNecessary ? 'Necessária' : 'Compra por impulso'} · '
        '${expense.isSustainable ? 'Menor pegada' : 'Pegada padrão'} · '
        '${_formatCarbon(_estimateCarbonKg(expense))} kg CO₂e',
      ),
      trailing: Text(
        _formatCurrency(expense.amount),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({this.initialNote});

  final String? initialNote;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = _categories.first;
  String _paymentMethod = _paymentMethods.first;
  DateTime _date = DateTime.now();
  bool _isNecessary = true;
  bool _isSustainable = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.initialNote ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _Expense(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: _parseAmount(_amountController.text)!,
        date: _date,
        category: _category,
        paymentMethod: _paymentMethod,
        note: _noteController.text.trim(),
        isNecessary: _isNecessary,
        isSustainable: _isSustainable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxFormHeight = (MediaQuery.sizeOf(context).height - bottomInset - 64)
        .clamp(0.0, MediaQuery.sizeOf(context).height);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxFormHeight),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Novo gasto',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          prefixText: 'R\$ ',
                          hintText: '0,00',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final amount = _parseAmount(value ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Informe um valor maior que zero.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: _categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value ?? _category),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                        ),
                        items: _paymentMethods
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _paymentMethod = value ?? _paymentMethod,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Data: ${_formatDate(_date)}'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descrição (opcional)',
                          hintText: 'Ex.: feira da semana',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Essa compra era realmente necessária?',
                        ),
                        subtitle: const Text(
                          'Desative se foi uma compra por impulso.',
                        ),
                        value: _isNecessary,
                        onChanged: (value) =>
                            setState(() => _isNecessary = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Possui selo/origem sustentável ou menor pegada?',
                        ),
                        subtitle: const Text(
                          'Ex.: transporte público, bicicleta, mercado local ou item usado.',
                        ),
                        value: _isSustainable,
                        onChanged: (value) =>
                            setState(() => _isSustainable = value),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final amount =
                              _parseAmount(_amountController.text) ?? 0;
                          final factor =
                              _carbonKgPerRealByCategory[_category] ?? 0.10;
                          final estimate =
                              amount * factor * (_isSustainable ? 0.1 : 1);
                          return Text(
                            'Pegada estimada: ${_formatCarbon(estimate)} kg CO₂e\n'
                            'Estimativa educativa por categoria e valor.',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Salvar lançamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishEntryDialog extends StatefulWidget {
  const _WishEntryDialog();

  @override
  State<_WishEntryDialog> createState() => _WishEntryDialogState();
}

class _WishEntryDialogState extends State<_WishEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Novo desejo de compra'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'O que você quer comprar?',
          hintText: 'Ex.: um fone novo',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Informe o item desejado.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Iniciar 72 horas'),
      ),
    ],
  );
}

class _BudgetEditorDialog extends StatefulWidget {
  const _BudgetEditorDialog({
    required this.category,
    required this.initialAmount,
  });

  final String category;
  final double initialAmount;

  @override
  State<_BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<_BudgetEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Limite de ${widget.category}'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Orçamento mensal',
          prefixText: 'R\$ ',
        ),
        validator: (value) {
          final amount = _parseAmount(value ?? '');
          if (amount == null || amount <= 0) return 'Informe um valor válido.';
          return null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _parseAmount(_controller.text));
          }
        },
        child: const Text('Salvar limite'),
      ),
    ],
  );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.category,
    required this.spent,
    required this.budget,
    required this.onTap,
  });

  final String category;
  final double spent;
  final double budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;
    final color = ratio >= 1
        ? colorScheme.error
        : ratio >= .8
        ? colorScheme.secondary
        : colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcons[category] ?? Icons.more_horiz,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${_formatCurrency(spent)} / ${_formatCurrency(budget)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(5),
              color: color,
            ),
            if (ratio >= .8)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ratio >= 1
                        ? 'Limite atingido'
                        : 'Atenção: mais de 80% do limite',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}

class _ReportTotal extends StatelessWidget {
  const _ReportTotal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 6),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

double? _parseAmount(String input) {
  var normalized = input.trim().replaceAll(' ', '');
  final comma = normalized.lastIndexOf(',');
  final period = normalized.lastIndexOf('.');
  if (comma >= 0 && period >= 0) {
    normalized = comma > period
        ? normalized.replaceAll('.', '').replaceAll(',', '.')
        : normalized.replaceAll(',', '');
  } else if (comma >= 0) {
    normalized = normalized.replaceAll(',', '.');
  } else if (period >= 0 && normalized.length - period - 1 == 3) {
    normalized = normalized.replaceAll('.', '');
  }
  return double.tryParse(normalized);
}

String _formatCarbon(double kg) => kg.toStringAsFixed(2).replaceAll('.', ',');

String _formatRemaining(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}min';
}

String _formatCurrency(double amount) =>
    'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _monthLabel(DateTime date) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${months[date.month - 1]} de ${date.year}';
}
