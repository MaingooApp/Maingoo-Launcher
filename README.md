# Maingoo Backend

Backend completo para la plataforma Maingoo. Arquitectura de microservicios con NestJS, NATS, PostgreSQL y Docker.

## 🚀 Quick Start

```bash
# 1. Configurar variables de entorno de cada servicio
cp services/gateway/.env.example services/gateway/.env
cp services/auth/.env.example services/auth/.env
cp services/documents-analyzer/.env.example services/documents-analyzer/.env
cp services/suppliers/.env.example services/suppliers/.env

# Edita documents-analyzer/.env y agrega tu OPENAI_API_KEY

# 2. Levantar todo con Docker Compose
make up         # Levanta infraestructura + microservicios
make migrate    # Ejecutar migraciones (primera vez)
make logs       # Ver logs en tiempo real

# 3. Acceder a los servicios
# Gateway: http://localhost:3000
# NATS Monitor: http://localhost:8222
```

Ver `make help` para todos los comandos disponibles.

## Estructura

```
maingoo-backend/
  docker-compose.yml          # Desarrollo con hot-reload
  docker-compose.prod.yml     # Producción optimizada
  Makefile                    # Todos los comandos disponibles
  services/
    gateway/
      .env                    # Variables de entorno del servicio
      .env.example
      Dockerfile
    auth/
      .env
      .env.example
      Dockerfile
    documents-analyzer/
      .env
      .env.example
      Dockerfile
    suppliers/
      .env
      .env.example
      Dockerfile
```

## Primeros pasos

1. Agrega los submódulos Git:

   ```bash
   git submodule add <GIT_URL_GATEWAY> services/gateway
   git submodule add <GIT_URL_AUTH> services/auth
   git submodule add <GIT_URL_ANALYZER> services/documents-analyzer
   git submodule update --init --recursive
   ```

2. Copia las variables de entorno para cada servicio:

   ```bash
   # Cada microservicio tiene su propio .env
   cp services/gateway/.env.example services/gateway/.env
   cp services/auth/.env.example services/auth/.env
   cp services/documents-analyzer/.env.example services/documents-analyzer/.env
   cp services/suppliers/.env.example services/suppliers/.env
   ```

   > **Nota**: Cada microservicio gestiona su propia configuración.

3. **Desarrollo con Docker Compose**

   Configura la API key de OpenAI:

   ```bash
   cp .env.template .env
   # Edita .env y agrega tu OPENAI_API_KEY
   ```

   Levanta todo (infraestructura + microservicios con hot-reload):

   ```bash
   docker compose up -d
   # o usa: make up
   ```

   Ver logs en tiempo real:

   ```bash
   docker compose logs -f
   # o usa: make logs
   ```

   Las migraciones se deben ejecutar manualmente la primera vez:

   ```bash
   make migrate
   ```

   Detener todo:

   ```bash
   docker compose down
   # o usa: make down
   ```

4. **Desarrollo sin Docker (opcional)**

   Si prefieres ejecutar los servicios localmente:

   ```bash
   # Levanta solo infraestructura
   docker compose up -d nats-server pg-auth pg-analyzer pg-suppliers

   # En terminales separadas, ejecuta cada servicio
   cd services/gateway && npm install && npm run start:dev
   cd services/auth && npm install && npm run start:dev
   cd services/documents-analyzer && npm install && npm run start:dev
   cd services/suppliers && npm install && npm run start:dev
   ```

5. **Producción (Google Cloud)**

   Configura variables de producción:

   ```bash
   cp .env.prod.template .env.prod
   # Edita .env.prod con tus credenciales reales
   ```

   Build y push de imágenes a GCR:

   ```bash
   docker compose -f docker-compose.prod.yml build
   docker compose -f docker-compose.prod.yml push
   ```

   Deploy en Google Cloud:

   ```bash
   docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
   ```

## Servicios

- **gateway**: puerta de entrada HTTP, valida JWT y deriva solicitudes vía NATS.
- **auth**: gestiona usuarios, roles, permisos y tokens.
- **documents-analyzer**: procesa facturas con OpenAI (extracción temporal con IA).
- **suppliers**: gestiona proveedores, facturas y productos (persistencia). Escucha eventos de documents-analyzer.

## Infraestructura

### Contenedores

- **nats-server**: Servidor NATS para comunicación entre microservicios (puertos 4222/8222)
- **pg-auth**: Base de datos PostgreSQL 16 para Auth (puerto 5433)
- **pg-analyzer**: Base de datos PostgreSQL 16 para Documents-Analyzer (puerto 5435)
- **pg-suppliers**: Base de datos PostgreSQL 16 para Suppliers (puerto 5436)
- **gateway**: API Gateway HTTP (puerto 3000)
- **auth**: Microservicio de autenticación (puerto 3001)
- **documents-analyzer**: Microservicio de análisis de documentos (puerto 3002)
- **suppliers**: Microservicio de proveedores (puerto 3003)

Todos los contenedores comparten la red `maingoo-net`.

### Archivos Docker

- `docker-compose.yml`: Desarrollo local con hot-reload
- `docker-compose.prod.yml`: Producción con healthchecks y restart policies
- `services/*/Dockerfile`: Imagen de desarrollo para cada microservicio
- `services/*/.dockerignore`: Excluye node_modules, dist, .env

## Comandos Disponibles (Makefile)

Todos los comandos están centralizados en el `Makefile`. Usa `make help` para ver la lista completa.

### Comandos principales

```bash
# Desarrollo
make up                # Levantar todo con Docker Compose
make down              # Detener contenedores
make logs              # Ver logs en tiempo real
make dev-infra         # Levantar solo infraestructura (NATS + DBs)

# Migraciones
make migrate           # Ejecutar migraciones en todos los servicios
make migrate-auth      # Migrar solo Auth
make migrate-analyzer  # Migrar solo Documents-Analyzer
make migrate-suppliers # Migrar solo Suppliers

# Build y limpieza
make build             # Build de todas las imágenes
make clean             # Limpiar contenedores y volúmenes

# Utilidades
make install           # Instalar dependencias en todos los servicios
make test              # Ejecutar tests en todos los servicios
make format            # Formatear código
make lint              # Lint código

# Producción
make prod-build        # Build imágenes para producción
make prod-push         # Push a Google Container Registry
make prod-up           # Levantar en modo producción
make prod-build        # Build para producción
make prod-up           # Levantar en modo producción
```

## Despliegue en Google Cloud

Ver guía detallada en [`GOOGLE_CLOUD_DEPLOY.md`](./GOOGLE_CLOUD_DEPLOY.md)

Opciones disponibles:

- **Cloud Run**: Serverless, auto-scaling
- **Google Kubernetes Engine (GKE)**: Orquestación completa
- **Compute Engine**: VM tradicional

## Troubleshooting

- **Docker no levanta**: Verifica que Docker Desktop esté activo
- **Error de conexión NATS**: Asegúrate que el puerto 4222 esté libre
- **Error de migración Prisma**: Verifica que las DBs estén corriendo (`docker ps`)
- **Hot-reload no funciona**: Verifica que los volúmenes estén montados correctamente
- **Ver logs**: `make logs` o `docker compose logs -f <servicio>`
- **Revisar eventos NATS**: `docker compose logs -f nats-server`
