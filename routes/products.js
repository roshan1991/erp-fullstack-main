const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const { authenticate } = require('../middleware/auth');
const { Op } = require('sequelize');

// --- Products (Local Inventory) ---
router.get("/", authenticate, async (req, res) => {
    try {
        const { skip, limit, search } = req.query;
        const offset = parseInt(skip) || 0;
        const limitVal = parseInt(limit) || 100;

        const whereClause = {};
        if (search) {
            whereClause[Op.or] = [
                { name: { [Op.like]: `%${search}%` } },
                { sku: { [Op.like]: `%${search}%` } }
            ];
        }

        const products = await Product.findAll({
            where: whereClause,
            offset: offset,
            limit: limitVal
        });

        res.json({ products });
    } catch (error) {
        console.error("Get products error:", error);
        res.status(500).json({ detail: "Failed to fetch products" });
    }
});

module.exports = router;
