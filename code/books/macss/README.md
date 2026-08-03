# MACSS Architecture Book

The canonical book for MACSS: the architecture, and the methodology built on it.

It is maintained as Markdown so it can be versioned in Git, reviewed with pull
requests, rendered by site pipelines, and read as source of truth by
contributors and AI agents alike.

## Layout

```
SUMMARY.md        reading order, shared by every language — slugs, not titles
diagrams/         Mermaid sources, shared: labels are technical, not prose
src/<lang>/       one directory per language, one file per slug
```

`SUMMARY.md` holds what is language-independent: which chapters exist and in
what order. A chapter's **title lives in its own H1**, in its own language.
Splitting it that way is what lets the structure stay identical across editions
while the prose does not.

Adding a language is adding `src/<lang>/` and translating into it. No code has
to learn the language's name — the check enumerates the directory rather than
listing what it expects to find, so an edition added tomorrow is covered by the
suite that ships today.

A chapter a language has not translated yet is a missing file: a state the check
reports, rather than one that passes silently.

## Editorial rule

- Conceptual and explanatory chapters live in this book.
- Decision history stays in `docs/adr`.
- Operational contracts stay with the thing they govern: a command's contract is
  its declared parameters, not a document describing them.

## Where the content comes from

`cacsi-dev/handbook` is this book's laboratory — where the methodology is
refined against one company's actual practice before the general version
inherits it. The flow is one-directional: this book never references the
handbook and never depends on it. See Stage 6 of `docs/roadmap.md`.

Start reading from `SUMMARY.md`.
