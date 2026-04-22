# Vendoring choices

## What was copied

We vendored these trees under `generators/` — all `.git`, `.gitmodules`,
`target/`, and `regression/` directories were stripped so the tree ships
clean and cannot accidentally resurrect upstream submodule pointers.

| Source                                | Destination                          | Reason |
|---------------------------------------|--------------------------------------|--------|
| `RISC-V-CPU/rocket-chip/`             | `generators/rocket-chip/`            | Core generator |
| `RISC-V-CPU/generators/riscv-boom/`   | `generators/riscv-boom/`             | BOOM OoO core |
| `RISC-V-CPU/generators/sifive-cache/` | `generators/sifive-cache/`           | Inclusive L2 |
| `RISC-V-CPU/generators/testchipip/`   | `generators/testchipip/`             | TraceIO / SerDes utilities |
| `RISC-V-CPU/generators/targetutils/`  | `generators/targetutils/`            | FPGA target annotations |

Total vendored tree is ~38 MB. The original RISC-V-CPU used git
submodules pointing at these, which makes "git clone" heavyweight and
requires network access. Foxden ships them in the main tree.

## What was NOT copied

| Upstream                  | Why skipped |
|---------------------------|-------------|
| `chipyard/`               | Uses Chisel 6 + CIRCT (firtool) flow incompatible with our FIRRTL InlineInstances pass |
| `generators/gemmini/`     | Not required by the four Foxden configs; large and adds an extra build dep |
| `generators/shuttle/`     | Chipyard-Chisel-6 only |
| `generators/saturn/`      | 82 MB vector unit; add later when V-extension is wired up |
| `generators/constellation`| NoC generator; not needed for these four configs |
| `rocket-chip/regression/` | Test suite, not used on FPGA |
| `rocket-chip/target/`     | Build artefacts |
| `**/torture/`             | Random test generator |

## Why we didn't port Chisel 6 chipyard

Chipyard moved to Chisel 6 and its FIRRTL-to-Verilog pass is now CIRCT's
`firtool`, invoked from within Chisel. That flow does not compose with
the old `firrtl.passes.InlineInstances` transform and the VHDL-wrapper
generator used by vivado-risc-v, which post-processes flat emitted
Verilog. Doing the upgrade properly requires:

1. Replacing `firrtl.stage.FirrtlMain` with a `circt.stage` call.
2. Re-implementing the VHDL wrapper (net.largest.riscv.vhdl) to match
   what firtool emits (different module naming, different AXI port
   aggregation).
3. Re-validating the KU5P board TCL which expects `rocket.vhdl` with
   specific port names.

That's a multi-week effort outside the scope of this release. Foxden
preserves the working Chisel 3.6.1 + FIRRTL pipeline and borrows the
**naming / structure** pattern from chipyard (config family layout,
area / balance / performance opt profile mixins, explicit
WithNSmallBooms / WithNMediumBooms / WithNLargeBooms / WithNMegaBooms).

A future Foxden 2.x release can follow chipyard main-line once the
FIRRTL→CIRCT transition has stabilised and vivado-risc-v's toolchain
catches up.
