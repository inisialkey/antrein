import { ulid } from 'ulid';

/**
 * Public ID prefixes per ADR 0010. Extend here as new resources land.
 */
export const ID_PREFIXES = [
  'usr',
  'ses',
  'prt',
  'dev',
  'biz',
  'out',
  'mem',
  'inv',
  'stf',
  'svc',
  'sch',
  'cld',
  'bkg',
  'bsh',
  'pay',
  'evt',
  'ref',
  'que',
  'ntf',
  'rev',
  'fil',
  'adt',
  'idm',
  'obx',
  'req',
] as const;

export type IdPrefix = (typeof ID_PREFIXES)[number];

export function newId(prefix: IdPrefix): string {
  return `${prefix}_${ulid()}`;
}
