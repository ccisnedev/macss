# MACSS — Identidad de marca

---

## El símbolo

```
   █▀   ▀█
      •
   █▄   ▄█
```

Cuatro esquinas. Un punto. Nada más.

---

## Análisis del comité

---

**🏛️ Arquitecto — Fowler school**

> Las cuatro esquinas son literalmente un framework en su sentido más puro: un marco que define el espacio donde ocurre el trabajo. `db`, `api`, `ui`, `infra` — cada esquina es una dimensión del stack. El punto central no pertenece a ninguna capa; pertenece al sistema. Es donde converge el contexto completo que MACSS le devuelve al desarrollador.

---

**🎨 Diseñadora — Pentagram**

> El símbolo funciona en todos los tamaños porque no depende del detalle: funciona a 3×3 caracteres en terminal, a 16×16px como favicon, a cualquier escala vectorial. Su poder viene del espacio negativo. La chakana no está dibujada — emerge. Eso significa que el símbolo *activa* al observador: para verla, hay que completarla mentalmente. Los mejores logos hacen exactamente eso.
>
> El punto es verde. No el marco. El verde señala lo que está vivo, lo que es el objetivo, lo que aún no se alcanza del todo — y eso es lo correcto para una herramienta de desarrollo: la calidad como norte constante.

---

**📐 Semiótico — Eco**

> El símbolo opera en tres niveles simultáneos:
>
> **Nivel 1 — Literal:** cuatro esquinas forman un marco. Un punto verde en el centro.
>
> **Nivel 2 — Estructural:** las esquinas son los cuatro dominios del stack (`db · api · ui · infra`). El punto es la quintaesencia — el quinto elemento que surge cuando los cuatro están en equilibrio: el software que funciona.
>
> **Nivel 3 — Cultural:** la cruz que emerge del espacio negativo es la chakana andina — símbolo precolombino del cosmos ordenado en cuatro cuadrantes. MACSS tiene origen latinoamericano. La resonancia no es decorativa; es estructural.
>
> El punto verde es la luz al final del muelle de Fitzgerald: el ideal que organiza todo el esfuerzo, visible pero nunca definitivamente alcanzado. Es la metáfora correcta para el desarrollo de software.

---

**🗿 Historiador andino**

> La chakana no está dibujada. Aparece. Eso es fiel a la tradición andina: el orden no se impone, emerge de la relación entre las partes. Sacsayhuamán no tiene plano maestro conocido — el muro es la suma de piedras que se tallaron para encajar entre sí. MACSS propone lo mismo: módulos que se definen por sus interfaces, no por un esquema central.
>
> Que el símbolo de una herramienta de arquitectura de software contenga la cruz andina como figura latente — sin haberlo forzado — es un accidente que merece conservarse.

---

**📊 Estratega — YC**

> Test de marca final:
>
> | Criterio | Resultado |
> |----------|-----------|
> | Reconocible a 16×16px | ✓ |
> | Funciona en blanco y negro | ✓ |
> | Funciona en terminal ASCII | ✓ |
> | Tiene una lectura inmediata | ✓ — cuatro esquinas, un punto |
> | Tiene una segunda lectura | ✓ — la chakana emerge |
> | Tiene una tercera lectura | ✓ — la quintaesencia, Gatsby |
> | Es diferenciado en el espacio de dev tooling | ✓ |
> | Comunica el producto sin texto | ✓ — framework + centro vivo |
>
> Un logo que tiene tres lecturas sin necesitar explicación es un logo que funciona. No cambiéis nada.

---

## Síntesis

**El símbolo:** cuatro esquinas blancas (`█▀ ▀█ / █▄ ▄█`) y un punto verde (`•`).

**Lo que comunica sin palabras:**
- Un framework con cuatro dominios (`db · api · ui · infra`)
- La chakana — orden que emerge del espacio negativo
- La quintaesencia — el quinto elemento que aparece cuando los cuatro están en equilibrio
- El desarrollador que domina los cuatro elementos: el **Software Bender**

**El color:** el marco es blanco — neutral, estructural. El punto es verde — vivo, el objetivo, la luz que se persigue.

**El nombre:** `macss`. El alias: `ma`. Dos letras, presencia completa.

---

## Identidad de marca: Layer Cake Architecture

> "Where you serve vertical slices."

El símbolo de las cuatro esquinas evoluciona hacia el **pastel de capas** como identidad visual principal. La arquitectura se comunica directamente: un pastel de 3 capas sobre un plato, con una rebanada cortada que atraviesa todo — incluyendo el plato.

### El pastel

```
              🍒  ← cereza verde
        ┌─────────────────┐
  app   │ ░░░░░░░░░░░░░░░ │  frosting (glaseado)
        ├─────────────────┤
  api   │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  filling (relleno)
        ├─────────────────┤
  db    │ █████████████████ │  sponge (bizcocho)
        ╞═════════════════╡
  infra │ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ │  plate (plato)
        └─────────────────┘
```

### Mapeo capa → elemento

| Elemento | Capa | Por qué funciona como metáfora |
|----------|------|-------------------------------|
| **Plate** (plato) | `infra/` | Soporte rígido. No se come. Sin él, el pastel no se sostiene. |
| **Sponge** (bizcocho) | `db/` | Base porosa que absorbe y retiene. Estructura interna del pastel. |
| **Filling** (relleno) | `api/` | El núcleo rico — la razón por la que comes el pastel. Lógica de negocio. |
| **Frosting** (glaseado) | `app/` | Lo primero que ves y tocas. La presentación. |

### Capas adicionales (toppings)

El pastel es extensible. Nuevas capas opcionales se apilan como decoraciones:

- `cli/` — interfaz textual
- `site/` — documentación pública
- `book/` — documentación extendida

### El corte vertical (slice)

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

El plato se corta porque un slice necesita su infraestructura: su Dockerfile, su pipeline de CI, su configuración de ambiente.

### La cereza verde

La cereza verde en la cima del pastel preserva el significado del punto verde original:

- **Símbolo abstracto**: punto verde = quintaesencia, lo que emerge cuando los cuatro dominios están en equilibrio
- **Layer Cake**: cereza verde = la calidad del software en producción — el resultado visible cuando todas las capas están correctamente integradas
- **Referencia literaria**: la luz verde de Gatsby — el ideal que organiza todo el esfuerzo, visible pero nunca definitivamente alcanzado

### Coexistencia de representaciones

| Contexto | Representación |
|----------|---------------|
| Favicon, terminal, marca minimal | Símbolo abstracto (`█▀ ▀█ / • / █▄ ▄█`) |
| Documentación, arquitectura, onboarding | Layer Cake con slice |
| Comunicación verbal | "Layer Cake Architecture — where you serve vertical slices" |

---

*Identidad definida. Mayo 2026.*
