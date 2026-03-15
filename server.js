const express = require("express");
const path = require("path");
const cors = require("cors");
const dotenv = require("dotenv");
const apiRoutes = require("./routes/api");
const sequelize = require("./config/database");

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes
const accountsRoutes = require('./routes/accounts_full');
app.use('/api/accounts', accountsRoutes);

// Elais AI
app.use('/api/elais', require('./routes/elais'));

app.use("/api/v1", apiRoutes);

// Swagger Documentation
const swaggerUi = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger');
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// Serve uploaded logos publicly at /api/v1/logos/
app.use("/api/v1/logos", express.static(path.join(__dirname, "public", "logos")));

// Serve general uploads (like products) publicly at /api/v1/uploads/
app.use("/api/v1/uploads", express.static(path.join(__dirname, "public", "uploads")));

// Serve static files from React build
app.use(express.static(path.join(__dirname, "client", "dist")));

// Health check endpoint
app.get("/api/health", (req, res) => {
    res.json({
        status: "ok",
        backend: "node",
        database: "connected",
        version: "1.0.0"
    });
});

// All other routes serve the React app
app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "client", "dist", "index.html"));
});

// Initialize database and start server
const startServer = async () => {
    console.log('--- Server Restart Triggered ---');
    try {
        // Test database connection
        try {
            await sequelize.authenticate();
            console.log('✅ Database connection established successfully.');
            
            // Sync database models
            console.log('🔄 Syncing database models...');
            await sequelize.sync({ alter: false });
            console.log('✅ Database models synced.');
        } catch (dbError) {
            console.warn('⚠️ MySQL Database not connected. Some features may be limited.');
            console.warn('   (SQLite features like Elais and Accounts will still work)');
        }

        // Seed Admin User (only if DB is connected)
        if (sequelize.models.User) {
            try {
                const { User } = require('./models/index');
                const adminExists = await User.findOne({ where: { email: 'admin@example.com' } });
                if (!adminExists) {
                    console.log('🔄 Creating default admin user...');
                    const hashedPassword = await User.hashPassword('admin');
                    await User.create({
                        username: 'admin',
                        email: 'admin@example.com',
                        hashed_password: hashedPassword,
                        full_name: 'System Administrator',
                        is_active: true,
                        is_superuser: true,
                        role: 'admin',
                        branch_id: null
                    });
                    console.log('✅ Admin user created: admin / admin');
                }
            } catch (seedError) {
                console.error('⚠️ Failed to seed admin user:', seedError);
            }
        }

        // Create HTTP server and initialize Socket.IO
        const http = require('http');
        const server = http.createServer(app);
        const { Server } = require("socket.io");
        const io = new Server(server, {
            cors: {
                origin: "*", // allow all or specify client URL
                methods: ["GET", "POST"]
            }
        });

        // Initialize socket logic
        require('./sockets/chat')(io);

        // Make io accessible to our router
        app.set('io', io);

        // Start server
        server.listen(PORT, () => {
            console.log(`\n╔════════════════════════════════════════════════════════╗`);
            console.log(`║     ERP FULLSTACK APPLICATION - RUNNING               ║`);
            console.log(`╚════════════════════════════════════════════════════════╝`);
            console.log(`\n🚀 Server: http://localhost:${PORT}`);
            console.log(`📊 Database: ${process.env.DB_NAME} on ${process.env.DB_HOST}`);
            console.log(`🔌 API: http://localhost:${PORT}/api/v1`);
            console.log(`📚 Docs: http://localhost:${PORT}/api-docs`);
            console.log(`\n💡 Press Ctrl+C to stop\n`);
            
            checkOllama();
        });
    } catch (error) {
        console.error('❌ Unable to start server:', error);
        process.exit(1);
    }
};

startServer();

process.on('SIGINT', () => {
    console.log('Server shutting down...');
    process.exit(0);
});

async function checkOllama() {
    try {
        const response = await fetch('http://localhost:11434/api/tags');
        if (response.ok) {
            const data = await response.json();
            const models = data.models?.map(m => m.name).join(', ') || 'none';
            console.log('[Elais] ✅ Ollama is running. Available models: ' + models);
        } else {
            console.warn('[Elais] ⚠️ Ollama returned an error. AI features might be limited.');
        }
    } catch (err) {
        console.warn('[Elais] ❌ WARNING: Ollama not detected on port 11434. AI features will be unavailable.');
    }
}
