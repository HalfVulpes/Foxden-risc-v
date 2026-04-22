// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Foxden Config #1 : In-order RV64GC
// - Rocket big core (IMAFDC), MMU, 16 KB L1I / 16 KB L1D per core
// - 1 / 2 / 4 / 8 core variants
// - Linux-capable, boots Debian via OpenSBI + U-Boot
//
// Matches the profile of the "application core" in MicroBlaze / Zynq
// but gives full 64-bit RV64GC and symmetric multi-core.
package foxden

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._

// ---- Building block ---------------------------------------------------------

class FoxdenInOrderBase extends Config(
  new WithNBreakpoints(8) ++
  new FoxdenBaseConfig)

class FoxdenInOrderWideBase extends Config(
  new WithNBreakpoints(8) ++
  new FoxdenWideBusConfig)

// ---- 1-core -----------------------------------------------------------------

/** Foxden_IO_RV64GC_1 : single-core Linux-capable in-order RV64GC. */
class Foxden_IO_RV64GC_1 extends Config(
  new WithNBigCores(1) ++
  new FoxdenInOrderBase)

// ---- 2-core -----------------------------------------------------------------

/** Foxden_IO_RV64GC_2 : dual-core RV64GC, coherent L1, no L2. */
class Foxden_IO_RV64GC_2 extends Config(
  new WithNBigCores(2) ++
  new FoxdenInOrderBase)

/** Foxden_IO_RV64GC_2_L2 : dual-core with 512 KB SiFive inclusive L2. */
class Foxden_IO_RV64GC_2_L2 extends Config(
  new WithInclusiveCache ++
  new WithNBigCores(2) ++
  new FoxdenInOrderWideBase)

// ---- 4-core (recommended) ---------------------------------------------------

/** Foxden_IO_RV64GC_4 : quad-core RV64GC, no L2, 64-bit memory edge. */
class Foxden_IO_RV64GC_4 extends Config(
  new WithNBigCores(4) ++
  new FoxdenInOrderBase)

/** Foxden_IO_RV64GC_4_L2W : quad-core with 512 KB L2 + 256-bit memory edge.
  * This is the recommended flagship in-order Foxden config for the KU5P.
  */
class Foxden_IO_RV64GC_4_L2W extends Config(
  new WithInclusiveCache ++
  new WithNBigCores(4) ++
  new FoxdenInOrderWideBase)

// ---- 8-core -----------------------------------------------------------------

/** Foxden_IO_RV64GC_8 : 8-core. Tight LUT budget on KU5P; use a bigger part. */
class Foxden_IO_RV64GC_8 extends Config(
  new WithInclusiveCache ++
  new WithNBigCores(8) ++
  new FoxdenInOrderWideBase)
