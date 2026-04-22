# XiangShan Nanhu as Foxden's 5th OoO family

## Research summary (2026-04-22)

Surveyed the open-source RISC-V OoO landscape for a core more modern
than BOOM to slot above LargeBOOM / MegaBOOM:

| Core                     | Repo                                   | HDL / Chisel | Linux | BOOM-equivalent         | Verdict for Foxden 1.x |
|--------------------------|----------------------------------------|--------------|-------|-------------------------|------------------------|
| XiangShan Kunminghu (G3) | OpenXiangShan/XiangShan master         | Chisel 6.7   | yes   | beats MegaBOOM (~15 SPECint2006/GHz, 6-wide) | **blocked** - Chisel 6 |
| **XiangShan Nanhu (G2)** | OpenXiangShan/XiangShan branch `nanhu` | Chisel 3.x   | yes   | between LargeBOOM and MegaBOOM, TAGE-SC-L + ITTAGE | **pick this one**      |
| Nanhu-V5                 | OpenXiangShan-Nanhu/Nanhu-V5           | Chisel 6     | yes   | between Nanhu and KMH   | blocked - Chisel 6     |
| Shuttle                  | ucb-bar/shuttle                        | Chisel 3/6   | yes   | in-order superscalar    | wrong slot (not OoO)   |
| NaxRiscv                 | SpinalHDL/NaxRiscv                     | SpinalHDL    | yes   | ~SmallBOOM/MediumBOOM   | different HDL          |
| VexiiRiscv OoO           | SpinalHDL/VexiiRiscv                   | SpinalHDL    | yes   | ~SmallBOOM              | different HDL          |
| CVA6S+ + HPDcache        | openhwgroup/cva6 + cv-hpdcache         | SystemVerilog| yes   | superscalar in-order    | not OoO pipeline       |
| OpenC910 / C906          | XUANTIE-RV/openc910                    | SystemVerilog| yes   | ~LargeBOOM              | not Chisel; huge re-plumb |
| Tenstorrent Ascalon      | (closed IP)                            | -            | yes   | would beat MegaBOOM     | not open source        |

**Conclusion:** XiangShan Nanhu is the only realistic upgrade above
LargeBOOM for a Chisel 3.6.1 stack.  Kunminghu / Nanhu-V5 should be
revisited when Foxden migrates to Chisel 6 (see
`memory/chisel-version.md`). For now, BOOM Medium* still wins the
"medium OoO" slot on Chisel-3.

## Vendoring procedure (reserved slot - not executed in 1.x)

```bash
cd Foxden-risc-v
git clone --depth=1 -b nanhu \
    https://github.com/OpenXiangShan/XiangShan generators/xiangshan
rm -rf generators/xiangshan/.git generators/xiangshan/.gitmodules

# Side-dependencies XiangShan pulls in (all small):
for dep in chisel-crossbar difftest HuanCun utility yunsuan; do
  git clone --depth=1 https://github.com/OpenXiangShan/$dep \
      generators/xiangshan-deps/$dep
done
find generators/xiangshan-deps -name ".git" -exec rm -rf {} +
```

Then:

1. Strip the `libraryDependencies += "edu.berkeley.cs" %% "rocketchip"`
   line from XiangShan's inner `build.sbt` (same trick as testchipip).
2. Add an sbt sub-project `xiangshan` to our top-level `build.sbt` that
   depends on cde + rocketchip + the HuanCun / utility side-modules.
3. Write `WithNXiangShanCores(n)` in a new file modelled on BOOM's
   `WithNMediumBooms` — it installs
   `XSTileAttachParams` into `TilesLocated(InSubsystem)`.
4. Flip `Foxden_OoO_XS_1` / `Foxden_OoO_XS_2` from the current
   "not-vendored" throw to:

   ```scala
   class Foxden_OoO_XS_1 extends Config(
     new WithInclusiveCache ++
     new WithNBreakpoints(8) ++
     new WithNXiangShanCores(1) ++
     new FoxdenWideBusConfig)
   ```

5. Adjust `board/common/foxden-freq`: Nanhu is a 4-wide OoO with a
   large L1 + TAGE - expect 50 MHz Fmax on xcku5p-2, identical
   budget to MegaBOOM.
6. Update `FoxdenSystem.scala` if XiangShan's IOs need extra
   diplomatic sinks (they don't on Nanhu, but on Kunminghu some
   AIA-related sinks are added).

## Estimated effort

~1 day for a first successful `sbt compile` + DTS emit, another day
for block-design integration on KU5P.  Not done in Foxden 1.x because
the BD / IP-inference quirk in `docs/STATUS.md` is the blocking item
before any new core is synthesised on this board.

## Why Foxden reserves the slot *now*

Reserving `Foxden_OoO_XS_{1,2}` classes means:
- The GUI can surface family #5 today with a clear "not-vendored-yet"
  error instead of silently falling back to BOOM.
- `make list-configs` shows the forward-looking menu.
- Users who read `docs/EXTENSIONS.md` + this memo can do the vendor
  drop in a self-contained way without needing to re-shape
  Foxden's Scala surface.

## References

- OpenXiangShan/XiangShan                                 (root)
- OpenXiangShan/XiangShan, branch `nanhu`                 (our target)
- OpenXiangShan-Nanhu/Nanhu-V5                            (Chisel-6 successor)
- RISC-V Summit Europe 2025: XiangShan Kunminghu slides
- Hot Chips 2024: XiangShan - a high-performance open-source RV64 OoO
- SpinalHDL/NaxRiscv, SpinalHDL/VexiiRiscv                (alt HDL)
- openhwgroup/cva6, openhwgroup/cv-hpdcache               (SV, superscalar in-order)
- ucb-bar/shuttle                                         (in-order, wrong slot)
