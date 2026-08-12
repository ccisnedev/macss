# Entrega

<!-- macss:lang=es · Idioma de esta entrega. Sigue al proyecto, no a la etapa:
     el mismo idioma que la solicitud y el contrato que responde. -->

<!--
  Este documento es la **afirmación**, no el veredicto. Es el espejo de la
  solicitud: la solicitud dice qué se pidió y nadie la firma; la entrega dice
  qué se construyó y tampoco la firma nadie. Lo que se firma es la
  verificación, y la firma quien responde por ella.

  Así que se escribe para alguien que no estuvo aquí — que tiene el contrato
  congelado y el diff, y nada más. Todo lo que pueda deducir de esos dos ya es
  suyo. Solo hay tres cosas que no, y son las tres secciones de abajo.

  Lo que NO va aquí: qué se construyó (lo dice el código), por qué se construyó
  así (lo dice un ADR, o no lo dice nada), y qué tan bien salió. Una entrega
  que argumenta su propia calidad está haciendo el trabajo de la verificación,
  y lo hace desde la única posición que no puede.
-->

## Metadatos

| Campo     | Valor                                     |
| --------- | ----------------------------------------- |
| Solicitud | <!-- slug -->                             |
| Issue     | <!-- #N, el contrato que responde -->     |
| Entregado | {{DATE}}                                  |

## 1. Cada criterio, y dónde está su evidencia

<!-- Una fila por criterio de aceptación del contrato, con los ids del propio
     contrato: el 3er criterio de la 2a historia es US2-AC3. La puerta comprueba
     que estén todos y que cada uno nombre algo que el lector pueda ejecutar o
     abrir — el nombre de un test, un fichero y una línea, un comando.

     Esto es una afirmación. Estás diciendo "creo que este criterio se cumple, y
     aquí es dónde mirar". Quien verifica lo comprueba; tú no lo verificas aquí.
     Un criterio que no pudiste cumplir no se omite: va en la sección 2. -->

| Criterio | Dónde está la evidencia                            |
| -------- | -------------------------------------------------- |
| US1-AC1  | <!-- nombre del test · fichero:línea · comando -->  |

## 2. Qué quedó sin hacer, y por qué

<!-- La sección que el diff no puede enseñar. Un criterio sin implementar se ve
     igual que uno implementado en otro sitio, y una decisión de dejar algo
     fuera se ve igual que un descuido. Dilo sin rodeos, por cada cosa:

     - qué no está,
     - si quedó fuera de alcance, aplazado, o intentado y abandonado,
     - y qué debería hacer el lector al respecto.

     Si se entregó todo el contrato, escribe "Nada" — la sección vacía y la
     sección sin escribir son afirmaciones distintas, y solo una es fiable. -->

- <!-- qué falta, y por qué -->

## 3. Cómo se reproduce

<!-- Lo que quien verifica necesita para llegar desde un clon limpio hasta la
     evidencia de la sección 1: la rama, y el comando que corre la suite. Y
     cualquier cosa fuera de lo normal que si no tendría que descubrir — un
     fixture que generar, un servicio que levantar, un flag que poner. Si no hay
     nada fuera de lo normal, dilo: "nada" también es información. -->

- **Rama:** <!-- nombre de la rama -->
- **Suite:** <!-- el comando que corre todos los tests -->
- **Algo más:** <!-- preparación que el lector no podría adivinar, o "nada" -->
