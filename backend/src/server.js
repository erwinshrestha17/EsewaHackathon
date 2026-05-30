import { env } from './config/env.js';
import { app } from './app.js';

app.listen(env.port, env.host, (error) => {
  if (error) {
    console.error('Failed to start Sajha Kharcha API:', error.message);
    process.exitCode = 1;
    return;
  }

  console.log(`Sajha Kharcha API listening on http://${env.host}:${env.port}`);
});
