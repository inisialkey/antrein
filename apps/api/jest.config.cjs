/** Unit tests only; integration specs run via jest.integration.config.cjs */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/src/**/*.spec.ts'],
  testPathIgnorePatterns: ['\\.integration\\.spec\\.ts$'],
  setupFiles: ['reflect-metadata'],
};
