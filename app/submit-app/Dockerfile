FROM node:24-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4200

COPY src/package*.json ./
RUN npm ci --omit=dev

COPY src/ ./
COPY public/ ../public/

USER node

EXPOSE 4200

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:4200/health').then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "server.js"]
