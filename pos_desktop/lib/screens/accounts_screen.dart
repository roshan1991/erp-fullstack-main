import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/pos_provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/virtual_keyboard.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Row(
          children: [
            const Sidebar(activePage: 'Accounts'),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF2A2A3C),
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Daily Summary'),
                        Tab(text: 'Expenses'),
                        Tab(text: 'Monthly Report'),
                      ],
                      indicatorColor: Color(0xFF0882C8),
                      labelColor: Color(0xFF0882C8),
                      unselectedLabelColor: Colors.white70,
                    ),
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        DailyAccountsTab(),
                        ExpensesTab(),
                        MonthlyReportTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DAILY ACCOUNTS TAB ---
class DailyAccountsTab extends StatefulWidget {
  const DailyAccountsTab({Key? key}) : super(key: key);

  @override
  _DailyAccountsTabState createState() => _DailyAccountsTabState();
}

class _DailyAccountsTabState extends State<DailyAccountsTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    Future.microtask(() =>
        Provider.of<PosProvider>(context, listen: false).fetchDailySummary(_selectedDate));
  }

  void _moveDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final summary = provider.dailySummary;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildDateNavigator(),
          const SizedBox(height: 24),
          if (summary == null)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView(
                children: [
                  _buildKPIGrid(summary),
                  const SizedBox(height: 24),
                  _buildStatsRow(summary),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Expenses Today'),
                  _buildExpenseChips(summary),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopProducts(summary)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildTransactionsList(provider)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moveDate(-1)),
        const SizedBox(width: 16),
        Text(
          DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _moveDate(1)),
      ],
    );
  }

  Widget _buildKPIGrid(Map<String, dynamic> s) {
    final rev = s['revenue']['total'];
    final gross = s['gross_profit'];
    final exp = s['expenses']['total'];
    final net = s['net_profit'];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildKPICard('Revenue', rev, Colors.blue),
        _buildKPICard('Gross Profit', gross, Colors.orange),
        _buildKPICard('Expenses', exp, Colors.red),
        _buildKPICard('Net Profit', net, net >= 0 ? Colors.green : Colors.red, isNet: true),
      ],
    );
  }

  Widget _buildKPICard(String title, dynamic amount, Color color, {bool isNet = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNet ? color.withOpacity(0.2) : const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(16),
        border: isNet ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'LKR ${(amount as num).toDouble().toStringAsFixed(2)}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildCompactStat('Transactions', s['transaction_count'].toString()),
        _buildCompactStat('Avg Sale', 'LKR ${(s['avg_sale_value'] as num).toDouble().toStringAsFixed(2)}'),
        _buildCompactStat('Cash', 'LKR ${(s['revenue']['cash'] as num).toDouble().toStringAsFixed(2)}'),
        _buildCompactStat('Card', 'LKR ${(s['revenue']['card'] as num).toDouble().toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildCompactStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildExpenseChips(Map<String, dynamic> s) {
    final List cats = s['expenses']['by_category'] ?? [];
    if (cats.isEmpty) return const Text('No expenses recorded today.', style: TextStyle(color: Colors.grey));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cats.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Chip(
            label: Text('${c['category']}: LKR ${(c['amount'] as num).toDouble().toStringAsFixed(2)}'),
            backgroundColor: const Color(0xFF2A2A3C),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTopProducts(Map<String, dynamic> s) {
    final List items = s['top_products'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Top Products'),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(16)),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                title: Text(item['name'] ?? 'Unknown'),
                subtitle: Text('Revenue: LKR ${(item['revenue'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}'),
                trailing: Chip(label: Text('${(item['qty'] as num?)?.toInt() ?? 0} sold')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(PosProvider provider) {
    // We need to fetch all transactions for the day
    // For simplicity, we can reuse the daily summary if we add a transactions list to it
    // But the user said "Section All Transactions: List of all transactions for the day"
    // So let's fetch them
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('All Transactions'),
        FutureBuilder<List<dynamic>>(
          future: provider.getTransactionsForDay(_selectedDate),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final txs = snapshot.data!;
            return Container(
              height: 400,
              decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(16)),
              child: ListView.separated(
                itemCount: txs.length,
                separatorBuilder: (ctx, i) => Divider(color: Colors.white10, height: 1),
                itemBuilder: (ctx, i) {
                  final tx = txs[i];
                  final isIncome = tx['type'] == 'income';
                  final time = tx['created_at'] != null ? tx['created_at'].split(' ')[1].substring(0, 5) : '--:--';
                  return ListTile(
                    leading: Text(time, style: const TextStyle(color: Colors.grey)),
                    title: Text('${tx['category']} - ${tx['description'] ?? "No desc"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LKR ${(tx['amount'] as num).toDouble().toStringAsFixed(2)}',
                          style: TextStyle(color: isIncome ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        if (tx['reference_type'] != 'sale')
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.grey),
                            onPressed: () => _confirmDelete(ctx, tx['id']),
                          )
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<PosProvider>(context, listen: false).deleteTransaction(id);
              Navigator.pop(ctx);
              _fetch();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- EXPENSES TAB ---
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({Key? key}) : super(key: key);

  @override
  _ExpensesTabState createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  String? _selectedCategory;
  String _paymentMethod = 'Cash';
  bool _categorizing = false;
  
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<PosProvider>(context, listen: false).fetchExpenseCategories());
  }

  void _saveExpense() async {
    if (_selectedCategory == null || _amountController.text.isEmpty) return;
    
    final data = {
      'type': 'expense',
      'category': _selectedCategory,
      'description': _descController.text,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'date': DateFormat('yyyy-MM-dd').format(_expenseDate),
      'payment_method': _paymentMethod.toUpperCase(),
    };

    final success = await Provider.of<PosProvider>(context, listen: false).addExpense(data);
    if (success) {
      _descController.clear();
      _amountController.clear();
      setState(() {
        _selectedCategory = null;
        _expenseDate = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);

    return Column(
      children: [
        _buildForm(provider),
        _buildFilters(),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: provider.getTransactionsFiltered(
              from: _fromDate,
              to: _toDate,
              type: 'expense',
            ),
            builder: (context, snapshot) {
              final txs = snapshot.data ?? [];
              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: txs.length,
                      separatorBuilder: (ctx, i) => Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, i) {
                        final tx = txs[i];
                        return ListTile(
                          leading: Text(tx['date'] ?? '', style: const TextStyle(color: Colors.grey)),
                          title: Text(tx['category'] ?? ''),
                          subtitle: Text(tx['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'LKR ${(tx['amount'] as num).toDouble().toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.grey),
                                onPressed: () {
                                  provider.deleteTransaction(tx['id']);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _buildFooter(txs),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForm(PosProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF2A2A3C).withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Record New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  value: _selectedCategory,
                  items: provider.expenseCategories
                      .where((c) => c['type'] == 'expense')
                      .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['name'], child: Text(c['name'])))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _descController,
                  readOnly: provider.useOnScreenKeyboard,
                  onTap: () => provider.useOnScreenKeyboard ? _showKeyboard(_descController) : null,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: const OutlineInputBorder(),
                    suffixIcon: _categorizing
                        ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFD2042D))))
                        : IconButton(
                            icon: const Icon(Icons.auto_awesome, color: const Color(0xFFD2042D), size: 20),
                            onPressed: () async {
                              final desc = _descController.text.trim();
                              if (desc.isEmpty) return;
                              setState(() => _categorizing = true);
                              final cat = await provider.categorizeExpense(desc);
                              setState(() {
                                _selectedCategory = cat.isNotEmpty ? cat : _selectedCategory;
                                _categorizing = false;
                              });
                            },
                            tooltip: 'Elais Magic: Auto-categorize',
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  readOnly: provider.useOnScreenKeyboard,
                  onTap: () => provider.useOnScreenKeyboard ? _showKeyboard(_amountController, numeric: true) : null,
                  decoration: const InputDecoration(labelText: 'Amount (LKR)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDatePickerBtn('Date: ${DateFormat('yyyy-MM-dd').format(_expenseDate)}', () async {
                final d = await showDatePicker(context: context, initialDate: _expenseDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => _expenseDate = d);
              }),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _paymentMethod,
                items: ['Cash', 'Card', 'Transfer', 'Other'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0882C8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20)),
                child: const Text('Save Expense'),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Colors.grey),
          const SizedBox(width: 16),
          _buildDatePickerBtn(DateFormat('yyyy-MM-dd').format(_fromDate), () async {
            final d = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _fromDate = d);
          }),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
          _buildDatePickerBtn(DateFormat('yyyy-MM-dd').format(_toDate), () async {
            final d = await showDatePicker(context: context, initialDate: _toDate, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _toDate = d);
          }),
          const SizedBox(width: 24),
          // Category filter...
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('Clear Filters')),
        ],
      ),
    );
  }

  Widget _buildHistory(PosProvider provider) {
    return const SizedBox.shrink(); // Integrated into build() via FutureBuilder
  }

  Widget _buildFooter(List<dynamic> txs) {
    final total = txs.fold<double>(
      0.0, (sum, tx) => sum + ((tx['amount'] as num).toDouble())
    );
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2A2A3C),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Total Expenses: ', style: TextStyle(color: Colors.grey)),
          Text(
            'LKR ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
        child: Text(label),
      ),
    );
  }

  void _showKeyboard(TextEditingController controller, {bool numeric = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VirtualKeyboard(
        controller: controller,
        onClosed: () => Navigator.pop(context),
      ),
    );
  }
}

// --- MONTHLY REPORT TAB ---
class MonthlyReportTab extends StatefulWidget {
  const MonthlyReportTab({Key? key}) : super(key: key);

  @override
  _MonthlyReportTabState createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<MonthlyReportTab> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String? _elaisNarrative;
  bool _loadingNarrative = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    Future.microtask(() =>
        Provider.of<PosProvider>(context, listen: false).fetchMonthlyReport(_year, _month));
    setState(() => _elaisNarrative = null);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      if (_month < 1) { _month = 12; _year--; }
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final report = provider.monthlyReport;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildMonthNavigator(),
          const SizedBox(height: 24),
          if (report == null)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView(
                children: [
                  _buildPLCard(report),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildWeeklyTable(report)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildExpenseBreakdown(report)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                  if (_loadingNarrative)
                    const Center(child: CircularProgressIndicator(color: const Color(0xFFD2042D)))
                  else if (_elaisNarrative != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2042D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD2042D).withOpacity(0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome, color: const Color(0xFFD2042D), size: 20),
                          SizedBox(width: 8),
                          Text('Elais Analysis', style: TextStyle(color: const Color(0xFFD2042D), fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                        const SizedBox(height: 12),
                        Text(_elaisNarrative!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
                      ]),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Get Elais AI Summary'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD2042D),
                          side: const BorderSide(color: const Color(0xFFD2042D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          setState(() => _loadingNarrative = true);
                          final res = await provider.getMonthlyNarrative(_year, _month);
                          setState(() {
                            _elaisNarrative = res;
                            _loadingNarrative = false;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 32),
                  _buildTopProducts(report),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _exportPdf(report),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text(
                        'Export Monthly PDF Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0882C8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moveMonth(-1)),
        const SizedBox(width: 16),
        Text(
          '${_monthName(_month)} $_year',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _moveMonth(1)),
      ],
    );
  }

  String _monthName(int m) {
    return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][m - 1];
  }

  Widget _buildPLCard(Map<String, dynamic> r) {
    final net = r['net_profit'];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPLItem('Total Revenue', r['revenue']['total'], Colors.blue),
              _buildPLItem('COGS', r['cogs'], Colors.orange),
              _buildPLItem('Gross Profit', r['gross_profit'], Colors.orangeAccent),
              _buildPLItem('Gross Margin %', r['gross_margin_pct'], Colors.grey, isPct: true),
              _buildPLItem('Expenses', r['expenses']['total'], Colors.redAccent),
            ],
          ),
          const Divider(height: 48, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NET PROFIT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(
                'LKR ${(net as num).toDouble().toStringAsFixed(2)}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: net >= 0 ? Colors.greenAccent : Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPLItem(String label, dynamic val, Color color, {bool isPct = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          isPct ? '${(val as num).toDouble().toStringAsFixed(1)}%' : 'LKR ${(val as num).toDouble().toStringAsFixed(0)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildWeeklyTable(Map<String, dynamic> r) {
    final List weeks = r['revenue']['by_week'] ?? [];
    return _buildSectionBox('Weekly Revenue', 
      DataTable(
        columns: const [
          DataColumn(label: Text('Week')),
          DataColumn(label: Text('Revenue')),
        ],
        rows: weeks.map((w) => DataRow(cells: [
          DataCell(Text('Week ${w['week']}')),
          DataCell(Text('LKR ${(w['amount'] as num).toDouble().toStringAsFixed(2)}')),
        ])).toList(),
      )
    );
  }

  Widget _buildExpenseBreakdown(Map<String, dynamic> r) {
    final List cats = r['expenses']['by_category'] ?? [];
    return _buildSectionBox('Expense Categories', 
      Column(
        children: cats.map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c['category']),
                  Text('LKR ${(c['amount'] as num).toDouble().toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: c['pct_of_total'] / 100,
                backgroundColor: Colors.white12,
                color: Color(0xFF0882C8),
                minHeight: 6,
              ),
            ],
          ),
        )).toList(),
      )
    );
  }

  Widget _buildTopProducts(Map<String, dynamic> r) {
    final List items = r['top_products'] ?? [];
    return _buildSectionBox('Top Products (Performance)', 
      SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Units')),
            DataColumn(label: Text('Revenue')),
            DataColumn(label: Text('Profit')),
          ],
          rows: items.map((i) => DataRow(cells: [
            DataCell(Text(i['name'] ?? 'Unknown')),
            DataCell(Text((i['units_sold'] as num?)?.toInt().toString() ?? '0')),
            DataCell(Text('LKR ${(i['revenue'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}')),
            DataCell(Text('LKR ${(i['profit'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: Colors.greenAccent))),
          ])).toList(),
        ),
      )
    );
  }

  Widget _buildSectionBox(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(16)),
          child: child,
        ),
      ],
    );
  }

  Future<void> _exportPdf(Map<String, dynamic> r) async {
    try {
      final pdf = pw.Document();
      final monthName = _monthName(_month);
      final revenue = (r['revenue']?['total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final cogs = (r['cogs'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final grossProfit = (r['gross_profit'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final expenses = (r['expenses']?['total'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final netProfit = (r['net_profit'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final topProducts = (r['top_products'] as List?) ?? [];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Monthly Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('$monthName $_year', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('P&L Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  data: [
                    ['Item', 'Amount (LKR)'],
                    ['Total Revenue', revenue],
                    ['Cost of Goods (COGS)', cogs],
                    ['Gross Profit', grossProfit],
                    ['Total Expenses', expenses],
                    ['NET PROFIT', netProfit],
                  ],
                ),
                pw.SizedBox(height: 24),
                if (topProducts.isNotEmpty) ...[
                  pw.Text('Top Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    data: [
                      ['Product', 'Units', 'Revenue', 'Profit'],
                      ...topProducts.map((i) => [
                        i['name'] ?? '',
                        '${(i['units_sold'] as num?)?.toInt() ?? 0}',
                        'LKR ${(i['revenue'] as num?)?.toDouble().toStringAsFixed(0) ?? "0"}',
                        'LKR ${(i['profit'] as num?)?.toDouble().toStringAsFixed(0) ?? "0"}',
                      ]),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Report_${monthName}_$_year.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Extension to provider for specific fetching
extension PosProviderAccountsExt on PosProvider {
  Future<List<dynamic>> getTransactionsForDay(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final result = await apiService.get('/api/accounts/transactions?date=$dateStr');
    return (result as List?) ?? [];
  }

  Future<List<dynamic>> getTransactionsFiltered({required DateTime from, required DateTime to, String? type}) async {
    final f = DateFormat('yyyy-MM-dd').format(from);
    final t = DateFormat('yyyy-MM-dd').format(to);
    String url = '/api/accounts/transactions?from=$f&to=$t';
    if (type != null) url += '&type=$type';
    final result = await apiService.get(url);
    return (result as List?) ?? [];
  }
}
