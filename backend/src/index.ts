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
import { v4 as uuidv4 } from 'uuid';

const app = express();
const port = process.env.PORT || 8080;

app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Request ID middleware
app.use((req, res, next) => {
    const requestId = uuidv4();
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

const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });
const liveService = new GeminiLiveService();

server.on('upgrade', async (request, socket, head) => {
    const url = new URL(request.url || '', `http://${request.headers.host}`);

    if (url.pathname === '/ws/live-cooking' || url.pathname === '/api/ws/live-cooking') {
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
app.use(errorHandler);

server.listen(port, () => {
    logger.info(`Server is running on port ${port}`);
});
