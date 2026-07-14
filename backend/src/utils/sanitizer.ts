export function cleanText(text: string): string {
  return text
    .replace(/\r\n/g, ' ')
    .replace(/\n/g, ' ')
    .replace(/\t/g, ' ')
    .replace(/\s{2,}/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .trim();
}

export function cleanTitle(text: string): string {
  return cleanText(text)
    .replace(/^Press\s*Release\s*/i, '')
    .replace(/^Press\s*[-]?\s*/i, '')
    .replace(/^Notification\s*/i, '')
    .trim();
}

export function extractDateFromText(text: string): string | null {
  const patterns = [
    /Dated:\s*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})/i,
    /dated\s+(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})/i,
    /(\d{1,2}[-/]\d{1,2}[-/]\d{4})/,
  ];

  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match && match[1]) {
      return match[1];
    }
  }

  return null;
}
