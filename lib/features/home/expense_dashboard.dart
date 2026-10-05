import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'domain/finance_models.dart';
import 'domain/finance_rules.dart';
import 'providers/finance_provider.dart';

const _categories = expenseCategories;

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

typedef _Expense = Expense;
typedef _PurchaseWish = PurchaseWish;
typedef _ConsciousSaving = ConsciousSaving;

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
  final _notifications = FlutterLocalNotificationsPlugin();
  int _selectedTab = 0;
  Timer? _wishRefreshTimer;

  FinanceProvider get _finance => context.read<FinanceProvider>();
  List<_Expense> get _expenses => _finance.expenses;
  List<_PurchaseWish> get _wishes => _finance.wishes;
  List<_ConsciousSaving> get _savings => _finance.savings;
  Map<String, double> get _budgets => _finance.budgets;

  @override
  void initState() {
    super.initState();
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

  double _spentInCategory(String category) =>
      FinanceRules.spentInCategory(_expenses, category, month: DateTime.now());

  double get _spentThisMonth =>
      FinanceRules.total(_expenses.where((expense) => _isCurrentMonth(expense.date)).map((expense) => expense.amount));

  double get _carbonThisMonth =>
      FinanceRules.carbonInMonth(_expenses, DateTime.now());

  double get _carbonLastMonth {
    final now = DateTime.now();
    final startOfLastMonth = DateTime(now.year, now.month - 1);
    final startOfThisMonth = DateTime(now.year, now.month);
    final lastMonth = _expenses.where(
      (expense) =>
          !expense.date.isBefore(startOfLastMonth) &&
          expense.date.isBefore(startOfThisMonth),
    );
    return FinanceRules.total(lastMonth.map(FinanceRules.carbonKg));
  }

  double get _consciousSavingsThisMonth =>
      FinanceRules.savingsInMonth(_savings, DateTime.now());

  double get _totalBudget => FinanceRules.total(_budgets.values);

  bool _isCurrentMonth(DateTime date) =>
      FinanceRules.isInMonth(date, DateTime.now());

  double _estimateCarbonKg(_Expense expense) => FinanceRules.carbonKg(expense);

  Future<bool> _addExpense(_Expense expense) async {
    final previousSpent = _spentInCategory(expense.category);
    try {
      await _finance.addExpense(expense);
    } catch (error, stackTrace) {
      debugPrint('Failed to persist expense: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível salvar o gasto.');
      return false;
    }

    final budget = _budgets[expense.category] ?? 0;
    final newSpent = previousSpent + expense.amount;
    if (budget > 0 && previousSpent < budget * .8 && newSpent >= budget * .8) {
      await _sendBudgetAlert(expense.category, reachedLimit: false);
    }
    if (budget > 0 && previousSpent < budget && newSpent >= budget) {
      await _sendBudgetAlert(expense.category, reachedLimit: true);
    }
    return true;
  }

  Future<void> _addWish(String title) async {
    final now = DateTime.now();
    final wish = _PurchaseWish(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
    );
    try {
      await _finance.addWish(wish);
    } catch (error, stackTrace) {
      debugPrint('Failed to persist purchase wish: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível salvar o desejo.');
    }
  }

  Future<void> _removeWish(_PurchaseWish wish) async {
    try {
      await _finance.removeWish(wish.id);
    } catch (error, stackTrace) {
      debugPrint('Failed to remove purchase wish: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível remover o desejo.');
    }
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

  Future<void> _showSavingForm() async {
    final saving = await showDialog<_ConsciousSaving>(
      context: context,
      builder: (_) => const _SavingEntryDialog(),
    );
    if (saving == null || !mounted) return;
    try {
      await _finance.addSaving(saving);
    } catch (error, stackTrace) {
      debugPrint('Failed to persist conscious saving: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível salvar a economia.');
    }
  }

  Future<void> _removeSaving(_ConsciousSaving saving) async {
    try {
      await _finance.removeSaving(saving.id);
    } catch (error, stackTrace) {
      debugPrint('Failed to remove conscious saving: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível remover a economia.');
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
      final saved = await _addExpense(expense);
      if (saved && wishToRegister != null) {
        await _removeWish(wishToRegister);
      }
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
    try {
      await _finance.setBudget(category, saved);
    } catch (error, stackTrace) {
      debugPrint('Failed to persist budget: $error\n$stackTrace');
      if (mounted) _showMessage('Não foi possível salvar o limite.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
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
      body: finance.isLoading
          ? const Center(child: CircularProgressIndicator())
          : finance.loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar os dados locais.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: finance.load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
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
    final expensesThisMonth = _expenses
        .where((expense) => _isCurrentMonth(expense.date))
        .toList();
    final categoryTotals = FinanceRules.totalsByCategory(
      expensesThisMonth,
      month: DateTime.now(),
    );
    final impulseTotal = FinanceRules.expensesByNecessity(
      expensesThisMonth,
      necessary: false,
    );
    final necessaryTotal = FinanceRules.expensesByNecessity(
      expensesThisMonth,
      necessary: true,
    );
    final currentExpenses = FinanceRules.total(categoryTotals.values);
    final chartColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.error,
      Colors.orange,
      Colors.blue,
      Colors.purple,
    ];
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
        _ReportChartCard(
          title: 'Gastos por Categoria',
          subtitle: 'Distribuição dos gastos deste mês',
          child: currentExpenses == 0
              ? const _ChartEmptyState()
              : Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 34,
                          sections: [
                            for (
                              var index = 0;
                              index < _categories.length;
                              index++
                            )
                              if (categoryTotals[_categories[index]]! > 0)
                                PieChartSectionData(
                                  value: categoryTotals[_categories[index]]!,
                                  color: chartColors[index],
                                  title:
                                      '${(categoryTotals[_categories[index]]! / currentExpenses * 100).round()}%',
                                  radius: 72,
                                  titleStyle: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._categories.indexed.map((entry) {
                      final (index, category) = entry;
                      final amount = categoryTotals[category]!;
                      if (amount == 0) return const SizedBox.shrink();
                      return _ChartLegendRow(
                        color: chartColors[index],
                        label: category,
                        value: _formatCurrency(amount),
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _ReportChartCard(
          title: 'Necessidade x Impulso',
          subtitle: 'Valor em reais (R\$) classificado neste mês',
          child: expensesThisMonth.isEmpty
              ? const _ChartEmptyState()
              : Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: BarChart(
                        BarChartData(
                          maxY:
                              [
                                impulseTotal,
                                necessaryTotal,
                                1,
                              ].reduce((a, b) => a > b ? a : b) *
                              1.15,
                          barGroups: [
                            _comparisonBarGroup(
                              x: 0,
                              value: impulseTotal,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            _comparisonBarGroup(
                              x: 1,
                              value: necessaryTotal,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final label = switch (value.toInt()) {
                                    0 => 'Impulso',
                                    1 => 'Necessário',
                                    _ => '',
                                  };
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _ChartLegendRow(
                      color: Theme.of(context).colorScheme.tertiary,
                      label: 'Compras por impulso',
                      value: _formatCurrency(impulseTotal),
                    ),
                    _ChartLegendRow(
                      color: Theme.of(context).colorScheme.primary,
                      label: 'Compras necessárias',
                      value: _formatCurrency(necessaryTotal),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _ReportChartCard(
          title: 'Pegada de carbono',
          subtitle: 'Estimativa em kg CO₂e: mês atual x anterior',
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY:
                        [
                          _carbonThisMonth,
                          _carbonLastMonth,
                          1,
                        ].reduce((a, b) => a > b ? a : b) *
                        1.2,
                    barGroups: [
                      _comparisonBarGroup(
                        x: 0,
                        value: _carbonLastMonth,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      _comparisonBarGroup(
                        x: 1,
                        value: _carbonThisMonth,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final label = switch (value.toInt()) {
                              0 => _shortMonthLabel(
                                DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month - 1,
                                ),
                              ),
                              1 => _shortMonthLabel(DateTime.now()),
                              _ => '',
                            };
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _ChartLegendRow(
                color: Theme.of(context).colorScheme.secondary,
                label: 'Mês anterior',
                value: '${_formatCarbon(_carbonLastMonth)} kg CO₂e',
              ),
              _ChartLegendRow(
                color: Theme.of(context).colorScheme.primary,
                label: 'Mês atual',
                value: '${_formatCarbon(_carbonThisMonth)} kg CO₂e',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildConsciousSavingsReport(),
        const SizedBox(height: 14),
        _buildPersonalizedTips(
          expensesThisMonth: expensesThisMonth,
          impulseTotal: impulseTotal,
          currentExpenses: currentExpenses,
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

  BarChartGroupData _comparisonBarGroup({
    required int x,
    required double value,
    required Color color,
  }) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: value,
        color: color,
        width: 30,
        borderRadius: BorderRadius.circular(5),
      ),
    ],
  );

  Widget _buildConsciousSavingsReport() {
    final currentMonthSavings = _savings
        .where((saving) => _isCurrentMonth(saving.date))
        .toList();
    return _ReportChartCard(
      title: 'Dinheiro economizado com consumo consciente',
      subtitle: 'Valores informados ao registrar uma economia',
      trailing: IconButton.filledTonal(
        tooltip: 'Registrar economia consciente',
        onPressed: _showSavingForm,
        icon: const Icon(Icons.add),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _formatCurrency(_consciousSavingsThisMonth),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Registre a diferença que deixou de gastar ao evitar um impulso ou escolher uma alternativa consciente. O app não presume valores que não foram informados.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (currentMonthSavings.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...currentMonthSavings
                .take(5)
                .map(
                  (saving) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      saving.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${saving.type} · ${_formatDate(saving.date)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatCurrency(saving.amount)),
                        IconButton(
                          tooltip: 'Remover economia',
                          onPressed: () => _removeSaving(saving),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalizedTips({
    required List<_Expense> expensesThisMonth,
    required double impulseTotal,
    required double currentExpenses,
  }) {
    final tips = <String>[];
    if (currentExpenses > 0) {
      final impulseShare = impulseTotal / currentExpenses;
      if (impulseShare >= 0.3) {
        tips.add(
          '${_formatPercent(impulseShare)} dos seus gastos foram classificados como compras por impulso. Antes de comprar, use a pausa de 72 horas para avaliar se o item continua importante.',
        );
      } else {
        tips.add(
          'Compras por impulso representam ${_formatPercent(impulseShare)} dos seus gastos neste mês. Continue registrando suas escolhas para acompanhar esse hábito.',
        );
      }
      final sustainableTotal = expensesThisMonth
          .where((expense) => expense.isSustainable)
          .fold<double>(0, (total, expense) => total + expense.amount);
      final sustainableShare = sustainableTotal / currentExpenses;
      if (sustainableShare < 0.25) {
        tips.add(
          'Suas escolhas marcadas como sustentáveis representam ${_formatPercent(sustainableShare)} do total. Quando possível, considere transporte público, comércio local ou produtos usados.',
        );
      } else {
        tips.add(
          '${_formatPercent(sustainableShare)} dos seus gastos foram marcados como escolhas de menor pegada. Ótimo progresso, mantenha esse hábito.',
        );
      }
    } else {
      tips.add(
        'Registre seus gastos para receber dicas baseadas nas categorias, escolhas e hábitos deste mês.',
      );
    }

    final categoryWithHighestBudgetUsage =
        _categories
            .map((category) {
              final spent = expensesThisMonth
                  .where((expense) => expense.category == category)
                  .fold<double>(0, (total, expense) => total + expense.amount);
              final budget = _budgets[category] ?? 0;
              return (
                category: category,
                spent: spent,
                ratio: budget <= 0 ? 0.0 : spent / budget,
              );
            })
            .where((entry) => entry.spent > 0)
            .toList()
          ..sort((a, b) => b.ratio.compareTo(a.ratio));
    if (categoryWithHighestBudgetUsage.isNotEmpty) {
      final topCategory = categoryWithHighestBudgetUsage.first;
      if (topCategory.ratio >= 0.8) {
        tips.add(
          topCategory.category == 'Alimentação'
              ? 'Você já usou ${_formatPercent(topCategory.ratio)} do limite de alimentação. Planejar as refeições da semana pode ajudar a reduzir gastos com refeições fora de casa.'
              : 'Você já usou ${_formatPercent(topCategory.ratio)} do limite de ${topCategory.category.toLowerCase()}. Revise os próximos gastos dessa categoria para fechar o mês dentro do orçamento.',
        );
      }
    }

    return _ReportChartCard(
      title: 'Dicas para seus hábitos',
      subtitle: 'Recomendações calculadas com seus lançamentos deste mês',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
        ],
      ),
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
                          final estimate = FinanceRules.carbonEstimate(
                            amount: amount,
                            category: _category,
                            isSustainable: _isSustainable,
                          );
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

class _SavingEntryDialog extends StatefulWidget {
  const _SavingEntryDialog();

  @override
  State<_SavingEntryDialog> createState() => _SavingEntryDialogState();
}

class _SavingEntryDialogState extends State<_SavingEntryDialog> {
  static const _savingTypes = [
    'Compra por impulso evitada',
    'Escolha sustentável',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = _savingTypes.first;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      _ConsciousSaving(
        id: now.microsecondsSinceEpoch.toString(),
        amount: _parseAmount(_amountController.text)!,
        description: _descriptionController.text.trim(),
        type: _type,
        date: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar economia'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo de economia'),
            items: _savingTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quanto você economizou?',
              prefixText: 'R\$ ',
            ),
            validator: (value) {
              final amount = _parseAmount(value ?? '');
              if (amount == null || amount <= 0) {
                return 'Informe um valor maior que zero.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Como você economizou?',
              hintText: 'Ex.: preparei o almoço em casa',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Descreva a escolha consciente.'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salvar economia')),
    ],
  );
}

class _ReportChartCard extends StatelessWidget {
  const _ReportChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(
      'Ainda não há gastos neste mês para comparar.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

class _ChartLegendRow extends StatelessWidget {
  const _ChartLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
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

String _formatPercent(double ratio) =>
    '${(ratio * 100).round().clamp(0, 999)}%';

String _shortMonthLabel(DateTime date) {
  const months = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
  return months[date.month - 1];
}

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
