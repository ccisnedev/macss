# Principios nucleares y trade-offs

MACSS define un conjunto corto de principios para mantener coherencia a escala.

## Principios

1. Fronteras modulares fuertes.
2. Contratos explicitos y verificables.
3. Especificacion ejecutable (tests + gates).
4. Separacion de preocupaciones transversales mediante plugins.
5. Evolucion controlada con trazabilidad arquitectonica.

## Trade-offs explicitos

1. Se sacrifica libertad local para ganar legibilidad global.
2. Se privilegia consistencia de contratos sobre atajos de implementacion.
3. Se acepta mayor disciplina inicial para reducir deuda evolutiva.

Estos principios se aplican de forma uniforme en `db`, `api`, `app/cli` e `infra`.
