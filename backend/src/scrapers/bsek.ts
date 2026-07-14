import axios from 'axios';
import puppeteer from 'puppeteer';
import * as cheerio from 'cheerio';
import type { ScrapedNewsItem, ScraperResult } from '../types';
import { cleanText, cleanTitle, extractDateFromText } from '../utils/sanitizer';

const PROD_BASE_URL = 'https://www.bsek.edu.pk';
const STAGING_BASE_URL = 'https://staging.bsek.edu.pk';
const API_PATH = '/api/v1d2s3h64';

interface BSEKContentItem {
  id: number;
  title: string;
  content: string;
  image_path: string;
  link: string | null;
  section: string;
  created_at: string;
  image_url: string;
  link_url: string | null;
}

interface BSEKApiResponse {
  current_page: number;
  data: BSEKContentItem[];
  total?: number;
  last_page?: number;
}

function mapItem(item: BSEKContentItem, baseUrl: string): ScrapedNewsItem {
  return {
    title: cleanText(item.title || item.content || ''),
    originalUrl: item.link_url || item.image_url || baseUrl,
    source: 'BSEK',
    dateStr: item.created_at || null,
    category: 'General',
    imageUrl: item.image_url || '',
  };
}

async function fetchAllPages(baseUrl: string, endpoint: string, perPage = 50): Promise<BSEKContentItem[]> {
  const allItems: BSEKContentItem[] = [];
  let page = 1;
  let totalPages = 1;

  while (page <= totalPages) {
    try {
      const res = await axios.get<BSEKApiResponse>(
        `${baseUrl}${API_PATH}/${endpoint}?per_page=${perPage}&page=${page}`,
        {
          timeout: 15000,
          headers: {
            Accept: 'application/json',
            'User-Agent':
              'Mozilla/5.0 (compatible; IlmAI-BoardScraper/1.0; +https://ilmai.app)',
          },
        },
      );

      const body = res.data;
      if (!body?.data || !Array.isArray(body.data)) break;

      allItems.push(...body.data);

      if (body.last_page) {
        totalPages = body.last_page;
      } else if (body.total && perPage > 0) {
        totalPages = Math.ceil(body.total / perPage);
      }
      page++;
    } catch {
      break;
    }
  }

  return allItems;
}

async function scrapeViaApi(): Promise<ScrapedNewsItem[]> {
  console.log('[BSEK] Trying production API...');
  let items = await fetchAllPages(PROD_BASE_URL, 'content/section/press_releases');

  if (items.length > 0) {
    console.log(`[BSEK] Got ${items.length} press releases from production API`);
    return items.map((i) => mapItem(i, PROD_BASE_URL));
  }

  console.log('[BSEK] Production API failed, trying staging API...');
  items = await fetchAllPages(STAGING_BASE_URL, 'content/section/press_releases');

  if (items.length > 0) {
    console.log(`[BSEK] Got ${items.length} press releases from staging API`);
    return items.map((i) => mapItem(i, STAGING_BASE_URL));
  }

  console.log('[BSEK] No press_releases found, trying all content via production API...');
  const allContent = await fetchAllPages(PROD_BASE_URL, 'content');

  if (allContent.length > 0) {
    console.log(`[BSEK] Got ${allContent.length} content items from production API`);
    return allContent.map((i) => mapItem(i, PROD_BASE_URL));
  }

  console.log('[BSEK] Trying all content via staging API...');
  const stagingContent = await fetchAllPages(STAGING_BASE_URL, 'content');

  if (stagingContent.length > 0) {
    console.log(`[BSEK] Got ${stagingContent.length} content items from staging API`);
    return stagingContent.map((i) => mapItem(i, STAGING_BASE_URL));
  }

  return [];
}

async function scrapeViaPuppeteer(): Promise<ScrapedNewsItem[]> {
  console.log('[BSEK] Trying Puppeteer to render SPA...');
  
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    
    const page = await browser.newPage();
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
    );

    // Try main page
    const urlsToTry = [
      PROD_BASE_URL,
      `${PROD_BASE_URL}/news`,
      `${PROD_BASE_URL}/press-releases`,
      `${PROD_BASE_URL}/notifications`,
      `${PROD_BASE_URL}/circulars`,
    ];

    for (const url of urlsToTry) {
      try {
        console.log(`[BSEK] Puppeteer navigating to ${url}...`);
        await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
        
        // Wait for React to hydrate
        await new Promise(resolve => setTimeout(resolve, 3000));

        const items = await page.evaluate(() => {
          const results: Array<{ title: string; url: string; date?: string }> = [];
          const seen = new Set<string>();
          
          document.querySelectorAll('a[href]').forEach((a) => {
            const href = a.getAttribute('href') || '';
            const text = a.textContent?.trim() || '';
            
            if (!text || text.length < 10 || seen.has(text)) return;
            
            // Check if link looks like a news item
            const isNewsLike = 
              href.includes('press') ||
              href.includes('news') ||
              href.includes('release') ||
              href.includes('notification') ||
              href.includes('circular') ||
              text.toLowerCase().includes('press') ||
              text.toLowerCase().includes('release') ||
              text.toLowerCase().includes('notification') ||
              text.toLowerCase().includes('circular') ||
              text.toLowerCase().includes('exam') ||
              text.toLowerCase().includes('result') ||
              text.toLowerCase().includes('admit') ||
              text.toLowerCase().includes('date sheet') ||
              text.toLowerCase().includes('schedule');
            
            if (isNewsLike) {
              seen.add(text);
              let fullUrl = href;
              if (href.startsWith('/')) fullUrl = `https://www.bsek.edu.pk${href}`;
              else if (!href.startsWith('http')) fullUrl = `https://www.bsek.edu.pk/${href}`;
              
              results.push({ title: text, url: fullUrl });
            }
          });
          
          return results;
        });

        console.log(`[BSEK] Puppeteer found ${items.length} potential news items from ${url}`);
        
        if (items.length > 0) {
          return items.map(item => ({
            title: cleanText(item.title),
            originalUrl: item.url,
            source: 'BSEK',
            dateStr: null,
            category: 'General',
            imageUrl: '',
          }));
        }
      } catch (err) {
        console.log(`[BSEK] Puppeteer failed for ${url}: ${err}`);
        continue;
      }
    }

    return [];
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[BSEK] Puppeteer error: ${msg}`);
    return [];
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
  }
}

async function scrapeViaHtmlFallback(): Promise<ScrapedNewsItem[]> {
  console.log('[BSEK] Trying HTML fallback...');
  
  try {
    const resp = await axios.get(PROD_BASE_URL, {
      timeout: 15000,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (compatible; IlmAI-BoardScraper/1.0; +https://ilmai.app)',
      },
    });

    const html = resp.data as string;
    const linkPattern = /<a[^>]+href=["']([^"']+)["'][^>]*>([^<]+)<\/a>/gi;
    const htmlItems: ScrapedNewsItem[] = [];
    let match: RegExpExecArray | null;
    const seen = new Set<string>();

    while ((match = linkPattern.exec(html)) !== null) {
      const href = match[1];
      const text = cleanText(match[2]);
      if (!text || text.length < 10 || seen.has(text)) continue;
      seen.add(text);

      const isNewsLike = 
        href.includes('press') ||
        href.includes('news') ||
        href.includes('release') ||
        href.includes('notification') ||
        href.includes('circular') ||
        text.toLowerCase().includes('press') ||
        text.toLowerCase().includes('release') ||
        text.toLowerCase().includes('notification') ||
        text.toLowerCase().includes('circular') ||
        text.toLowerCase().includes('exam') ||
        text.toLowerCase().includes('result') ||
        text.toLowerCase().includes('admit') ||
        text.toLowerCase().includes('date sheet');

      if (!isNewsLike) continue;

      const fullUrl = href.startsWith('http') 
        ? href 
        : `https://www.bsek.edu.pk${href.startsWith('/') ? '' : '/'}${href}`;
      htmlItems.push({
        title: text,
        originalUrl: fullUrl,
        source: 'BSEK',
        dateStr: null,
        category: 'General',
        imageUrl: '',
      });
    }

    return htmlItems;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[BSEK] HTML fallback error: ${msg}`);
    return [];
  }
}

export async function scrapeBSEK(): Promise<ScraperResult> {
  console.log('[BSEK] Scraping started...');

  try {
    // Try APIs first (production, then staging)
    const apiItems = await scrapeViaApi();
    if (apiItems.length > 0) {
      return { source: 'BSEK', items: apiItems, error: null };
    }

    // Try Puppeteer for SPA rendering
    const puppeteerItems = await scrapeViaPuppeteer();
    if (puppeteerItems.length > 0) {
      return { source: 'BSEK', items: puppeteerItems, error: null };
    }

    // Fallback to simple HTML scraping
    const htmlItems = await scrapeViaHtmlFallback();
    if (htmlItems.length > 0) {
      return { source: 'BSEK', items: htmlItems, error: null };
    }

    return {
      source: 'BSEK',
      items: [],
      error: 'No news items found on BSEK site via any method.',
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[BSEK] Error: ${msg}`);
    return { source: 'BSEK', items: [], error: msg };
  }
}
