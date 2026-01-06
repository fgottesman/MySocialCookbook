import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';


dotenv.config();

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

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});
