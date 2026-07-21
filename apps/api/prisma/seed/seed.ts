/**
 * Development seed data. Never runs automatically; invoked via `make seed`.
 * Demo users land here with the auth module (M2) — password hashing is not
 * available before then.
 */
async function main(): Promise<void> {
  process.stdout.write('No seed data yet (first seedable module arrives with M2 auth).\n');
}

void main();
