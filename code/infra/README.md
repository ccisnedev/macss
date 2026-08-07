# infra

Infrastructure — provisioning and deployment of the environments where the other
modules run (containers, cloud resources, pipelines).

**Optional.** A MACSS project is valid without this module.
**Transversal.** `infra` is not a layer in the `app → api → db` chain. It
provisions for all three.
**Direction:** `infra` knows the modules — it packages and deploys them. The
modules never import `infra`.

## What belongs here

Version *definitions and recipes*, never built artifacts. Images, binaries, and
provider state are build outputs; keep them out of the repository (`.gitignore`).

## Recommended structure

Two axes, independent of any specific tool:

```
code/infra/
  modules/         # reusable, parameterized definitions (build recipes, IaC modules)
  environments/    # concrete instances that reference modules with real values
    dev/
    prod/
```

- `modules/` are the reusable definitions; `environments/` are the instances that
  call them with per-environment values.
- Keep each environment (`dev`, `staging`, `prod`) separate so it holds its own
  values and its own approval flow.

This layout is a recommendation, not a mandate. Create only the folders a real
deployment needs.
