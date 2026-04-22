# Foxden design notebook

This folder is a scratchpad for design decisions, gotchas and TODOs.
It's in-tree (not in `docs/`) because future maintainers - and future
LLM sessions - need to know *why* something was done the way it was,
not just *what*.

## What's here

- `architecture.md`         - the five configs and their positioning
- `vendoring.md`            - why we copied generators in, and what was pruned
- `chisel-version.md`       - why Chisel 3.6.1 and not chipyard's Chisel 6
- `lscpu-branding.md`       - how we make Linux advertise "Foxden" as the vendor
- `xiangshan-integration.md`- research + vendoring plan for the XS slot
- `todo.md`                 - open work, closed items, known blockers
- `ideas.md`                - forward-looking brainstorm (unfiltered)

> Note: `memory/` is gitignored in this tree — it's a private notebook,
> not a product artefact. Committed docs live under `docs/`.
