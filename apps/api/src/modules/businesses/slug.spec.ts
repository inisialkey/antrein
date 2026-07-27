import { slugify, withSuffix } from './slug';

describe('slugify', () => {
  it('lowercases and hyphenates', () => {
    expect(slugify('AntreIn Barbershop')).toBe('antrein-barbershop');
  });

  it('strips punctuation and collapses separators', () => {
    expect(slugify("Pak Oki's  Cukur & Co.")).toBe('pak-oki-s-cukur-co');
  });

  it('strips diacritics', () => {
    expect(slugify('Café Résumé')).toBe('cafe-resume');
  });

  it('falls back when nothing survives', () => {
    expect(slugify('!!!')).toBe('business');
  });
});

describe('withSuffix', () => {
  it('keeps the base on the first attempt, then numbers from 2', () => {
    expect(withSuffix('barber', 0)).toBe('barber');
    expect(withSuffix('barber', 1)).toBe('barber-2');
    expect(withSuffix('barber', 4)).toBe('barber-5');
  });
});
