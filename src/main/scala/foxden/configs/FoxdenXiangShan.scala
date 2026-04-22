// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Foxden Config #5 : XiangShan-class flagship single-core
//
// XiangShan (OpenXiangShan, github.com/OpenXiangShan/XiangShan) is a
// modern 2024-era open-source RV64 OoO core out of ICT / PLCT / BOSC.
// The `nanhu` branch is the only XiangShan line that is Chisel-3
// compatible with Foxden 1.x's vendored rocket-chip (3.6.1).
//
//   - 4-wide OoO fetch/rename/commit
//   - 64 KB L1I / 64 KB L1D, 1 MB L2, L3 optional
//   - TAGE-SC-L + ITTAGE branch predictor
//   - AXI4 memory / MMIO; diplomacy-compatible with rocket-chip
//   - Linux-capable (Debian verified)
//
// Compared to BOOM's current 3-wide LargeBOOM / 4-wide MegaBOOM,
// Nanhu typically delivers ~1.3-1.5x IPC on SPECint2006-scale
// workloads with a better branch predictor.  On a KU5P at -2 speed
// grade we target 50 MHz; Fmax ceiling is similar to MegaBOOM.
//
// ---- Integration status ----
//
// XiangShan Nanhu is *not vendored* in Foxden 1.x to keep the tree
// under 350 MB. Adding it is tracked as a short project:
//
//   1. `git clone -b nanhu https://github.com/OpenXiangShan/XiangShan
//       generators/xiangshan` (~60 MB after .git is stripped).
//   2. Adapt `generators/xiangshan/build.sbt` to depend on Foxden's
//       local rocketchip / cde (strip the Maven-rocketchip line, same
//       trick we used for testchipip).
//   3. Instantiate `XSTileAttachParams` inside a new subclass of
//       FoxdenSystem, or write `WithNXiangShanCores(n)` following BOOM's
//       `WithNMediumBooms` pattern.
//   4. Flip this file's placeholder classes over to the real thing and
//       remove the runtime throw.
//
// Until then the classes below raise a clear build-time error so users
// don't silently get a BOOM fallback when they ask for XiangShan.
package foxden

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._

private[foxden] object FoxdenXiangShanNotVendored {
  def fail: Nothing = throw new RuntimeException(
    "[Foxden] XiangShan Nanhu is not vendored in this release.\n" +
    "  The `Foxden_OoO_XS_*` family is a reserved slot - see\n" +
    "  memory/xiangshan-integration.md for the vendoring procedure.\n" +
    "  Workaround: use Foxden_OoO_Large_1 or Foxden_OoO_Mega_1 for now.")
}

/** Foxden_OoO_XS_1 : single-core XiangShan Nanhu (4-wide OoO, TAGE-SC-L).
  * Flagship slot above LargeBOOM / MegaBOOM when XiangShan is vendored. */
class Foxden_OoO_XS_1 extends Config((site, here, up) => {
  case _ => FoxdenXiangShanNotVendored.fail
})

/** Foxden_OoO_XS_2 : dual-core XiangShan Nanhu. */
class Foxden_OoO_XS_2 extends Config((site, here, up) => {
  case _ => FoxdenXiangShanNotVendored.fail
})
