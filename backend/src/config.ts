import dotenv from 'dotenv';
dotenv.config();

export const CONFIG = {
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID || '',
    credentialPath: process.env.GOOGLE_APPLICATION_CREDENTIALS || './service-account.json',
  },
  scrapeIntervalMinutes: parseInt(process.env.SCRAPE_INTERVAL_MINUTES || '240', 10),
  logLevel: process.env.LOG_LEVEL || 'info',
} as const;
