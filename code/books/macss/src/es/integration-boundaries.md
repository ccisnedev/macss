# Integraciones y limites operativos

Este capitulo define donde y como MACSS integra base de datos, servicios externos y asincronia.

## Database as Code

1. El esquema vive en codigo declarativo.
2. La base es reproducible y auditable.
3. El acceso se encapsula en Repository.

## Servicios externos

1. Salen por Service en capa server.
2. Se protegen con timeouts, reintentos y circuit breakers cuando aplique.
3. Se observan con logs y metricas.

## Asincronia

MACSS admite asincronia cuando hay necesidad real:

1. eventos para side-effects desacoplados,
2. colas para procesamiento diferido,
3. push para cambios no iniciados por el cliente.

## Limites no negociables

1. La UI no llama terceros directos (salvo auth definido).
2. La logica de negocio no se mueve a middlewares.
3. El contrato publico no se cambia sin versionado y pruebas de compatibilidad.
