# Stage 1: Builder
FROM node:18-alpine AS builder
WORKDIR /app

# Install required build dependencies
RUN apk add --no-cache python3 make g++

# Copy only package files first for efficient caching
COPY package*.json ./

# Install dependencies based on lock file
RUN npm ci

# Copy rest of the project files
COPY . .

# Build the Next.js application
RUN npm run build

# Stage 2: Runner
FROM node:18-alpine AS runner
WORKDIR /app

# Copy build output and required files from builder
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Environment setup
ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Start application
CMD ["node", "server.js"]
