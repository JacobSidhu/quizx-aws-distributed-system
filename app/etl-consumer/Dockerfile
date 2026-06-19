FROM node:24-alpine

WORKDIR /app

ENV NODE_ENV=production

COPY src/package*.json ./
RUN npm ci --omit=dev

COPY src/ ./

USER node

CMD ["node", "consumer.js"]
