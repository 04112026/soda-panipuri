FROM node:22-alpine
WORKDIR /app
# Layer 1: dependency manifest; cache npm install unless it changes
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund
# Layer 2: application code; edits invalidate this layer only
COPY index.js ./
EXPOSE 3000
CMD ["node", "index.js"]
