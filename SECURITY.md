# Security Policy

MACSS is the root of an ecosystem whose components (CLI, templates, scaffolding and reference architecture) are used to build production software. We take vulnerabilities in it seriously and appreciate responsible disclosure.

## Supported versions

The project is pre-1.0. Security fixes are released for the **latest minor version** only. Older minors do not receive backports, so the remediation is to upgrade.

| Component | Supported |
|---|---|
| `macss` CLI and templates | latest minor (currently 0.14.x) |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public issues, discussions or pull requests.**

Report them privately through GitHub:

1. Go to the [Security tab](https://github.com/ccisnedev/macss/security) of this repository.
2. Click **Report a vulnerability**.
3. Fill in the advisory form.

Please include as much of the following as you can:

- Affected component and version.
- The type of issue (for example insecure defaults in generated code, command injection or secret exposure).
- Steps to reproduce.
- The impact: what an attacker can achieve.
- Any known workaround or suggested fix.

## What to expect

| Step | Target |
|---|---|
| Acknowledgement of your report | within 5 business days |
| Initial assessment (confirmed or not, severity) | within 10 business days |
| Fix or mitigation plan for confirmed issues | communicated in the advisory |

We work on confirmed issues in a private advisory and keep you informed there. When a fix is released, we publish the advisory, credit you unless you prefer to stay anonymous, and request a CVE when appropriate.

## Scope

**In scope:**

- the `macss` CLI;
- project templates and scaffolding, including insecure defaults in the code they generate;
- automation assets in this repository;
- architecture guidance that recommends an insecure pattern.

**Out of scope:**

- Components published from sibling repositories. Report those through their own repositories; for [`modular_api`](https://github.com/ccisnedev/modular_api), use its [Security tab](https://github.com/ccisnedev/modular_api/security).
- Vulnerabilities in applications built with MACSS that are caused by the application's own code or configuration. Please report those to the application owner.
- Vulnerabilities in third-party dependencies that MACSS does not make worse. Please report those upstream.
