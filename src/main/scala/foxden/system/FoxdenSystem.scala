// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors. See LICENSE for details.
//
// Portions adapted from the vivado-risc-v project by Eugene Tarassov
// (BSD 3-Clause) and the chipyard project (Apache-2.0 + BSD-3-Clause).
//
// FoxdenSystem: Vivado-facing SoC wrapper for Foxden configurations.
// - Exports AXI4 master for DDR memory
// - Exports AXI4 MMIO port for peripherals (UART / SDC / Ethernet)
// - Exports AXI4 slave port (used by DMA-capable peripherals)
// - Exposes the debug module for OpenOCD/xsdb via BSCAN (JTAG)
package foxden

import chisel3._
import org.chipsalliance.cde.config.{Config, Parameters}
import freechips.rocketchip.devices.debug.DebugModuleKey
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.devices.tilelink._
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}
import freechips.rocketchip.util.DontTouch
import freechips.rocketchip.system._

/** Top-level Foxden SoC: same IO shape as the vivado-risc-v RocketSystem
  * so the existing Vivado TCL and VHDL wrapper work unchanged.
  */
class FoxdenSystem(implicit p: Parameters) extends RocketSubsystem
    with HasAsyncExtInterrupts
    with CanHaveMasterAXI4MemPort
    with CanHaveMasterAXI4MMIOPort
    with CanHaveSlaveAXI4Port
{
  val bootROM = p(BootROMLocated(location)).map { BootROM.attach(_, this, CBUS) }
  override lazy val module = new FoxdenSystemModuleImp(this)
}

class FoxdenSystemModuleImp[+L <: FoxdenSystem](_outer: L)
    extends RocketSubsystemModuleImp(_outer)
    with HasRTCModuleImp
    with HasExtInterruptsModuleImp
    with DontTouch
