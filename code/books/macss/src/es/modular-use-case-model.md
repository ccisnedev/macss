# Modelo modular por caso de uso

La unidad central de MACSS es el UseCase. No el endpoint, no la tabla, no el controlador.

## Regla principal

Cada operacion de negocio relevante debe representarse como un UseCase con contrato explicito.

## Componentes del modelo

1. Input DTO: define y valida entradas.
2. Output DTO: define forma de salida.
3. UseCase: ejecuta reglas de negocio.
4. Repository: encapsula persistencia.
5. API route: expone transporte.

## Fronteras

1. Un UseCase no contiene transporte HTTP.
2. Un UseCase no conoce detalles de UI.
3. Un UseCase delega IO a Repository o Service.

## Beneficios

1. testeabilidad por unidad de negocio,
2. trazabilidad contrato -> codigo -> pruebas,
3. extraccion de modulos con bajo costo,
4. paridad consistente entre SDKs.

## Ejemplo de convencion (Dart)

```text
api/modules/orders/
  dtos/order_create_input.dart
  dtos/order_create_output.dart
  usecases/order_create_usecase.dart
  repositories/orders_repository.dart
  routes/orders_routes.dart
```

Esta estructura expresa arquitectura de manera legible para humanos y agentes AI.
