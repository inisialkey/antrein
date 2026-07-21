import { newId } from './id';

describe('newId', () => {
  it('produces prefixed Crockford-base32 ULIDs', () => {
    expect(newId('usr')).toMatch(/^usr_[0-9A-HJKMNP-TV-Z]{26}$/);
    expect(newId('bkg')).toMatch(/^bkg_[0-9A-HJKMNP-TV-Z]{26}$/);
  });

  it('produces unique values', () => {
    const ids = new Set(Array.from({ length: 1000 }, () => newId('req')));
    expect(ids.size).toBe(1000);
  });
});
