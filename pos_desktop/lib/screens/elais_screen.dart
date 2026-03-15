import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../widgets/sidebar.dart';

class ElaisScreen extends StatefulWidget {
  final bool isOverlay;
  const ElaisScreen({super.key, this.isOverlay = false});
  @override State<ElaisScreen> createState() => _ElaisScreenState();
}

class _ElaisScreenState extends State<ElaisScreen> with SingleTickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late TabController _tabCtrl;
  String _forecast = '';
  Map<String, dynamic>? _cashflow;
  bool _loadingForecast = false;
  bool _loadingCashflow = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosProvider>().fetchElaisAlerts();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _send() async {
    final q = _msgCtrl.text.trim();
    if (q.isEmpty) return;
    _msgCtrl.clear();
    await context.read<PosProvider>().chatWithElais(q);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Widget _chatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFFF6B6B) : const Color(0xFF3A3A4C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg['content'] ?? '',
            style: TextStyle(
              color: isUser ? Colors.white : Colors.white.withOpacity(0.92),
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final colors = {
      'critical': const Color(0xFFFF4444),
      'warning': const Color(0xFFFFAA00),
      'info': const Color(0xFF4A90D9),
    };
    final color = colors[alert['severity']] ?? const Color(0xFF888888);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(alert['title'] ?? '', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(alert['message'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _insightPanel(PosProvider prov) {
    return Column(children: [
      TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFFFF6B6B),
        unselectedLabelColor: Colors.white38,
        indicatorColor: const Color(0xFFFF6B6B),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: const [Tab(text: 'ALERTS'), Tab(text: 'FORECAST'), Tab(text: 'CASH FLOW')],
      ),
      Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
        // --- Alerts Tab ---
        ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (prov.dailyBrief != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.wb_sunny, color: Color(0xFFFF6B6B), size: 16),
                    const SizedBox(width: 6),
                    Text('Good morning from Elais',
                        style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(prov.dailyBrief!, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                ]),
              ),
            ],
            if (prov.elaisAlerts.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('All clear! No alerts today.', style: TextStyle(color: Colors.white38)),
              ))
            else
              ...prov.elaisAlerts.map(_alertCard),
          ],
        ),
        // --- Forecast Tab ---
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.trending_up, size: 16),
              label: const Text('Generate demand forecast', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadingForecast
                  ? null
                  : () async {
                      setState(() => _loadingForecast = true);
                      _forecast = await context.read<PosProvider>().getDemandForecast();
                      setState(() => _loadingForecast = false);
                    },
            ),
            const SizedBox(height: 12),
            if (_loadingForecast)
              const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
            else if (_forecast.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_forecast, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6)),
              ),
          ]),
        ),
        // --- Cash Flow Tab ---
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet, size: 16),
              label: const Text('Generate 30-day forecast', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadingCashflow
                  ? null
                  : () async {
                      setState(() => _loadingCashflow = true);
                      _cashflow = await context.read<PosProvider>().getCashflowForecast();
                      setState(() => _loadingCashflow = false);
                    },
            ),
            const SizedBox(height: 12),
            if (_loadingCashflow)
              const Center(child: CircularProgressIndicator(color: Color(0xFF4A90D9)))
            else if (_cashflow != null) ...[
              _cashflowStatRow('Projected Revenue', _cashflow!['projected_revenue'], '0xFF4CAF50'),
              _cashflowStatRow('Projected Expenses', _cashflow!['projected_expenses'], '0xFFFF9800'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_cashflow!['forecast'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6)),
              ),
            ],
          ]),
        ),
      ])),
    ]);
  }

  Widget _cashflowStatRow(String label, dynamic value, String colorHex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text('LKR ${(value as num? ?? 0).toStringAsFixed(0)}',
            style: TextStyle(color: Color(int.parse(colorHex)), fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PosProvider>();
    Widget content = Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A3C),
          border: Border(bottom: BorderSide(color: Color(0xFF3A3A4C))),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFFF6B6B), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Elais AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${prov.elaisAlerts.length} alerts active', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white38),
            onPressed: () => prov.fetchElaisAlerts(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16, color: Colors.white38),
            onPressed: prov.clearElaisChat,
            tooltip: 'Clear Chat',
          ),
        ]),
      ),
      // Body
      Expanded(
        child: widget.isOverlay 
          ? _buildOverlayLayout(prov)
          : Row(children: [
              // Chat panel
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF3A3A4C))),
                ),
                child: _buildChatPanel(prov),
              ),
              // Right insight panel
              Expanded(child: _insightPanel(prov)),
            ]),
      ),
    ]);

    if (widget.isOverlay) return Material(color: const Color(0xFF1E1E2C), child: content);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Row(children: [
        const Sidebar(activePage: 'elais'),
        Expanded(child: content),
      ]),
    );
  }

  Widget _buildOverlayLayout(PosProvider prov) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF2A2A3C),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: const Color(0xFFFF6B6B),
            labelColor: const Color(0xFFFF6B6B),
            tabs: const [Tab(text: 'Chat'), Tab(text: 'Insights')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildChatPanel(prov),
              _insightPanel(prov),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel(PosProvider prov) {
    return Column(children: [
      // Quick prompts
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _quickPrompt('Today\'s summary'),
          _quickPrompt('Low stock'),
          _quickPrompt('Best sellers'),
        ]),
      ),
      // Messages
      Expanded(
        child: prov.chatHistory.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome, size: 40, color: Color(0xFFFF6B6B)),
                const SizedBox(height: 12),
                const Text('Hi, I\'m Elais!',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
              ]))
            : ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...prov.chatHistory.map(_chatBubble),
                  if (prov.elaisLoading)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(children: [
                        SizedBox(width: 12),
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B))),
                        SizedBox(width: 8),
                        Text('Elais is thinking...', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ]),
                    ),
                ],
              ),
      ),
      // Input
      Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF3A3A4C))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask Elais...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF3A3A4C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _quickPrompt(String text) {
    return GestureDetector(
      onTap: () async {
        _msgCtrl.clear();
        await context.read<PosProvider>().chatWithElais(text);
        _scrollToBottom();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A4C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ),
    );
  }
}
