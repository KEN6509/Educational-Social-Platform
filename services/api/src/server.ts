import app from './index.js';
import { env } from './config/env.js';

app.listen(env.PORT, () => {
  console.log(`CyanZone API listening on port ${env.PORT}`);
});
