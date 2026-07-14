import * as admin from 'firebase-admin';
import cron from 'node-cron';
import { CONFIG } from './config';
import { scrapeBSEK } from './scrapers/bsek';
import { scrapeBIEK } from './scrapers/biek';
import { writeNewsBatch } from './services/firestore';

let db: admin.firestore.Firestore;
let app: admin.app.App;

function initializeFirebase(): void {
  try {
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: CONFIG.firebase.projectId || undefined,
    });
    db = admin.firestore();
    db.settings({ ignoreUndefinedProperties: true });
    console.log('[Firebase] Initialized successfully');
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[Firebase] Init failed: ${msg}`);
    process.exit(1);
  }
}

async function runScrapeCycle(): Promise<void> {
  const startedAt = Date.now();
  console.log('='.repeat(60));
  console.log(`[Scheduler] Scrape cycle started at ${new Date().toISOString()}`);
  console.log('='.repeat(60));

  const results = await Promise.allSettled([
    scrapeBSEK().then((r) => ({ ...r, label: 'BSEK' })),
    scrapeBIEK().then((r) => ({ ...r, label: 'BIEK' })),
  ]);

  let totalWritten = 0;
  let totalSkipped = 0;
  let totalUpdated = 0;

  for (const result of results) {
    if (result.status === 'rejected') {
      console.error(`[${result.reason?.label || 'Scraper'}] CRASHED:`, result.reason);
      continue;
    }

    const { label, source, items, error } = result.value;

    if (error) {
      console.warn(`[${label}] Scraped with warning: ${error}`);
    }

    if (items.length === 0) {
      console.log(`[${label}] No items found, skipping Firestore write.`);
      continue;
    }

    const { written, skipped, updated, errors } = await writeNewsBatch(db, source, items);
    totalWritten += written;
    totalSkipped += skipped;
    totalUpdated += updated;

    console.log(
      `[${label}] Written: ${written} | Updated: ${updated} | Skipped (dupes): ${skipped} | Errors: ${errors}`,
    );
  }

  const elapsed = ((Date.now() - startedAt) / 1000).toFixed(1);
  console.log(`[Scheduler] Cycle complete in ${elapsed}s. Total new: ${totalWritten}, Updated: ${totalUpdated}`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const runOnce = args.includes('--once');

  initializeFirebase();

  if (runOnce) {
    console.log('[Scheduler] Running single scrape cycle (--once)...');
    await runScrapeCycle();
    console.log('[Scheduler] Done. Exiting.');
    await app.delete();
    process.exit(0);
  }

  console.log(`[Scheduler] Initial scrape starting...`);
  await runScrapeCycle();

  const intervalMinutes = CONFIG.scrapeIntervalMinutes;
  const cronExpr = `*/${intervalMinutes} * * * *`;
  console.log(`[Scheduler] Scheduling every ${intervalMinutes} minutes (cron: ${cronExpr})`);

  cron.schedule(cronExpr, () => {
    runScrapeCycle().catch((err) => {
      console.error('[Scheduler] Uncaught cycle error:', err);
    });
  });

  console.log('[Scheduler] Running. Press Ctrl+C to stop.');
}

main().catch((err) => {
  console.error('[Fatal]', err);
  process.exit(1);
});
