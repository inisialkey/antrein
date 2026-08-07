import { extensionFor, normalizeImageMimeType, sniffImageMimeType } from './image-sniff';

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
const webp = Buffer.concat([
  Buffer.from('RIFF', 'latin1'),
  Buffer.from([0x24, 0x00, 0x00, 0x00]),
  Buffer.from('WEBPVP8 ', 'latin1'),
]);

describe('sniffImageMimeType', () => {
  it('identifies the three accepted formats', () => {
    expect(sniffImageMimeType(jpeg)).toBe('image/jpeg');
    expect(sniffImageMimeType(png)).toBe('image/png');
    expect(sniffImageMimeType(webp)).toBe('image/webp');
  });

  it('rejects anything else, including a truncated header', () => {
    expect(sniffImageMimeType(Buffer.from('MZ\x90\x00', 'latin1'))).toBeNull();
    expect(sniffImageMimeType(Buffer.from('GIF89a', 'latin1'))).toBeNull();
    expect(sniffImageMimeType(Buffer.from([0xff, 0xd8]))).toBeNull();
    expect(sniffImageMimeType(Buffer.alloc(0))).toBeNull();
  });

  it('does not accept a RIFF container that is not WebP', () => {
    const wav = Buffer.concat([
      Buffer.from('RIFF', 'latin1'),
      Buffer.from([0x24, 0x00, 0x00, 0x00]),
      Buffer.from('WAVEfmt ', 'latin1'),
    ]);
    expect(sniffImageMimeType(wav)).toBeNull();
  });
});

describe('normalizeImageMimeType', () => {
  it('folds the image/jpg spelling and casing', () => {
    expect(normalizeImageMimeType('IMAGE/JPG')).toBe('image/jpeg');
    expect(normalizeImageMimeType(' image/png ')).toBe('image/png');
  });
});

describe('extensionFor', () => {
  it('maps each accepted type to a storage extension', () => {
    expect(extensionFor('image/jpeg')).toBe('jpg');
    expect(extensionFor('image/png')).toBe('png');
    expect(extensionFor('image/webp')).toBe('webp');
  });
});
