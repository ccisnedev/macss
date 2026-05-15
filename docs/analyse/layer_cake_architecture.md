# Layer Cake Architecture

> "Where you serve vertical slices."

---

## Abstract

Layer Cake Architecture es el modelo visual y estructural que describe la organización de un sistema MACSS: capas horizontales apiladas (como un pastel) y rebanadas verticales (slices) que atraviesan todas las capas incluyendo la base. Este documento fundamenta el modelo con referencias verificables a la literatura de ingeniería de software.

---

## 1. Antecedentes: Arquitectura en capas

### 1.1 El patrón Layers

El patrón **Layers** aparece formalmente en:

> Buschmann, F., Meunier, R., Rohnert, H., Sommerlad, P., & Stal, M. (1996). *Pattern-Oriented Software Architecture, Volume 1: A System of Patterns*. Wiley. pp. 31–51.

Define una descomposición jerárquica donde cada capa:
- Usa solo servicios de la capa inmediatamente inferior
- No conoce la existencia de capas superiores
- Tiene una responsabilidad cohesiva

### 1.2 El modelo de cuatro capas de Evans

> Evans, E. (2003). *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley. Chapter 4, "Isolating the Domain", pp. 68–74.

Evans propone cuatro capas:

| Capa | Responsabilidad |
|------|----------------|
| User Interface | Presentación y entrada del usuario |
| Application | Orquestación de casos de uso |
| Domain | Lógica de negocio pura |
| Infrastructure | Persistencia, mensajería, frameworks |

### 1.3 Clean Architecture

> Martin, R. C. (2017). *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall. Part V, Chapters 20–22.

Reorganiza las capas en círculos concéntricos con la **Dependency Rule**: las dependencias apuntan hacia adentro (hacia el dominio). La capa externa (frameworks/UI) depende de la interna (entidades), nunca al revés.

### 1.4 Hexagonal Architecture (Ports & Adapters)

> Cockburn, A. (2005). "Hexagonal Architecture." *alistair.cockburn.us/hexagonal-architecture/*

Propone que la aplicación expone **puertos** (interfaces) y se conecta al mundo exterior mediante **adaptadores**. Elimina la distinción arriba/abajo, pero mantiene la separación de concerns.

---

## 2. Vertical Slice Architecture

### 2.1 Origen

El término **Vertical Slice Architecture** fue popularizado por Jimmy Bogard a partir de 2018:

> Bogard, J. (2018). "Vertical Slice Architecture." *jimmybogard.com/vertical-slice-architecture/*

> Bogard, J. (2019). "Vertical Slice Architecture" [Conference talk]. NDC Sydney 2019. Disponible en YouTube.

### 2.2 Definición

En lugar de organizar por capa técnica (`Controllers/`, `Services/`, `Repositories/`), se organiza por **feature** — cada slice contiene todo lo necesario para una funcionalidad:

```
Feature: CreateOrder
├── CreateOrderCommand.cs      ← input
├── CreateOrderHandler.cs      ← logic
├── CreateOrderValidator.cs    ← validation
└── CreateOrderResponse.cs     ← output
```

### 2.3 Relación con MACSS

MACSS **no sigue** la estructura de Bogard (todo en una carpeta). MACSS mantiene la separación por capas pero adopta el **concepto** de slice:

- Bogard: slice = carpeta que contiene todas las capas mezcladas
- MACSS: slice = unión lógica de módulos homónimos, cada uno en su capa

```
slice "orders" = db/modules/orders/
               + api/modules/orders/
               + app/modules/orders/
               + infra/  (configuración)
```

El slice en MACSS es una restricción de coherencia, no una carpeta.

---

## 3. La metáfora "Layer Cake"

### 3.1 Uso previo del término

El término "layer cake" aparece en múltiples contextos de software:

- **Android architecture**: el stack se describe como un "layer cake" (Linux kernel → HAL → Android Runtime → Framework → Apps). Ver: Android Open Source Project documentation.
- **Networking**: el modelo OSI de 7 capas se visualiza frecuentemente como un pastel de capas. Ver: Tanenbaum, A. S. (2010). *Computer Networks*, 5th ed. Pearson. Chapter 1.
- **Web stack**: LAMP/MEAN stacks se diagraman como capas apiladas.

### 3.2 Diferencia con uso previo

En usos anteriores, "layer cake" es solo una visualización. En MACSS, **Layer Cake Architecture** es el modelo operativo:

| Aspecto | Uso informal | MACSS |
|---------|-------------|-------|
| Metáfora | Visual | Estructural + visual |
| Corte vertical | No definido | Slice = unidad de trabajo |
| Plato | No existe | infra/ = soporte no-funcional |
| Capas adicionales | Fijas | Extensibles (cli/, site/, book/) |

### 3.3 El pastel como identidad

La decisión de usar el pastel como **identidad de marca** (no solo como diagrama) es original. No existe en el ecosistema de developer tooling un producto cuya marca sea literalmente un pastel de capas. Esto lo hace:

- **Memorable**: imagen concreta, no abstracta
- **Auto-explicativo**: comunica la arquitectura sin texto
- **Extensible**: nuevas capas = nuevo sabor/textura

---

## 4. El modelo Layer Cake de MACSS

### 4.1 Anatomía

```
          🍒  ← cereza verde (calidad)
    ┌───────────────┐
    │ ░░░░░░░░░░░░░ │  frosting   →  app/     (presentación)
    ├───────────────┤
    │ ▓▓▓▓▓▓▓▓▓▓▓▓▓ │  filling    →  api/     (lógica de negocio)
    ├───────────────┤
    │ █████████████ │  sponge     →  db/      (datos)
    ╞═══════════════╡
    │ ▪▪▪▪▪▪▪▪▪▪▪▪▪ │  plate      →  infra/   (soporte)
    └───────────────┘
```

### 4.2 Capas fundamentales

| Elemento del pastel | Capa | Metáfora | Responsabilidad |
|---------------------|------|----------|-----------------|
| **Plate** (plato) | `infra/` | Soporte rígido, no se come | Docker, CI/CD, IaC, configuración de ambientes |
| **Sponge** (bizcocho) | `db/` | Base porosa, absorbe y retiene | DDL declarativo, schemas, seeds, datos |
| **Filling** (relleno) | `api/` | Núcleo rico, razón del pastel | UseCases, Repositories, lógica de negocio |
| **Frosting** (glaseado) | `app/` | Superficie visible y atractiva | UI, Services HTTP, Controllers, vistas |

### 4.3 Capas adicionales (toppings)

| Elemento | Capa | Uso |
|----------|------|-----|
| Decoración superior | `cli/` | Interfaz textual |
| Decoración superior | `site/` | Documentación pública |
| Decoración superior | `book/` | Documentación extendida |

### 4.4 El corte vertical (slice)

Una rebanada corta **todas las capas incluyendo el plato**:

```
    ┌───────────────┐         ┌───┐
    │ ░░░░░░░░░░░░░ │         │░░░│  ← app/modules/orders/
    ├───────────────┤         ├───┤
    │ ▓▓▓▓▓▓▓▓▓▓▓▓▓ │    →    │▓▓▓│  ← api/modules/orders/
    ├───────────────┤         ├───┤
    │ █████████████ │         │███│  ← db/modules/orders/
    ╞═══════════════╡         ╞═══╡
    │ ▪▪▪▪▪▪▪▪▪▪▪▪▪ │         │▪▪▪│  ← infra/ (pipeline, env)
    └───────────────┘         └───┘
     pastel completo       slice "orders"
```

**El plato se corta** porque un slice necesita su infraestructura: su Dockerfile, su pipeline de CI, su configuración de ambiente.

### 4.5 La cereza verde

- Posición: cima del pastel
- Color: verde
- Significado: la calidad del software en producción — el resultado visible cuando todas las capas están correctamente integradas
- Referencia literaria: la luz verde al final del muelle en *The Great Gatsby* (Fitzgerald, 1925) — el ideal que organiza el esfuerzo

---

## 5. Comparación con modelos existentes

| Modelo | Capas | Corte vertical | Plato/Infra | Extensible |
|--------|-------|---------------|-------------|-----------|
| Evans (DDD) | 4 fijas | No | Infrastructure (mezclada) | No |
| Clean Architecture | 4 círculos | No | Frameworks (exterior) | No |
| Hexagonal | 2 (app + adapters) | No | Adapters | No |
| Vertical Slice (Bogard) | 0 (mezcladas) | Sí (carpeta) | No | N/A |
| **Layer Cake (MACSS)** | **3 + plato** | **Sí (concepto)** | **Sí (separado)** | **Sí** |

---

## 6. Referencias

1. Buschmann, F. et al. (1996). *Pattern-Oriented Software Architecture, Vol. 1*. Wiley.
2. Evans, E. (2003). *Domain-Driven Design*. Addison-Wesley.
3. Martin, R. C. (2017). *Clean Architecture*. Prentice Hall.
4. Cockburn, A. (2005). "Hexagonal Architecture." alistair.cockburn.us.
5. Bogard, J. (2018). "Vertical Slice Architecture." jimmybogard.com/vertical-slice-architecture/
6. Bogard, J. (2019). "Vertical Slice Architecture." NDC Sydney. [YouTube]
7. Tanenbaum, A. S. (2010). *Computer Networks*, 5th ed. Pearson.
8. Perry, D. E. & Wolf, A. L. (1992). "Foundations for the Study of Software Architecture." *ACM SIGSOFT Software Engineering Notes*, 17(4), pp. 40–52.
9. Dijkstra, E. W. (1968). "The Structure of the 'THE'-Multiprogramming System." *Communications of the ACM*, 11(5), pp. 341–346.
10. Fitzgerald, F. S. (1925). *The Great Gatsby*. Charles Scribner's Sons.

---

*Documento creado: Mayo 2026.*
