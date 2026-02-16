const fs = require('fs');
const path = require('path');
const Sequelize = require('sequelize');
const sequelize = require('../config/database');

const db = {};

const models = [
    'User',
    'Customer',
    'Product',
    'Order',
    'OrderItem',
    'Coupon',
    'Supplier',
    'Account',
    'Transaction',
    'Settings',
    'Company',
    'Branch',
    'RolePermission'
];

// Import models
models.forEach(modelName => {

    const modelPath = path.join(__dirname, `${modelName}.js`);
    if (fs.existsSync(modelPath)) {
        const model = require(modelPath);
        db[modelName] = model;
    } else {
        console.warn(`Model file not found: ${modelName}.js`);
    }

});

// Initialize associations
Object.keys(db).forEach(modelName => {
    if (db[modelName] && db[modelName].associate) {
        db[modelName].associate(db);
    }
});

// Explicitly define associations here if they are not in the model files' associate method
// Ideally, we move association logic to the models themselves, but for now, let's redefine them here to be sure.

// Order <-> Customer
if (db.Order && db.Customer) {
    db.Order.belongsTo(db.Customer, { foreignKey: 'customer_id' });
    db.Customer.hasMany(db.Order, { foreignKey: 'customer_id' });
}

// Order <-> OrderItem
if (db.Order && db.OrderItem) {
    db.Order.hasMany(db.OrderItem, { foreignKey: 'order_id' });
    db.OrderItem.belongsTo(db.Order, { foreignKey: 'order_id' });
}

// OrderItem <-> Product
if (db.OrderItem && db.Product) {
    db.OrderItem.belongsTo(db.Product, { foreignKey: 'product_id' });
    db.Product.hasMany(db.OrderItem, { foreignKey: 'product_id' });
}

// Product <-> Supplier
if (db.Product && db.Supplier) {
    db.Product.belongsTo(db.Supplier, { foreignKey: 'supplier_id' });
    db.Supplier.hasMany(db.Product, { foreignKey: 'supplier_id' });
}

// Company <-> Branch
if (db.Company && db.Branch) {
    db.Company.hasMany(db.Branch, { foreignKey: 'company_id' });
    db.Branch.belongsTo(db.Company, { foreignKey: 'company_id' });
}

// Branch <-> User
if (db.Branch && db.User) {
    db.Branch.hasMany(db.User, { foreignKey: 'branch_id' });
    db.User.belongsTo(db.Branch, { foreignKey: 'branch_id' });
}


db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;
