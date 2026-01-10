import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';


dotenv.config();

import http from 'http';
import { WebSocketServer } from 'ws';
import { GeminiLiveService } from './services/gemini_live';
import { createClient } from '@supabase/supabase-js';
import { supabaseUrl, supabaseAnonKey } from './db/supabase';
import logger from './utils/logger';
import { errorHandler } from './middleware/error';
import { randomUUID } from 'crypto';
import { checkSchema } from './utils/schemaGuard';

const app = express();
app.set('trust proxy', 1);
const port = process.env.PORT || 8080;

app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Request ID middleware
app.use((req, res, next) => {
    const requestId = randomUUID();
    req.headers['x-request-id'] = requestId;
    res.setHeader('X-Request-Id', requestId);
    next();
});

import v1Router from './routes/v1';

app.use('/api/v1', v1Router);
// Temporarily keep legacy /api while transitioning iOS client
import apiRouter from './routes/api';
app.use('/api', apiRouter);

app.get('/', (req, res) => {
    res.send('ClipCook Backend is running!');
});

app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0',
        env: process.env.NODE_ENV || 'development'
    });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

// Error handler must be last
app.use(errorHandler);

// Validate schema before starting server
(async () => {
    try {
        await checkSchema();

        server.listen(port, () => {
            logger.info(`Server is running on port ${port}`);
        });
    } catch (error) {
        logger.error('[FATAL] Schema validation failed. Server will not start.', error);
        process.exit(1);
    }
})();

const liveService = new GeminiLiveService();

server.on('upgrade', async (request, socket, head) => {
    const url = new URL(request.url || '', `http://${request.headers.host}`);

    if (url.pathname === '/ws/live-cooking' || url.pathname === '/api/ws/live-cooking') {
        // Validate Supabase config before attempting auth
        if (!supabaseUrl || !supabaseAnonKey) {
            logger.error('[WS Upgrade] Supabase environment variables not configured');
            socket.write('HTTP/1.1 503 Service Unavailable\r\n\r\n');
            socket.destroy();
            return;
        }

        // Authenticate before upgrading
        const authHeader = request.headers['authorization'];
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
            socket.destroy();
            return;
        }

        const token = authHeader.split(' ')[1];
        const userClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: `Bearer ${token}` } }
        });

        const { data: authData, error: authError } = await userClient.auth.getUser();

        if (authError || !authData.user) {
            logger.error(`[WS Upgrade] Auth Failed: ${authError?.message}`);
            socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
            socket.destroy();
            return;
        }

        wss.handleUpgrade(request, socket, head, (ws) => {
            liveService.handleConnection(ws, request, authData.user, userClient);
        });
    } else {
        socket.destroy();
    }
});

// Error handler must be last
// Note: server.listen() is called above after schema validation passes

// Graceful shutdown
const shutdown = () => {
    logger.info('Shutting down gracefully...');
    server.close(() => {
        logger.info('HTTP server closed.');
        wss.close(() => {
            logger.info('WebSocket server closed.');
            process.exit(0);
        });
    });

    // Force exit after 10s
    setTimeout(() => {
        logger.error('Could not close connections in time, forcefully shutting down');
        process.exit(1);
    }, 10000);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
