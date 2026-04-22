// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
package foxden

import org.chipsalliance.cde.config.{Config, Parameters}
import freechips.rocketchip.devices.debug.DebugModuleKey
import freechips.rocketchip.subsystem._
import freechips.rocketchip.devices.tilelink._
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}
import freechips.rocketchip.system._

/** Mixin: shrink the RISC-V debug module's program buffer.
  * Large program buffers eat LUTs with no value for FPGA softcores.
  */
class WithDebugProgBuf(prog_buf_words: Int, imp_break: Boolean)
    extends Config((site, here, up) => {
      case DebugModuleKey =>
        up(DebugModuleKey, site).map(_.copy(
          nProgramBufferWords = prog_buf_words,
          hasImplicitEbreak = imp_break))
    })

/** Mixin: put a human-readable vendor / part-number string into the
  * generated device tree. This is what Linux exposes to /proc/cpuinfo
  * and lscpu as "Model", making the board identify itself cleanly.
  */
class WithFoxdenDTS(model: String = "Foxden RV64GC Linux SoC")
    extends WithDTS(model, Seq("foxden,foxden-risc-v", "foxden,rv64"))

/** FoxdenBaseConfig: shared scaffolding across all Foxden variants.
  *   - 14 GB max external DRAM (board-specific Makefile shrinks as needed)
  *   - 64-bit memory bus edge
  *   - Coherent CBUS/SBUS topology
  *   - No TileLink monitors (huge LUT / timing win on FPGA)
  *   - Debug over system-bus access (SBA)
  *   - Boot ROM baked from `workspace/bootrom.img`
  */
class FoxdenBaseConfig extends Config(
  new WithBootROMFile("workspace/bootrom.img") ++
  new WithExtMemSize(0x380000000L) ++
  new WithNExtTopInterrupts(8) ++
  new WithFoxdenDTS() ++
  new WithDebugSBA ++
  new WithEdgeDataBits(64) ++
  new WithCoherentBusTopology ++
  new WithoutTLMonitors ++
  new BaseConfig)

/** Same as [[FoxdenBaseConfig]] but with a 256-bit memory edge.
  * Use this for L2-backed configs or wide DRAM subsystems.
  */
class FoxdenWideBusConfig extends Config(
  new WithBootROMFile("workspace/bootrom.img") ++
  new WithExtMemSize(0x380000000L) ++
  new WithNExtTopInterrupts(8) ++
  new WithFoxdenDTS() ++
  new WithDebugSBA ++
  new WithEdgeDataBits(256) ++
  new WithCoherentBusTopology ++
  new WithoutTLMonitors ++
  new BaseConfig)
