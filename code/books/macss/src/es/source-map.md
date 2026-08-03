# Source map y trazabilidad

Este apendice mapea el material canonico actual contra la estructura vigente del libro.

Primary architecture docs:

- docs/architecture.md
- docs/roadmap.md

Specification contracts:

- ninguno vigente. `docs/spec/` no existe; los contratos de comando viven en el
  propio CLI, como parametros declarados, y en `docs/architecture.md`.

Architecture analysis corpus:

- migrated into book chapters listed below

Book chapter filenames:

- descriptive slugs only, no numeric prefix
- SUMMARY.md controls reading order exclusively, para todos los idiomas
- cada slug resuelve a `src/<lang>/<slug>.md`
- insert or remove chapters by editing SUMMARY.md only

Rutas relativas a la raiz del repositorio, no a este archivo: el capitulo vive
en `code/books/macss/src/es/` y contar niveles hacia arriba se rompe cada vez
que el libro se mueve.

Migrado a capitulos activos del libro:

- docs/analyse/architecture_research.md -> Parte I y Parte II
- docs/analyse/lengua_macss.md -> glossary
- docs/analyse/testing.md -> testing-and-gates
- docs/analyse/chapters.md -> SUMMARY.md

ADR log:

- docs/adr/

Ecosystem companion tooling outside this repository:

- ../../../devops/README.md (`macss-devops` PowerShell module)

Politica editorial:

- El libro es la narrativa tecnica viva de arquitectura e ingenieria.
- Los specs siguen siendo normativos para contratos ejecutables.
- Los ADRs siguen siendo la bitacora de decisiones.
- Los modulos complementarios pueden vivir en repos hermanos si preservan la arquitectura MACSS.
