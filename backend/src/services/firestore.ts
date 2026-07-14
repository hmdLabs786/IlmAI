import * as admin from 'firebase-admin';
import type { FirestoreNewsItem, ScrapedNewsItem } from '../types';
import { categorizeItems } from './categorizer';
import { generateDocumentId } from '../utils/hash';

const COLLECTION = 'board_news';
const FCM_TOPIC = 'karachi_board_updates';

function toFirestoreItem(item: ScrapedNewsItem): FirestoreNewsItem {
  const titleHash = generateDocumentId(item.title, item.source);

  return {
    title: item.title,
    originalUrl: item.originalUrl,
    source: item.source,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    category: item.category,
    imageUrl: item.imageUrl,
    scrapedAt: admin.firestore.FieldValue.serverTimestamp(),
    titleHash,
  };
}

async function sendPushNotification(item: ScrapedNewsItem): Promise<void> {
  try {
    const message: admin.messaging.Message = {
      notification: {
        title: `New ${item.source} Notification`,
        body: item.title,
      },
      topic: FCM_TOPIC,
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        url: item.originalUrl,
      },
    };

    await admin.messaging().send(message);
    console.log(`[FCM] Push sent for "${item.title.substring(0, 50)}..."`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.warn(`[FCM] Failed to send push for "${item.title.substring(0, 50)}...": ${msg}`);
  }
}

function hasContentChanged(existingData: FirestoreNewsItem, newItem: ScrapedNewsItem): boolean {
  if (existingData.originalUrl !== newItem.originalUrl) return true;
  if (existingData.category !== newItem.category) return true;
  if (existingData.imageUrl !== newItem.imageUrl) return true;
  return false;
}

export async function writeNewsBatch(
  db: admin.firestore.Firestore,
  source: string,
  rawItems: ScrapedNewsItem[],
): Promise<{ written: number; skipped: number; updated: number; errors: number }> {
  const categorized = categorizeItems(rawItems);
  let written = 0;
  let skipped = 0;
  let updated = 0;
  let errors = 0;

  const batch = db.batch();
  let opCount = 0;
  const newItems: ScrapedNewsItem[] = [];
  const updatedItems: ScrapedNewsItem[] = [];

  for (const item of categorized) {
    const docId = generateDocumentId(item.title, item.source);
    const docRef = db.collection(COLLECTION).doc(docId);

    const existing = await docRef.get();

    if (existing.exists) {
      const existingData = existing.data() as FirestoreNewsItem;
      if (hasContentChanged(existingData, item)) {
        const data = toFirestoreItem(item);
        data.scrapedAt = admin.firestore.FieldValue.serverTimestamp();
        batch.update(docRef, data);
        opCount++;
        updatedItems.push(item);
      } else {
        skipped++;
      }
      continue;
    }

    const data = toFirestoreItem(item);
    batch.set(docRef, data);
    opCount++;
    newItems.push(item);

    if (opCount >= 490) {
      try {
        await batch.commit();
        written += newItems.length;
        updated += updatedItems.length;

        for (const newItem of newItems) {
          await sendPushNotification(newItem);
        }
        for (const updatedItem of updatedItems) {
          await sendPushNotification(updatedItem);
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`[${source}] Batch commit failed: ${msg}`);
        errors += opCount;
      }

      opCount = 0;
      newItems.length = 0;
      updatedItems.length = 0;
    }
  }

  if (opCount > 0) {
    try {
      await batch.commit();
      written += newItems.length;
      updated += updatedItems.length;

      for (const newItem of newItems) {
        await sendPushNotification(newItem);
      }
      for (const updatedItem of updatedItems) {
        await sendPushNotification(updatedItem);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[${source}] Batch commit failed: ${msg}`);
      errors += opCount;
    }
  }

  return { written, skipped, updated, errors };
}
