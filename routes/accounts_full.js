const router = require('express').Router();
const db = require('../accounts_db');

// GET /transactions — filter by date, from, to, type, category, limit=100
router.get('/transactions', (req, res) => {
  try {
    const { date, from, to, type, category, limit = 100 } = req.query;
    let query = 'SELECT * FROM accounts_transactions WHERE 1=1';
    const params = [];

    if (date) {
      query += ' AND date = ?';
      params.push(date);
    } else if (from && to) {
      query += ' AND date BETWEEN ? AND ?';
      params.push(from, to);
    }

    if (type) {
      query += ' AND type = ?';
      params.push(type);
    }

    if (category) {
      query += ' AND category = ?';
      params.push(category);
    }

    query += ' ORDER BY created_at DESC LIMIT ?';
    params.push(parseInt(limit));

    const rows = db.prepare(query).all(...params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /transactions — insert manual income/expense
router.post('/transactions', (req, res) => {
  try {
    const { type, category, description, amount, date, payment_method, reference_id } = req.body;
    const result = db.prepare(`
      INSERT INTO accounts_transactions 
      (type, category, description, amount, date, payment_method, reference_id, reference_type, buying_cost, gross_profit)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'manual', 0, 0)
    `).run(type, category, description, amount, date || new Date().toISOString().split('T')[0], payment_method, reference_id);

    const row = db.prepare('SELECT * FROM accounts_transactions WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /transactions/:id — block if reference_type='sale', else delete
router.delete('/transactions/:id', (req, res) => {
  try {
    const { id } = req.params;
    const tx = db.prepare('SELECT reference_type FROM accounts_transactions WHERE id = ?').get(id);
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });
    if (tx.reference_type === 'sale') {
      return res.status(403).json({ error: 'Locked: Sales transactions cannot be deleted manually.' });
    }
    db.prepare('DELETE FROM accounts_transactions WHERE id = ?').run(id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /daily-summary?date=YYYY-MM-DD — return full P&L for the day
router.get('/daily-summary', (req, res) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];
    const incomeRows = db.prepare("SELECT * FROM accounts_transactions WHERE type='income' AND date=?").all(date);
    const expenseRows = db.prepare("SELECT * FROM accounts_transactions WHERE type='expense' AND date=?").all(date);

    const revenueTotal = incomeRows.reduce((s, r) => s + r.amount, 0);
    const cogs = incomeRows.reduce((s, r) => s + r.buying_cost, 0);
    const expensesTotal = expenseRows.reduce((s, r) => s + r.amount, 0);
    const grossProfit = revenueTotal - cogs;
    const netProfit = grossProfit - expensesTotal;

    const cash = incomeRows.filter(r => r.payment_method === 'CASH').reduce((s, r) => s + r.amount, 0);
    const card = incomeRows.filter(r => r.payment_method === 'CARD').reduce((s, r) => s + r.amount, 0);
    const transfer = incomeRows.filter(r => r.payment_method === 'TRANSFER').reduce((s, r) => s + r.amount, 0);
    const other = incomeRows.filter(r => !['CASH', 'CARD', 'TRANSFER'].includes(r.payment_method)).reduce((s, r) => s + r.amount, 0);

    const expByCat = db.prepare(`
      SELECT category, SUM(amount) as amount FROM accounts_transactions 
      WHERE type='expense' AND date=? GROUP BY category
    `).all(date);

    const paymentBreakdown = db.prepare(`
      SELECT payment_method as method, COUNT(*) as count, SUM(amount) as amount
      FROM accounts_transactions
      WHERE type='income' AND date=?
      GROUP BY payment_method
    `).all(date);

    res.json({
      date,
      revenue: { total: revenueTotal, cash, card, transfer, other },
      cogs,
      gross_profit: grossProfit,
      expenses: { total: expensesTotal, by_category: expByCat },
      net_profit: netProfit,
      transaction_count: incomeRows.length,
      avg_sale_value: incomeRows.length > 0 ? (revenueTotal / incomeRows.length) : 0,
      payment_breakdown: paymentBreakdown
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /monthly-report?year=X&month=Y — return full monthly P&L
router.get('/monthly-report', (req, res) => {
  try {
    const { year, month } = req.query;
    const monthPadded = month.toString().padStart(2, '0');
    const monthPattern = `${year}-${monthPadded}-%`;

    const incomeRows = db.prepare("SELECT * FROM accounts_transactions WHERE type='income' AND date LIKE ?").all(monthPattern);
    const expenseRows = db.prepare("SELECT * FROM accounts_transactions WHERE type='expense' AND date LIKE ?").all(monthPattern);

    const revenueTotal = incomeRows.reduce((s, r) => s + r.amount, 0);
    const cogs = incomeRows.reduce((s, r) => s + r.buying_cost, 0);
    const expensesTotal = expenseRows.reduce((s, r) => s + r.amount, 0);
    const grossProfit = revenueTotal - cogs;
    const netProfit = grossProfit - expensesTotal;

    const weeks = db.prepare(`
      SELECT strftime('%W', date) as week, SUM(amount) as amount
      FROM accounts_transactions
      WHERE type='income' AND date LIKE ?
      GROUP BY week
    `).all(monthPattern);

    const expCategories = db.prepare(`
      SELECT category, SUM(amount) as amount
      FROM accounts_transactions
      WHERE type='expense' AND date LIKE ?
      GROUP BY category
    `).all(monthPattern);

    const expWithPct = expCategories.map(c => ({
      category: c.category,
      amount: c.amount,
      pct_of_total: expensesTotal > 0 ? (c.amount / expensesTotal * 100) : 0
    }));

    const bestDay = db.prepare(`
      SELECT date, SUM(amount) as revenue
      FROM accounts_transactions
      WHERE type='income' AND date LIKE ?
      GROUP BY date
      ORDER BY revenue DESC
      LIMIT 1
    `).get(monthPattern);

    const daysInMonth = new Date(year, month, 0).getDate();
    const dailyBreakdown = [];
    for (let i = 1; i <= daysInMonth; i++) {
        const d = `${year}-${monthPadded}-${i.toString().padStart(2, '0')}`;
        const dayRev = incomeRows.filter(r => r.date === d).reduce((s, r) => s + r.amount, 0);
        const dayExp = expenseRows.filter(r => r.date === d).reduce((s, r) => s + r.amount, 0);
        dailyBreakdown.push({
            date: d,
            revenue: dayRev,
            expenses: dayExp,
            net: dayRev - dayExp
        });
    }

    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

    res.json({
      year, month, month_name: monthNames[month - 1],
      revenue: { total: revenueTotal, by_week: weeks },
      cogs, gross_profit: grossProfit, 
      gross_margin_pct: revenueTotal > 0 ? (grossProfit / revenueTotal * 100) : 0,
      expenses: { total: expensesTotal, by_category: expWithPct },
      net_profit: netProfit,
      best_day: bestDay || { date: 'N/A', revenue: 0 },
      daily_breakdown: dailyBreakdown
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /categories — return all active expense_categories
router.get('/categories', (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM expense_categories WHERE is_active=1 ORDER BY name').all();
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /categories — insert new category
router.post('/categories', (req, res) => {
  try {
    const { name, type } = req.body;
    const result = db.prepare('INSERT INTO expense_categories (name, type) VALUES (?, ?)').run(name, type);
    const row = db.prepare('SELECT * FROM expense_categories WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
