const sequelize = require('./config/database');
const Product = require('./models/Product');

async function testDelete() {
    try {
        let p = await Product.findByPk(1);
        if (p) {
            console.log("Found product 1:", p.name);
            await p.destroy();
            console.log("Product 1 destroyed. Checking if it's accessible...");
            let p2 = await Product.findByPk(1);
            console.log("Found after destroy:", p2 ? "Yes" : "No");
            
            // Restore for future testing
            await p.restore();
            console.log("Product 1 restored.");
        } else {
            console.log("Product 1 not found");
        }
    } catch(e) {
        console.error("Error:", e.message);
    }
    process.exit();
}
testDelete();
