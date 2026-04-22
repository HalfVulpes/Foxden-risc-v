# Chisel version choice

## TL;DR

Foxden 1.x uses **Chisel 3.6.1** + classic FIRRTL, not Chisel 6 +
CIRCT/firtool.

## Reasons

1. **Vivado-risc-v tooling depends on classic FIRRTL.** The board
   glue (`net.largest.riscv.vhdl.Main`) parses flat Verilog emitted by
   `firrtl.stage.FirrtlMain` with the `InlineInstances` transform, and
   expects specific module-name shapes. CIRCT emits different structure.

2. **Rocket-chip / BOOM / sifive-cache versions that are known-good on
   the KU5P ship as Chisel 3.6.1.** Chipyard's newer rocket-chip has a
   reworked `HierarchicalElement` diplomacy API that our FoxdenSystem
   wrapper would need to be rewritten against, and BOOM on Chisel 6 is
   still in shakeout.

3. **Time budget.** A Chisel 6 port involves touching every config
   mixin, rebuilding the VHDL wrapper, and re-qualifying the bitstream
   on hardware. Out of scope for v1.

## Forward path

- Foxden 2.x: optional Chisel 6 backend guarded behind `USE_CHISEL7=1`
  (same pattern as chipyard's build.sbt), keeping 3.6.1 as the default
  until Vivado-risc-v upstream moves.
- Vendor chipyard's `dependencies/chisel` *source* only when 2.x lands,
  so the 1.x tree stays small.
