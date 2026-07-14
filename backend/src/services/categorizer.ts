import type { NewsCategory, ScrapedNewsItem } from '../types';

interface CategoryRule {
  patterns: RegExp[];
  category: NewsCategory;
  imageUrl: string;
}

const RULES: CategoryRule[] = [
  {
    patterns: [
      /date\s*sheet/i,
      /time\s*table/i,
      /schedule/i,
      /examination\s*program/i,
      /annual\s*examination/i,
      /paper/i,
      /2nd\s*shift/i,
      /morning\s*shift/i,
      /evening\s*shift/i,
      /practical\s*examination/i,
      /supply/i,
      /failure\s*students/i,
      /special\s*chance/i,
    ],
    category: 'Exams',
    imageUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=600&q=80',
  },
  {
    patterns: [
      /admit\s*card/i,
      /roll\s*number/i,
      /hall\s*ticket/i,
      /enrol(?:l)?ment/i,
      /registration/i,
      /admission/i,
      /affiliation/i,
    ],
    category: 'Admissions',
    imageUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80',
  },
  {
    patterns: [
      /result/i,
      /declared/i,
      /announced/i,
      /gazette/i,
      /position\s*holder/i,
      /topper/i,
      /passing/i,
    ],
    category: 'Results',
    imageUrl: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&q=80',
  },
  {
    patterns: [
      /postpone/i,
      /cancel/i,
      /adjourn/i,
      /defer/i,
      /suspended/i,
      /strike/i,
      /load\s*shedding/i,
      /power\s*outage/i,
    ],
    category: 'Exams',
    imageUrl: 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=600&q=80',
  },
  {
    patterns: [
      /transfer/i,
      /migration/i,
      /equivalence/i,
      /verification/i,
      /certificate/i,
      /provisional/i,
    ],
    category: 'Admissions',
    imageUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&q=80',
  },
  {
    patterns: [
      /model\s*paper/i,
      /scheme\s*of\s*stud(?:y|ies)/i,
      /curriculm/i,
      /syllabus/i,
    ],
    category: 'Exams',
    imageUrl: 'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=600&q=80',
  },
  {
    patterns: [
      /chairman/i,
      /meeting/i,
      /delegation/i,
      /appoint/i,
      /nomination/i,
      /committee/i,
    ],
    category: 'General',
    imageUrl: 'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=600&q=80',
  },
  {
    patterns: [/fake/i, /fraud/i, /scam/i, /social\s*media/i, /awareness/i],
    category: 'General',
    imageUrl: 'https://images.unsplash.com/photo-1563986768609-322da13575f2?w=600&q=80',
  },
  {
    patterns: [/tender/i, /recruitment/i, /job/i, /vacanc/i],
    category: 'General',
    imageUrl: 'https://images.unsplash.com/photo-1574482620811-04b0dcecbc9b?w=600&q=80',
  },
  {
    patterns: [/holiday/i, /vacation/i, /summer\s*vacation/i, /close/i],
    category: 'General',
    imageUrl: 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&q=80',
  },
];

const DEFAULT: { category: NewsCategory; imageUrl: string } = {
  category: 'General',
  imageUrl: 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=600&q=80',
};

export function categorizeItem(item: ScrapedNewsItem): ScrapedNewsItem {
  const searchText = item.title;

  for (const rule of RULES) {
    for (const pattern of rule.patterns) {
      if (pattern.test(searchText)) {
        return {
          ...item,
          category: rule.category,
          imageUrl: rule.imageUrl,
        };
      }
    }
  }

  return {
    ...item,
    category: DEFAULT.category,
    imageUrl: DEFAULT.imageUrl,
  };
}

export function categorizeItems(items: ScrapedNewsItem[]): ScrapedNewsItem[] {
  return items.map(categorizeItem);
}
