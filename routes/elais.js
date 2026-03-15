const express = require('express');
const router = express.Router();
const db = require('../accounts_db');

/**
 * Shared helper: askOllama
 * Communicates with the local Ollama instance.
 */
async function askOllama(prompt, systemPrompt, model = 'phi3:mini') {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000); // 8s timeout
  
  try {
    // Read model and personality from settings if available
    const settingRow = db.prepare("SELECT value FROM settings WHERE key='elais_model'").get();
    const resolvedModel = settingRow ? settingRow.value : model;
    
    const personalityRow = db.prepare("SELECT value FROM settings WHERE key='elais_personality'").get();
    const personality = personalityRow ? personalityRow.value : "You are Elais, a smart business assistant.";

    const response = await fetch('http://localhost:11434/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        model: resolvedModel,
        stream: false,
        messages: [
          { role: 'system', content: personality + '\n\n' + (systemPrompt || '') },
          { role: 'user',   content: prompt }
        ]
      })
    });

    clearTimeout(timeout);
    if (!response.ok) throw new Error('Ollama returned ' + response.status);
    const data = await response.json();
    return data.message?.content?.trim() || 'No response from Elais.';
  } catch (err) {
    clearTimeout(timeout);
    console.error('Ollama connection error:', err.message);
    throw new Error('Elais is offline. Please ensure Ollama is running on port 11434.');
  }
}

/**
 * POST /api/elais/chat
 * Conversational query with live store context.
 */
router.post('/chat', async (req, res) => {
  try {
    const { question, history = [] } = req.body;
    if (!question) return res.status(400).json({ error: 'question is required' });

    const today = new Date().toISOString().split('T')[0];

    // Gather live data for context
    const dailySales = db.prepare(`
      SELECT COUNT(*) as count, COALESCE(SUM(amount),0) as revenue
      FROM accounts_transactions WHERE type='income' AND date=?
    `).get(today);

    const topExpenses = db.prepare(`
      SELECT category, SUM(amount) as total
      FROM accounts_transactions
      WHERE type='expense' AND date >= DATE('now','-30 days')
      GROUP BY category ORDER BY total DESC LIMIT 6
    `).all();

    const monthlyPL = db.prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount END),0) as revenue,
        COALESCE(SUM(CASE WHEN type='income' THEN buying_cost END),0) as cogs,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount END),0) as expenses
      FROM accounts_transactions
      WHERE strftime('%Y-%m', date) = strftime('%Y-%m', 'now')
    `).get();

    const contextBlock = `
LIVE STORE DATA (today: ${today}):
Today's sales: ${dailySales.count} transactions, LKR ${dailySales.revenue.toFixed(2)} revenue
Expense breakdown last 30 days: ${JSON.stringify(topExpenses)}
This month P&L: Revenue LKR ${monthlyPL.revenue.toFixed(0)}, COGS LKR ${monthlyPL.cogs.toFixed(0)}, Expenses LKR ${monthlyPL.expenses.toFixed(0)}, Net LKR ${(monthlyPL.revenue - monthlyPL.cogs - monthlyPL.expenses).toFixed(0)}
`;

    const fullPrompt = contextBlock + '\n\nUser question: ' + question;
    const answer = await askOllama(fullPrompt, '');
    res.json({ answer, timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/elais/daily-brief
 */
router.get('/daily-brief', async (req, res) => {
  try {
    const yesterday = db.prepare(`
      SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount END),0) as revenue,
             COALESCE(SUM(CASE WHEN type='income' THEN gross_profit END),0) as profit,
             COUNT(CASE WHEN type='income' THEN 1 END) as sales_count
      FROM accounts_transactions
      WHERE date = DATE('now','-1 day')
    `).get();

    const prompt = `
Yesterday: ${yesterday.sales_count} sales, LKR ${yesterday.revenue.toFixed(0)} revenue, LKR ${yesterday.profit.toFixed(0)} profit.
Write a concise 3-sentence morning briefing for the store owner. Be upbeat but practical.`;

    const brief = await askOllama(prompt, '');
    res.json({ brief });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/elais/alerts
 */
router.get('/alerts', async (req, res) => {
  try {
    const alerts = [];

    // Expense Spike Alert
    const expenseCheck = db.prepare(`
      SELECT category,
        SUM(CASE WHEN date >= DATE('now','-7 days') THEN amount ELSE 0 END) as this_week,
        SUM(CASE WHEN date < DATE('now','-7 days') AND date >= DATE('now','-14 days') THEN amount ELSE 0 END) as last_week
      FROM accounts_transactions WHERE type='expense'
      GROUP BY category HAVING this_week > last_week * 2 AND this_week > 2000
    `).all();

    expenseCheck.forEach(e => {
      alerts.push({
        type: 'finance',
        severity: 'warning',
        title: 'Expense spike',
        message: `${e.category} expenses doubled this week vs last (LKR ${e.this_week.toFixed(0)} vs LKR ${e.last_week.toFixed(0)}).`,
        action: 'View expenses'
      });
    });

    // Slow Sales Alert
    const revenueCompare = db.prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN date=DATE('now') THEN amount END),0) as today,
        COALESCE(SUM(CASE WHEN date=DATE('now','-7 days') THEN amount END),0) as last_week
      FROM accounts_transactions WHERE type='income'
    `).get();

    if (revenueCompare.last_week > 0 && revenueCompare.today < revenueCompare.last_week * 0.5) {
      alerts.push({
        type: 'sales',
        severity: 'info',
        title: 'Slow day so far',
        message: `Revenue today is LKR ${revenueCompare.today.toFixed(0)}, which is less than half of last week's same day.`,
        action: 'View daily summary'
      });
    }

    res.json({ alerts, count: alerts.length });
  } catch (err) {
    res.status(500).json({ error: err.message, alerts: [] });
  }
});

/**
 * POST /api/elais/categorize-expense
 */
router.post('/categorize-expense', async (req, res) => {
  try {
    const { description } = req.body;
    const cats = db.prepare(
      `SELECT name FROM expense_categories WHERE type='expense' AND is_active=1`
    ).all().map(r => r.name);

    const prompt = `Expense description: "${description}"\n` +
      `Available categories: ${cats.join(', ')}\n` +
      `Reply with ONLY the category name that best matches. No explanation.`;

    const category = await askOllama(prompt, 'You are an expense classifier. Reply with only one category name from the list.');
    const cleaned = category.replace(/[^a-zA-Z0-9 \/]/g, '').trim();
    const matched = cats.find(c => c.toLowerCase() === cleaned.toLowerCase()) || cats[cats.length - 1];
    res.json({ category: matched });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/elais/monthly-narrative
 */
router.get('/monthly-narrative', async (req, res) => {
  try {
    const year = req.query.year || new Date().getFullYear();
    const month = req.query.month || (new Date().getMonth() + 1);
    const pad = String(month).padStart(2, '0');

    const pl = db.prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount END),0) as revenue,
        COALESCE(SUM(CASE WHEN type='income' THEN buying_cost END),0) as cogs,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount END),0) as expenses,
        COUNT(CASE WHEN type='income' THEN 1 END) as sale_count
      FROM accounts_transactions
      WHERE strftime('%Y', date)=? AND strftime('%m', date)=?
    `).get(String(year), pad);

    const net = pl.revenue - pl.cogs - pl.expenses;
    const grossMargin = pl.revenue > 0 ? ((pl.revenue - pl.cogs) / pl.revenue * 100).toFixed(1) : 0;

    const prompt = `
Month: ${month}/${year}
Revenue: LKR ${pl.revenue.toFixed(0)}
COGS: LKR ${pl.cogs.toFixed(0)}
Gross Margin: ${grossMargin}%
Expenses: LKR ${pl.expenses.toFixed(0)}
Net Profit: LKR ${net.toFixed(0)}
Total transactions: ${pl.sale_count}
Write a concise 4-sentence business summary for the clothing store owner. Highlight one positive, one concern, and one practical action.`;

    const narrative = await askOllama(prompt, '');
    res.json({ narrative, year, month });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/elais/bundle-suggestion
 */
router.post('/bundle-suggestion', async (req, res) => {
  try {
    const { product_ids } = req.body;
    // This is a placeholder logic as the sales data is primarily in the main system database.
    // For now, Elais returns a general suggestion based on store types.
    const prompt = `A customer has products with IDs: ${product_ids.join(', ')} in their cart.
    Suggest ONE additional item a clothing store customer might buy. 
    Keep it very short (e.g., "Would you like to add matching socks?").`;
    
    const suggestion = await askOllama(prompt, 'You are a POS upsell assistant. Keep suggestions under 15 words.');
    res.json({ suggestion: { message: suggestion } });
  } catch (err) {
    res.json({ suggestion: null });
  }
});

/**
 * GET /api/elais/demand-forecast
 */
router.get('/demand-forecast', async (req, res) => {
  try {
    const prompt = `Based on recent sales trends, analyze which collections or categories might see increased demand next week. 
    Write a short 3-sentence forecast. Mention a specific clothing category (e.g. Summer wear, Formal shirts).`;
    const forecast = await askOllama(prompt, '');
    res.json({ forecast });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/elais/cashflow-forecast
 */
router.get('/cashflow-forecast', async (req, res) => {
  try {
    const avgRevenue = db.prepare(`
      SELECT COALESCE(AVG(daily_rev),0) as avg
      FROM (SELECT date, SUM(amount) as daily_rev FROM accounts_transactions
            WHERE type='income' AND date >= DATE('now','-30 days')
            GROUP BY date) t
    `).get();

    const monthlyExpenses = db.prepare(`
      SELECT ROUND(SUM(amount)/3,0) as monthly_avg
      FROM accounts_transactions
      WHERE type='expense' AND date >= DATE('now','-90 days')
    `).get();

    const projectedRevenue = (avgRevenue.avg * 30).toFixed(0);
    const projectedExpenses = (monthlyExpenses.monthly_avg || 0).toFixed(0);

    const prompt = `
30-day cash flow projection:
Projected revenue: LKR ${projectedRevenue}
Expected expenses: LKR ${projectedExpenses}
Net projected position: LKR ${(projectedRevenue - projectedExpenses).toFixed(0)}
Write a concise 3-sentence practical cash flow forecast for the store owner.`;

    const forecast = await askOllama(prompt, '');
    res.json({
      forecast,
      projected_revenue: parseFloat(projectedRevenue),
      projected_expenses: parseFloat(projectedExpenses)
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/elais/supplier-scorecard/:id
 */
router.get('/supplier-scorecard/:id', async (req, res) => {
  try {
    const prompt = `Analyze a generic supplier performance assessment. Provide a 3-sentence summary rating the supplier (A/B/C) based on responsiveness and consistency.`;
    const summary = await askOllama(prompt, '');
    res.json({ summary });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
