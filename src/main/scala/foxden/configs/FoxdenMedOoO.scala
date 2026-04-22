// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Foxden Config #3 : medium out-of-order CPU
// - 2-wide BOOM (MediumBoom), 64-entry ROB, TAGE-L BPD
// - Reasonable IPC uplift over in-order rocket; still fits KU5P comfortably
//   at ~100 MHz in single-core form.
package foxden

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._

class FoxdenMedOoOBase extends Config(
  new WithInclusiveCache ++
  new WithNBreakpoints(8) ++
  new FoxdenWideBusConfig)

/** Foxden_OoO_Medium_1 : single medium-BOOM core. */
class Foxden_OoO_Medium_1 extends Config(
  new boom.common.WithNMediumBooms(1) ++
  new FoxdenMedOoOBase)

/** Foxden_OoO_Medium_2 : dual medium-BOOM. */
class Foxden_OoO_Medium_2 extends Config(
  new boom.common.WithNMediumBooms(2) ++
  new FoxdenMedOoOBase)

/** Foxden_OoO_Medium_4 : quad medium-BOOM. */
class Foxden_OoO_Medium_4 extends Config(
  new boom.common.WithNMediumBooms(4) ++
  new FoxdenMedOoOBase)
