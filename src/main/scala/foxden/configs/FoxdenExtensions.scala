// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Foxden-risc-v Authors.
//
// Optional ISA-extension and micro-architecture mixins, surfaced in the
// Makefile / GUI as EXT=<csv>.  Each mixin either flips a real
// CoreParams / diplomacy flag on the vendored rocket-chip, or raises a
// well-scoped error when the extension needs a generator that we have
// not vendored yet (e.g. V → Saturn / Ara).
package foxden

import chisel3._
import org.chipsalliance.cde.config.{Config, Parameters}
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tile._
import freechips.rocketchip.rocket._

// ============================================================================
// Helper: walk every RocketTileAttachParams in the tile set and update its
// CoreParams. Keeps the individual mixins one-liners.
// ============================================================================

private[foxden] object RocketCoreEdit {
  def apply(f: RocketCoreParams => RocketCoreParams) = new Config((site, here, up) => {
    case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
      case tp: RocketTileAttachParams =>
        tp.copy(tileParams = tp.tileParams.copy(core = f(tp.tileParams.core)))
      case other => other
    }
  })
}

private[foxden] object RocketTileEdit {
  def apply(f: RocketTileParams => RocketTileParams) = new Config((site, here, up) => {
    case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
      case tp: RocketTileAttachParams => tp.copy(tileParams = f(tp.tileParams))
      case other => other
    }
  })
}

// ============================================================================
// ISA extensions - hardware-backed on the vendored rocket-chip
// ============================================================================

/** Zicond - conditional integer ops (czero.eqz / czero.nez). */
class WithFoxdenZicond extends Config(RocketCoreEdit(_.copy(useConditionalZero = true)))

/** Zihintpause is implemented unconditionally in this rocket-chip era -
  * this is a no-op advisory mixin kept for GUI completeness. */
class WithFoxdenZihintpause extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Note: Zihintpause is always present on rocket tiles.")
}

/** Zfh / Zfhmin - IEEE 16-bit half-precision float.
  * Backed by WithFP16 in rocket-chip's subsystem. */
class WithFoxdenZfh extends WithFP16

/** H-extension / hypervisor. */
class WithFoxdenHypervisor extends WithHypervisor(hext = true)

/** Non-maskable interrupts. */
class WithFoxdenNMI extends Config(RocketCoreEdit(_.copy(useNMI = true)))

/** RVE - embedded ABI (only x0..x15 available). Incompatible with hypervisor. */
class WithFoxdenRVE extends Config(RocketCoreEdit(_.copy(useRVE = true, useHypervisor = false)))

/** Turn off compressed (RV64IMAFD, no 'C'). Rare but useful for simulating
  * a G-only core when chasing a decoder bug. */
class WithFoxdenNoC extends Config(RocketCoreEdit(_.copy(useCompressed = false)))

/** Bigger PMP region count (useful with H-extension / many privileged
  * isolation domains). */
class WithFoxdenNPMPs(n: Int = 16) extends Config(RocketCoreEdit(_.copy(nPMPs = n)))

/** Expose N hardware performance counters. Default is 0 (only
  * cycle/instret/time mandated by the ISA). */
class WithFoxdenNPerfCounters(n: Int = 8)
    extends Config(RocketCoreEdit(_.copy(nPerfCounters = n)))

/** CFlush (non-standard L1 flush). Some firmware debuggers expect this. */
class WithFoxdenCFlush extends Config(RocketCoreEdit(_.copy(haveCFlush = true)))

/** Gated clock for tiles (uses EICG_wrapper). */
class WithFoxdenClockGate
    extends Config(RocketCoreEdit(_.copy(clockGate = true)))

/** Disable CEASE instruction (non-standard; some boot code trips on it). */
class WithFoxdenNoCease extends Config(RocketCoreEdit(_.copy(haveCease = false)))

/** Brand the core as "Foxden" via mvendorid/marchid/mimpid hints. The
  * actual vendor id numeric is arbitrary while non-commercial (0 per spec). */
class WithFoxdenVendorID(impid: Int = 0x20260422)
    extends Config(RocketCoreEdit(_.copy(mvendorid = 0, mimpid = impid)))

// ============================================================================
// ISA extensions - advisory only (vendored rocket-chip has no hardware)
// ============================================================================

/** Zba bitmanip - advisory marker. No hardware on this rocket-chip era;
  * binaries compiled with -march=rv64gc_zba run via M-mode emulation. */
class WithFoxdenZba extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zba requested - advisory only on this rocket base.")
}

/** Zbb bitmanip. */
class WithFoxdenZbb extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zbb requested - advisory only on this rocket base.")
}

/** Zbs single-bit manipulation. */
class WithFoxdenZbs extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zbs requested - advisory only on this rocket base.")
}

/** Zbc carryless multiply. */
class WithFoxdenZbc extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zbc requested - advisory only on this rocket base.")
}

/** Zicboz / Zicbom cache-block ops. Needs a newer rocket fork. */
class WithFoxdenZicbom extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zicbom/Zicboz advisory only on this rocket base.")
}

/** Zacas atomic CAS. */
class WithFoxdenZacas extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zacas advisory only on this rocket base.")
}

/** Zknd/Zkne/Zknh scalar crypto (NIST suite). */
class WithFoxdenZk extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Zk (NIST crypto) advisory only on this rocket base.")
}

/** Sm/Ss-AIA - advanced interrupt architecture.  Requires IMSIC / APLIC
  * IP that isn't wired into this generator yet. */
class WithFoxdenAIA extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Sm/Ss-AIA requires IMSIC/APLIC blocks - not yet vendored.")
}

/** Svpbmt - page-based memory types. */
class WithFoxdenSvpbmt extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Svpbmt advisory only on this rocket base.")
}

/** Svinval - fine-grain TLB invalidation. */
class WithFoxdenSvinval extends Config((site, here, up) => Map.empty) {
  println("[Foxden] Svinval advisory only on this rocket base.")
}

// ============================================================================
// Vector extensions - require a companion generator
// ============================================================================

/** V extension via Saturn vector unit (Berkeley, RVV 1.0). Will fail the
  * build until `generators/saturn/` is vendored in.  Tracked in memory/todo.md. */
class WithFoxdenVector extends Config((site, here, up) => {
  case _ => throw new RuntimeException(
    "[Foxden] EXT=v (Saturn V-extension) is not wired up in this release.\n" +
    "  See docs/EXTENSIONS.md and memory/todo.md; vendor generators/saturn/ first.")
})

/** V extension via Ara (ETH Zurich). Alternative to Saturn, SystemVerilog. */
class WithFoxdenVectorAra extends Config((site, here, up) => {
  case _ => throw new RuntimeException(
    "[Foxden] EXT=v-ara (Ara vector unit) is not wired up - Ara is SV, not Chisel;\n" +
    "  integrating it is a CVA6-pairing follow-up. See memory/todo.md.")
})

// ============================================================================
// Micro-architecture mixins - area / balance / performance profiles
// ============================================================================

class WithFoxdenAreaOpt extends Config(RocketTileEdit(tp => tp.copy(
  btb    = None,
  dcache = tp.dcache.map(_.copy(nSets = 64, nWays = 2, nMSHRs = 0)),
  icache = tp.icache.map(_.copy(nSets = 64, nWays = 2)))))

class WithFoxdenBalancedOpt extends Config(RocketTileEdit(tp => tp.copy(
  dcache = tp.dcache.map(_.copy(nSets = 64, nWays = 4, nMSHRs = 1)),
  icache = tp.icache.map(_.copy(nSets = 64, nWays = 4)))))

class WithFoxdenPerfOpt extends Config(RocketTileEdit(tp => tp.copy(
  dcache = tp.dcache.map(_.copy(nSets = 128, nWays = 8, nMSHRs = 2)),
  icache = tp.icache.map(_.copy(nSets = 128, nWays = 8)),
  core   = tp.core.copy(
    mulDiv = Some(MulDivParams(mulUnroll = 8, mulEarlyOut = true, divEarlyOut = true)),
    fastLoadWord = true,
    fastLoadByte = true))))

// ============================================================================
// FPU trim mixins - useful when squeezing an OoO core onto a small part
// ============================================================================

/** Disable FPU entirely. Linux kernel must be built without hard-float. */
class WithFoxdenNoFPU extends WithoutFPU

/** Keep FPU but drop the fdiv / fsqrt unit (large in LUTs and slow). */
class WithFoxdenFPUNoDivSqrt extends WithFPUWithoutDivSqrt

// ============================================================================
// Memory-system mixins - not EXT flags, but exposed to the GUI for tuning
// ============================================================================

/** Convert L1 D$ to a non-blocking cache with N MSHRs. */
class WithFoxdenNonblockingL1(n: Int = 2) extends WithNonblockingL1(n)

/** Tune the SiFive inclusive L2 cache block size. */
class WithFoxdenCacheBlock(bytes: Int = 64) extends WithCacheBlockBytes(bytes)
