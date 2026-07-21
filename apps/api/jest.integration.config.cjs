/** Integration tests — require a running PostgreSQL (see Makefile test-integration) */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.integration.spec.ts'],
  testTimeout: 30000,
  setupFiles: ['reflect-metadata'],
};
