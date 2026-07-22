# ADR 0035 — MVP runtime topology: inline worker locally, Redis optional everywhere

- **Status:** Accepted
- **Date:** 2026-07-22

Local development runs the outbox/jobs worker inside the API process behind `WORKER_MODE=inline`; staging and production run it as a separate container from the same image with a worker command (`node dist/worker.js`). Redis is optional in every MVP environment: rate limiting uses an in-memory store (correct for the single-instance topology), no cache layer until measured, readiness never checks Redis, and `REDIS_URL` is optional config. Redis (and the Socket.IO adapter, ADR 0030) becomes mandatory at the moment instance count exceeds one — that flip is the documented scaling step.

Rejected: always-separate worker locally (process overhead for zero async volume) and Redis-mandatory staging (hard dependency exercising nothing a single instance needs).
