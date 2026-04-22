# Migrating from RISC-V-CPU's rocket-chip flow to Foxden

The sibling `RISC-V-CPU/` project used to build its SoC from:

```
RISC-V-CPU/rocket-chip/                  (git submodule)
RISC-V-CPU/generators/{riscv-boom,...}   (git submodules)
RISC-V-CPU/src/main/scala/rocket.scala   (Vivado.Rocket* configs)
```

Foxden replaces all three with a standalone tree at
`Foxden-risc-v/`.  Nothing under `RISC-V-CPU/` has to be removed;
the old flow is preserved.  The switch is gated on a single Make
variable:

```bash
# Old flow (still works)
cd RISC-V-CPU
make BOARD=rk-xcku5p CONFIG=rocket64b4 bitstream

# New Foxden flow
cd RISC-V-CPU
make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W FOXDEN=1 bitstream
```

When `FOXDEN=1` is set, `RISC-V-CPU/foxden.mk` intercepts the HDL
targets and forwards to `Foxden-risc-v/` via its own Makefile. The
Vivado project creation, bitstream build, flash, and jtag-boot
targets in `RISC-V-CPU/Makefile` then run exactly as before against
the Foxden-generated `rocket.vhdl` + `system-$(BOARD).v`.

## Step-by-step

1. Make sure the sibling directory exists and Foxden-risc-v is cloned
   next to RISC-V-CPU:
   ```
   Desktop/
   ├── RISC-V-CPU/
   └── Foxden-risc-v/
   ```

2. (Optional) launch the Foxden GUI once to save `workspace/config`:
   ```bash
   cd Foxden-risc-v && make gui
   ```

3. From `RISC-V-CPU/`, invoke any existing target with `FOXDEN=1`:
   ```bash
   make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W FOXDEN=1 vivado-project
   make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W FOXDEN=1 bitstream
   make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W FOXDEN=1 flash
   ```

## Equivalent configuration map

| Legacy `CONFIG=`  | Foxden equivalent              |
|-------------------|--------------------------------|
| `rocket64b1`      | `Foxden_IO_RV64GC_1`           |
| `rocket64b2`      | `Foxden_IO_RV64GC_2`           |
| `rocket64b2l2`    | `Foxden_IO_RV64GC_2_L2`        |
| `rocket64b4`      | `Foxden_IO_RV64GC_4`           |
| `rocket64b4l2w`   | `Foxden_IO_RV64GC_4_L2W`       |
| `rocket64b8`      | `Foxden_IO_RV64GC_8`           |
| `rocket64w1`      | `Foxden_OoO_Small_1`           |
| `rocket64x1`      | `Foxden_OoO_Medium_1`          |
| `rocket64y1`      | `Foxden_OoO_Large_1`           |
| `rocket64z1`      | `Foxden_OoO_Mega_1`            |

## Environment impact

The RISC-V-CPU `linux`, `bootloader`, `debian-riscv64/*` targets are
**unchanged** - Foxden produces the same `workspace/bootrom.img` layout
and device-tree shape, so OpenSBI, U-Boot, and the Debian rootfs work as
before.

## Rolling back

Unset `FOXDEN` (or `FOXDEN=0`), and use any of the original `rocket64*`
configs. The old submodule tree under `RISC-V-CPU/rocket-chip/` is
left untouched.
