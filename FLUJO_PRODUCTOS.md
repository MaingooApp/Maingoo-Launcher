# 📦 Integración de Productos en el Flujo de Facturas

## Resumen

Este documento describe cómo se integró el microservicio de productos en el flujo de análisis de facturas para crear un catálogo centralizado de productos.

## 🎯 Objetivo

Cuando un usuario sube una factura y el sistema extrae los productos, queremos:

1. ✅ Buscar cada producto en el catálogo por nombre o EAN
2. ✅ Si no existe, crearlo automáticamente
3. ✅ Vincular el producto a la línea de la factura
4. ✅ Permitir análisis de compras y comparación de precios

## 🔄 Flujo Completo

```
┌──────────────┐
│   Usuario    │
│  (iPhone)    │
└──────┬───────┘
       │ 1. Sube foto de factura
       ▼
┌──────────────────┐
│    Gateway       │  POST /api/analyze/invoice
└────────┬─────────┘
         │ 2. Envía a analyzer
         ▼
┌──────────────────────────┐
│ Documents-Analyzer       │
│                          │
│ 3. Extrae con Azure AI:  │
│    - Proveedor           │
│    - Total               │
│    - Líneas:             │
│      * Descripción       │
│      * Cantidad          │
│      * Precio            │
│      * EAN (si existe)   │
└────────┬─────────────────┘
         │ 4. Emite: documents.analyzed
         │    {documentId, extraction: {...}}
         ▼
┌────────────────────────────────────┐
│ Suppliers Service                  │
│                                    │
│ 5. Escucha evento                  │
│ 6. Para cada línea:                │
│    ┌────────────────────────┐     │
│    │ Llama a Products MS:   │     │◄────┐
│    │ findOrCreate({         │     │     │
│    │   name: "Aceite OV",   │     │     │
│    │   eanCode: "8412..."   │     │     │
│    │ })                     │     │     │
│    └────────────────────────┘     │     │
│                                    │     │
│ 7. Recibe masterProductId          │     │
│ 8. Crea factura con líneas:        │     │
│    - description: "Aceite OV"      │     │
│    - masterProductId: "uuid-123"   │     │
│    - quantity: 2                   │     │
│    - unitPrice: 15.50              │     │
└────────┬───────────────────────────┘     │
         │ 9. Emite: invoice.processed     │
         │    {documentId, invoiceId}      │
         ▼                                  │
┌──────────────────────────┐                │
│ Documents-Analyzer       │                │
│                          │                │
│ 10. Vincula invoiceId    │                │
│     al documento         │                │
└──────────────────────────┘                │
                                            │
                                            │
                     ┌──────────────────────┤
                     │ Products MS          │
                     │                      │
                     │ Busca producto:      │
                     │ 1. Por EAN           │
                     │ 2. Por nombre        │
                     │                      │
                     │ Si no existe:        │
                     │ - Crea nuevo         │
                     │ - Categoría "Otros"  │
                     │ - Unidad: "Unidad"   │
                     │                      │
                     │ Retorna:             │
                     │ { id, name, ... }    │
                     └──────────────────────┘
```

## 🛠️ Cambios Realizados

### 1. Products Microservice

**Archivo**: `services/products/src/config/subjects.ts`

- ✅ Agregado: `findOrCreate = 'products.findOrCreate'`

**Archivo**: `services/products/src/modules/products/products.controller.ts`

- ✅ Agregado endpoint NATS: `@MessagePattern(ProductsSubjects.findOrCreate)`

**Archivo**: `services/products/src/modules/products/products.service.ts`

- ✅ Nuevo método: `findOrCreate(data: { name, eanCode?, categoryName? })`
  - Busca por EAN (si se proporciona)
  - Busca por nombre (case-insensitive)
  - Si no existe, crea el producto con categoría "Otros"
  - Retorna el producto con su ID

### 2. Suppliers Microservice

**Archivo**: `services/suppliers/src/config/services.ts`

- ✅ Agregado: `ProductsSubjects = { findOrCreate: 'products.findOrCreate' }`

**Archivo**: `services/suppliers/prisma/schema.prisma`

- ✅ Modelo `InvoiceLine`:
  - Agregado campo: `masterProductId String?`
  - Agregado índice: `@@index([masterProductId])`

**Archivo**: `services/suppliers/src/modules/events/documents-event.handler.ts`

- ✅ Importado: `firstValueFrom` de rxjs
- ✅ Nuevo método: `processInvoiceLines()` que:
  1. Itera sobre cada línea de la factura
  2. Llama a Products MS con `client.send()`
  3. Obtiene el `masterProductId`
  4. Retorna líneas con el producto vinculado
- ✅ Actualizado: `handleDocumentAnalyzed()` para usar `processInvoiceLines()`

**Archivo**: `services/suppliers/src/modules/invoices/invoices.service.ts`

- ✅ Interface `CreateInvoicePayload.lines`:
  - Agregado: `masterProductId?: string`
- ✅ Método `createInvoice()`:
  - Ahora guarda `masterProductId` en cada línea

### 3. Documentación

**Archivo**: `README.md`

- ✅ Agregada sección: "📦 Flujo de Análisis de Facturas con Productos"
- ✅ Actualizada lista de servicios (agregado products:3004)
- ✅ Actualizada lista de bases de datos (agregado pg-products:5438)

**Archivo**: `services/suppliers/README.md`

- ✅ Actualizada sección: "Auto-create Flow with Products Integration"
- ✅ Agregado diagrama de flujo ASCII
- ✅ Actualizada tabla de eventos consumidos
- ✅ Agregada tabla: "Calls to Other Services"
- ✅ Actualizado schema de `InvoiceLine` con `masterProductId`

**Archivo**: `services/gateway/postman/Maingoo-Gateway-API.postman_collection.json`

- ✅ Agregadas 3 carpetas nuevas:
  - **Products** (6 endpoints)
  - **Categories** (5 endpoints)
  - **Allergens** (5 endpoints)
- ✅ Variables agregadas: `product_id`, `category_id`, `allergen_id`

## 📊 Base de Datos

### Migración Requerida

```bash
cd services/suppliers
npx prisma migrate dev --name add_master_product_id_to_invoice_line
```

Esto agrega:

```sql
ALTER TABLE "InvoiceLine"
ADD COLUMN "masterProductId" TEXT;

CREATE INDEX "InvoiceLine_masterProductId_idx"
ON "InvoiceLine"("masterProductId");
```

## 🚀 Cómo Probar

1. **Levantar todos los servicios**:

   ```bash
   docker-compose up -d
   ```

2. **Ejecutar migraciones**:

   ```bash
   # Suppliers
   docker-compose exec suppliers npx prisma migrate dev

   # Products (ejecutar seed para categorías)
   docker-compose exec products npx prisma migrate dev
   docker-compose exec products npx prisma db seed
   ```

3. **Subir una factura**:

   ```bash
   # Desde Postman o curl
   POST http://localhost:3000/api/analyze/invoice
   Headers: Authorization: Bearer <token>
   Body: form-data
     - file: [imagen de factura]
     - notes: "Test de productos"
   ```

4. **Verificar el flujo**:

   ```bash
   # Ver logs de cada servicio
   docker-compose logs -f documents-analyzer
   docker-compose logs -f suppliers
   docker-compose logs -f products
   ```

5. **Consultar la factura creada**:

   ```bash
   GET http://localhost:3000/api/suppliers/invoices/{invoiceId}
   ```

   Verás las líneas con `masterProductId` vinculado:

   ```json
   {
     "id": "cm3abc...",
     "invoiceLines": [
       {
         "id": "cm3xyz...",
         "description": "Aceite de Oliva Virgen Extra",
         "masterProductId": "cm3prod123",
         "quantity": 2,
         "unitPrice": 15.5,
         "price": 31.0
       }
     ]
   }
   ```

6. **Ver productos creados**:
   ```bash
   GET http://localhost:3000/api/products
   ```

## 🎉 Beneficios

1. **Catálogo Centralizado**:

   - Todos los productos en un solo lugar
   - Evita duplicados por nombre o EAN

2. **Análisis de Compras**:

   - Ver qué productos se compran más
   - Comparar precios entre proveedores
   - Identificar tendencias

3. **Gestión de Alérgenos**:

   - Cada producto tiene alérgenos asociados
   - Útil para restaurants con menús especiales

4. **Automatización**:

   - No requiere intervención manual
   - Los productos se crean automáticamente
   - Vinculación transparente

5. **Escalabilidad**:
   - Microservicios independientes
   - Comunicación asíncrona vía NATS
   - Fácil de extender

## 🔍 Próximos Pasos

1. ✅ **Dashboard de Productos**: Ver productos más comprados
2. ✅ **Alertas de Precio**: Notificar cuando un producto sube de precio
3. ✅ **Sugerencias**: ML para sugerir productos similares más baratos
4. ✅ **Estadísticas**: Gráficos de consumo por categoría
5. ✅ **Integración Inventario**: Vincular con stock disponible

## 📝 Notas Técnicas

- **No Foreign Keys**: `masterProductId` es un String sin FK por diseño de microservicios
- **Idempotencia**: `findOrCreate` evita duplicados automáticamente
- **Error Handling**: Si falla la búsqueda de producto, la factura se crea igual (sin masterProductId)
- **Performance**: Llamadas paralelas posibles (futuro: batch findOrCreate)
- **Categoría Default**: Si no se detecta categoría, usa "Otros"
