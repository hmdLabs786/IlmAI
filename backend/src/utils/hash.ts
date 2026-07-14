import { createHash } from 'crypto';

export function md5Hash(input: string): string {
  return createHash('md5').update(input).digest('hex');
}

export function generateDocumentId(title: string, source: string): string {
  return md5Hash(`${source}::${title}`);
}
