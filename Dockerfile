# Etapa 1: Dependencias
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

# Etapa 2: Construcción (Builder)
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Desactivar telemetría de Next.js durante el build
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# Etapa 3: Imagen de Producción (Runner)
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Cloud Run inyecta la variable PORT (por defecto 8080)
ENV PORT=8080
ENV HOSTNAME="0.0.0.0"

# Crear usuario sin privilegios para mayor seguridad
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copiar archivos públicos y estáticos requeridos
COPY --from=builder /app/public ./public

# Crear directorio .next y ajustar permisos para la caché
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copiar el paquete standalone generado por Next.js
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 8080

CMD ["node", "server.js"]
