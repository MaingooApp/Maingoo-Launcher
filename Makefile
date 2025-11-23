.PHONY: help dev-infra db-only build up down restart logs clean migrate migrate-auth migrate-analyzer migrate-suppliers migrate-enterprises seed prod-build prod-push prod-up prod-down prod-logs test test-gateway test-auth test-analyzer test-suppliers test-enterprises prisma-generate prisma-studio-auth prisma-studio-analyzer prisma-studio-suppliers prisma-studio-enterprises install format lint gateway-dev auth-dev analyzer-dev suppliers-dev enterprises-dev

# Variables
GCP_PROJECT_ID ?= your-gcp-project-id
IMAGE_TAG ?= latest

help: ## Mostrar esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================
# Docker Compose
# ============================================

build: ## Build de todas las imágenes Docker
	@echo "🔨 Building Docker images..."
	docker compose build

up: ## Levantar todo con Docker Compose (infraestructura + microservicios)
	@echo "⬆️  Starting all services..."
	docker compose up -d

dev-infra: ## Levantar solo infraestructura (NATS + DBs)
	@echo "🗄️  Levantando infraestructura..."
	docker compose up -d nats-server pg-auth pg-analyzer pg-suppliers pg-enterprises

db-only: ## Levantar solo las bases de datos PostgreSQL
	@echo "💾 Levantando solo bases de datos..."
	docker compose up -d pg-auth pg-analyzer pg-suppliers pg-enterprises

migrate: ## Ejecutar migraciones de Prisma en todos los servicios con BD
	@echo "📦 Ejecutando migraciones Prisma en contenedores..."
	@docker exec maingoo-auth npx prisma generate
	@docker exec maingoo-auth npx prisma db push
	@docker exec maingoo-documents-analyzer npx prisma generate
	@docker exec maingoo-documents-analyzer npx prisma db push
	@docker exec maingoo-suppliers npx prisma generate
	@docker exec maingoo-suppliers npx prisma db push
	@docker exec maingoo-enterprises npx prisma generate
	@docker exec maingoo-enterprises npx prisma db push
	@docker exec maingoo-products npx prisma generate
	@docker exec maingoo-products npx prisma db push
	@echo "✅ Migraciones completadas"

migrate-auth: ## Ejecutar migraciones solo en Auth
	@echo "📦 Migrando Auth..."
	@docker exec maingoo-auth npx prisma generate
	@docker exec maingoo-auth npx prisma db push

migrate-analyzer: ## Ejecutar migraciones solo en Documents-Analyzer
	@echo "📦 Migrando Documents-Analyzer..."
	@docker exec maingoo-documents-analyzer npx prisma generate
	@docker exec maingoo-documents-analyzer npx prisma db push

migrate-suppliers: ## Ejecutar migraciones solo en Suppliers
	@echo "📦 Migrando Suppliers..."
	@docker exec maingoo-suppliers npx prisma generate
	@docker exec maingoo-suppliers npx prisma db push

migrate-enterprises: ## Ejecutar migraciones solo en Enterprises
	@echo "📦 Migrando Enterprises..."
	@docker exec maingoo-enterprises npx prisma generate
	@docker exec maingoo-enterprises npx prisma db push

down: ## Detener todos los contenedores
	@echo "⬇️  Stopping all services..."
	docker compose down

restart: ## Reiniciar todos los servicios
	@echo "🔄 Restarting all services..."
	docker compose restart

logs: ## Ver logs de todos los servicios
	docker compose logs -f

clean: ## Limpiar contenedores, volúmenes e imágenes
	@echo "🧹 Cleaning up..."
	docker compose down -v
	docker system prune -f

# ============================================
# Producción
# ============================================

prod-build: ## Build imágenes para producción
	@echo "🏗️  Building production images..."
	docker compose -f docker-compose.prod.yml build

prod-push: ## Push imágenes a Google Container Registry
	@echo "⬆️  Pushing images to GCR..."
	docker tag maingoo-gateway gcr.io/$(GCP_PROJECT_ID)/maingoo-gateway:$(IMAGE_TAG)
	docker tag maingoo-auth gcr.io/$(GCP_PROJECT_ID)/maingoo-auth:$(IMAGE_TAG)
	docker tag maingoo-documents-analyzer gcr.io/$(GCP_PROJECT_ID)/maingoo-documents-analyzer:$(IMAGE_TAG)
	docker tag maingoo-suppliers gcr.io/$(GCP_PROJECT_ID)/maingoo-suppliers:$(IMAGE_TAG)
	docker push gcr.io/$(GCP_PROJECT_ID)/maingoo-gateway:$(IMAGE_TAG)
	docker push gcr.io/$(GCP_PROJECT_ID)/maingoo-auth:$(IMAGE_TAG)
	docker push gcr.io/$(GCP_PROJECT_ID)/maingoo-documents-analyzer:$(IMAGE_TAG)
	docker push gcr.io/$(GCP_PROJECT_ID)/maingoo-suppliers:$(IMAGE_TAG)

prod-up: ## Levantar en modo producción
	@echo "🚀 Starting production environment..."
	docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

prod-down: ## Detener producción
	@echo "⬇️  Stopping production environment..."
	docker compose -f docker-compose.prod.yml down

prod-logs: ## Ver logs de producción
	docker compose -f docker-compose.prod.yml logs -f

# ============================================
# Desarrollo Individual por Servicio
# ============================================

gateway-dev: ## Iniciar solo Gateway en desarrollo
	cd services/gateway && npm install && npm run start:dev

auth-dev: ## Iniciar solo Auth en desarrollo
	cd services/auth && npm install && npm run start:dev

analyzer-dev: ## Iniciar solo Documents-Analyzer en desarrollo
	cd services/documents-analyzer && npm install && npm run start:dev

suppliers-dev: ## Iniciar solo Suppliers en desarrollo
	cd services/suppliers && npm install && npm run start:dev

# ============================================
# Testing
# ============================================

test: ## Ejecutar tests en todos los servicios
	@echo "🧪 Running tests..."
	cd services/gateway && npm test
	cd services/auth && npm test
	cd services/documents-analyzer && npm test
	cd services/suppliers && npm test

test-gateway: ## Test solo Gateway
	cd services/gateway && npm test

test-auth: ## Test solo Auth
	cd services/auth && npm test

test-analyzer: ## Test solo Documents-Analyzer
	cd services/documents-analyzer && npm test

test-suppliers: ## Test solo Suppliers
	cd services/suppliers && npm test

# ============================================
# Prisma
# ============================================

prisma-generate: ## Generar Prisma Client en todos los servicios (en contenedores)
	@echo "🔄 Generating Prisma Clients..."
	@docker exec maingoo-auth npx prisma generate
	@docker exec maingoo-documents-analyzer npx prisma generate
	@docker exec maingoo-suppliers npx prisma generate
	@docker exec maingoo-products npx prisma generate
	@docker exec maingoo-enterprises npx prisma generate
	@echo "✅ Prisma Clients generados"

prisma-studio-auth: ## Abrir Prisma Studio para Auth (en contenedor)
	@echo "🎨 Abriendo Prisma Studio para Auth en http://localhost:5555"
	@docker exec -it maingoo-auth npx prisma studio

prisma-studio-analyzer: ## Abrir Prisma Studio para Documents-Analyzer (en contenedor)
	@echo "🎨 Abriendo Prisma Studio para Documents-Analyzer en http://localhost:5555"
	@docker exec -it maingoo-documents-analyzer npx prisma studio

prisma-studio-suppliers: ## Abrir Prisma Studio para Suppliers (en contenedor)
	@echo "🎨 Abriendo Prisma Studio para Suppliers en http://localhost:5555"
	@docker exec -it maingoo-suppliers npx prisma studio

seed: ## Ejecutar seeds de Prisma (roles, permisos, datos iniciales)
	@echo "🌱 Ejecutando seeds..."
	@docker exec maingoo-auth npx ts-node prisma/seed.ts
	@echo "✅ Seeds completados"

# ============================================
# Utilidades
# ============================================

install: ## Instalar dependencias en todos los servicios
	@echo "📥 Installing dependencies..."
	cd services/gateway && npm install
	cd services/auth && npm install
	cd services/documents-analyzer && npm install
	cd services/suppliers && npm install

format: ## Formatear código con Prettier
	@echo "✨ Formatting code..."
	cd services/gateway && npm run format
	cd services/auth && npm run format
	cd services/documents-analyzer && npm run format
	cd services/suppliers && npm run format

lint: ## Lint código con ESLint
	@echo "🔍 Linting code..."
	cd services/gateway && npm run lint
	cd services/auth && npm run lint
	cd services/documents-analyzer && npm run lint
	cd services/suppliers && npm run lint
