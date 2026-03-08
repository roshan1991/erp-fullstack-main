const sequelize = require('./config/database');
async function main() {
    try {
        await sequelize.query('ALTER TABLE inventory_products ADD COLUMN deletedAt DATETIME DEFAULT NULL;');
        console.log('Done');
    } catch(e) {
        if(e.name === 'SequelizeDatabaseError' && e.message.includes('Duplicate column name')) {
            console.log('Column already exists');
        } else {
            console.error('Error:', e.message);
        }
    }
    process.exit();
}
main();
