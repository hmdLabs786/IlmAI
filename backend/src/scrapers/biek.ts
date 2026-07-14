import axios from 'axios';
import * as cheerio from 'cheerio';
import type { ScrapedNewsItem, ScraperResult } from '../types';
import { cleanText, cleanTitle, extractDateFromText } from '../utils/sanitizer';

const BASE_URL = 'https://www.biek.edu.pk';
const TARGET_URL = `${BASE_URL}/press_release.asp`;

function resolveUrl(href: string): string {
  if (!href || href.startsWith('http')) return href || BASE_URL;
  if (href.startsWith('/')) return `${BASE_URL}${href}`;
  if (href.startsWith('./')) return `${BASE_URL}/${href.slice(2)}`;
  if (href.startsWith('../')) return `${BASE_URL}/${href.replace(/^\.\.\//, '')}`;
  if (href.startsWith('#')) return TARGET_URL;
  return `${BASE_URL}/${href}`;
}

function parseRow($: cheerio.CheerioAPI, el: any): ScrapedNewsItem | null {
  const $container = $(el);

  const titleTextEl = $container.find('.ts-title-boxed .ts-message-content p').first();
  const linkEl = $container.find('.ts-content-boxed p a').first();
  const linkHref = linkEl.attr('href');
  const linkText = cleanText(linkEl.text());

  const rawTitle = cleanText(titleTextEl.text());
  const dateStr = extractDateFromText(rawTitle);

  let title = cleanTitle(linkText || rawTitle);
  if (!title || title.length < 5) {
    title = cleanText(rawTitle);
  }
  if (!title || title.length < 5) return null;

  const originalUrl = linkHref ? resolveUrl(linkHref) : TARGET_URL;

  return {
    title,
    originalUrl,
    source: 'BIEK',
    dateStr,
    category: 'General',
    imageUrl: '',
  };
}

export async function scrapeBIEK(): Promise<ScraperResult> {
  console.log('[BIEK] Scraping started...');

  try {
    const response = await axios.get(TARGET_URL, {
      timeout: 20000,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        Accept:
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ur;q=0.8',
      },
    });

    const $ = cheerio.load(response.data);
    const items: ScrapedNewsItem[] = [];
    const seenTitles = new Set<string>();

    $('.ts-message-boxed.success').each((_i, el) => {
      const item = parseRow($, el);
      if (item && !seenTitles.has(item.title)) {
        seenTitles.add(item.title);
        items.push(item);
      }
    });

    console.log(`[BIEK] Found ${items.length} press releases`);

    return {
      source: 'BIEK',
      items,
      error: items.length === 0 ? 'No press release items found on BIEK page.' : null,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[BIEK] Error: ${msg}`);
    return { source: 'BIEK', items: [], error: msg };
  }
}
