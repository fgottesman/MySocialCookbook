import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';


dotenv.config();

import http from 'http';
import { WebSocketServer } from 'ws';
import { GeminiLiveService } from './services/gemini_live';

const app = express();
const port = process.env.PORT || 8080;

app.use(cors());
app.use(express.json({ limit: '50mb' }));

import apiRouter from './routes/api';

// Initialize Supabase - ensures environment variables are loaded
import './db/supabase';

app.use('/api', apiRouter);

app.get('/', (req, res) => {
    res.send('ClipCook Backend is running!');
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server });
const liveService = new GeminiLiveService();

wss.on('connection', (ws, req) => {
    const url = new URL(req.url || '', `http://${req.headers.host}`);
    // Match /ws/live-cooking or /api/ws/live-cooking
    if (url.pathname === '/ws/live-cooking' || url.pathname === '/api/ws/live-cooking') {
        liveService.handleConnection(ws, req);
    } else {
        ws.close(1000, 'Invalid endpoint');
    }
});

server.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});
