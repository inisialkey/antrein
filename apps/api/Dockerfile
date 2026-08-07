# syntax=docker/dockerfile:1
# Build context is apps/api. backend-brief §91: multi-stage, production
# dependencies only, non-root, health check, no embedded secrets.

FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# tsconfig must exist before `prisma generate`: the client generator reads it to
# pick its module format. Without it the client is emitted as ESM with `.ts`
# import specifiers, which then dies at runtime under CommonJS.
COPY tsconfig.json tsconfig.build.json nest-cli.json prisma.config.ts ./
COPY prisma ./prisma
# prisma.config.ts resolves DATABASE_URL eagerly; generate never connects, so a
# throwaway value satisfies the config loader without baking a secret in.
RUN DATABASE_URL=postgresql://build:build@localhost:5432/build npx prisma generate

COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000

# The pruned production tree still contains the prisma CLI (@prisma/client@7
# depends on it), so the one-shot migrate service runs `prisma migrate deploy`
# from this same image — ADR 0045 §5.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package.json prisma.config.ts ./

# Uploaded images (ADR 0046). Creating the directory here — owned by `node` —
# makes the named volume mounted over it inherit that ownership, which is what
# lets the non-root process write to it.
RUN mkdir -p /data/storage && chown -R node:node /data

ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="antrein-api" \
      org.opencontainers.image.source="https://github.com/inisialkey/antrein" \
      org.opencontainers.image.revision="${GIT_SHA}"

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -q --spider "http://127.0.0.1:${PORT}/health/live" || exit 1

CMD ["node", "dist/main.js"]
