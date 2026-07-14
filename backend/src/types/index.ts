export type BoardSource = 'BSEK' | 'BIEK';

export type NewsCategory =
  | 'Exams'
  | 'Admissions'
  | 'Results'
  | 'General';

export interface ScrapedNewsItem {
  title: string;
  originalUrl: string;
  source: BoardSource;
  dateStr: string | null;
  category: NewsCategory;
  imageUrl: string;
}

export interface FirestoreNewsItem {
  title: string;
  originalUrl: string;
  source: BoardSource;
  timestamp: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  category: NewsCategory;
  imageUrl: string;
  scrapedAt: FirebaseFirestore.FieldValue;
  titleHash: string;
}

export interface ScraperResult {
  source: BoardSource;
  items: ScrapedNewsItem[];
  error: string | null;
}
