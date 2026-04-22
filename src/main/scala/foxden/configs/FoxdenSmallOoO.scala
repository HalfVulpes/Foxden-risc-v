// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Foxden Config #2 : lowest-area out-of-order CPU
// - 1-wide BOOM (SmallBoom), 32-entry ROB, 2-op dispatch
// - RV64GC + RoCC-ready, Linux-capable
// - Intended for FPGA parts with tight LUT budgets where the user still
//   wants speculative OoO behaviour (e.g. for driver / soft-IP work that
//   hits memory-stall walls on in-order rocket).
package foxden

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._

class FoxdenSmallOoOBase extends Config(
  new WithInclusiveCache ++
  new WithNBreakpoints(8) ++
  new FoxdenWideBusConfig)

/** Foxden_OoO_Small_1 : single-core small-BOOM, L2-backed. */
class Foxden_OoO_Small_1 extends Config(
  new boom.common.WithNSmallBooms(1) ++
  new FoxdenSmallOoOBase)

/** Foxden_OoO_Small_2 : dual small-BOOM. BOOM multi-core is flagged
  * unstable upstream - use for experimentation.
  */
class Foxden_OoO_Small_2 extends Config(
  new boom.common.WithNSmallBooms(2) ++
  new FoxdenSmallOoOBase)

/** Foxden_OoO_Small_4 : quad small-BOOM. */
class Foxden_OoO_Small_4 extends Config(
  new boom.common.WithNSmallBooms(4) ++
  new FoxdenSmallOoOBase)
