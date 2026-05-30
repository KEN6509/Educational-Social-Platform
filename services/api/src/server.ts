import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { env } from './config/env.js';
import { adminRouter } from './routes/admin.js';
import { healthRouter } from './routes/health.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.use('/admin', adminRouter);
app.use('/health', healthRouter);

app.listen(env.PORT, () => {
  console.log(`CyanZone API listening on port ${env.PORT}`);
});
