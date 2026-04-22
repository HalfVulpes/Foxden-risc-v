// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Foxden Config #4 : highest-performance single-core
// - 3-wide BOOM (LargeBoom) by default; 4-wide MegaBOOM available
// - 96/128-entry ROB, aggressive TAGE-L predictor, large L1 caches
// - Designed to be the "application processor" profile - single core,
//   max IPC, L2-backed wide memory path.
package foxden

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._

class FoxdenLargeBase extends Config(
  new WithInclusiveCache ++
  new WithNBreakpoints(8) ++
  new FoxdenWideBusConfig)

/** Foxden_OoO_Large_1 : 3-wide LargeBOOM single core. Recommended flagship
  * single-core performance config.
  */
class Foxden_OoO_Large_1 extends Config(
  new boom.common.WithNLargeBooms(1) ++
  new FoxdenLargeBase)

/** Foxden_OoO_Mega_1 : 4-wide MegaBOOM single core. Upstream flags this
  * as occasionally unstable; included for users who want the maximum.
  */
class Foxden_OoO_Mega_1 extends Config(
  new boom.common.WithNMegaBooms(1) ++
  new FoxdenLargeBase)
