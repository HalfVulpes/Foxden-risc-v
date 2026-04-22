# SPDX-License-Identifier: Apache-2.0
# Foxden-risc-v — standalone Makefile
#
# Produces the FIRRTL / Verilog / VHDL-wrapper artefacts for a chosen
# Foxden configuration, plus (optionally) a Vivado project and bitstream.
# No git submodules, no network access required at build time.

# --- configuration -----------------------------------------------------------

ifneq (,$(wildcard workspace/config))
include workspace/config
endif

BOARD           ?= rk-xcku5p
CONFIG          ?= Foxden_IO_RV64GC_4_L2W
HW_SERVER_ADDR  ?= localhost:3121
JAVA_OPTIONS    ?=
CFG_FORMAT      ?= mcs
EXT             ?=            # csv list, e.g. EXT=zicond,nmi
OPT             ?= balance    # area | balance | performance

include board/$(BOARD)/Makefile.inc

all: bitstream

# --- toolchain ---------------------------------------------------------------

JAVA_VERSION    ?= 17
JAVA_PATH       ?= /usr/lib/jvm/java-$(JAVA_VERSION)-openjdk-amd64/bin
CROSS_COMPILE_LINUX = /usr/bin/riscv64-linux-gnu-

# Bare-metal (newlib) toolchain for the bootrom. We prefer the
# riscv64-unknown-elf-gcc built by the vivado-risc-v project; if not
# found we fall back to $PATH; if still missing, error with a hint.
FOXDEN_BARE_TOOLCHAIN := $(firstword \
  $(wildcard $(CURDIR)/workspace/gcc/riscv/bin/riscv64-unknown-elf-gcc) \
  $(wildcard $(CURDIR)/../RISC-V-CPU/workspace/gcc/riscv/bin/riscv64-unknown-elf-gcc) \
  $(shell command -v riscv64-unknown-elf-gcc))
ifeq ($(FOXDEN_BARE_TOOLCHAIN),)
  # No bare-metal toolchain found: the bootrom make rule will fail with
  # a helpful message. Everything else still works.
  CROSS_COMPILE_NO_OS_TOOLS ?= riscv64-unknown-elf-
else
  CROSS_COMPILE_NO_OS_TOOLS ?= $(dir $(FOXDEN_BARE_TOOLCHAIN))riscv64-unknown-elf-
endif
CROSS_COMPILE_NO_OS_FLAGS ?= -march=rv64imac -mabi=lp64

SBT := $(JAVA_PATH)/java -Xmx12G -Xss8M $(JAVA_OPTIONS) \
       -Dsbt.io.virtual=false -Dsbt.server.autostart=false \
       -jar $(realpath sbt-launch.jar)

FIRRTL = $(JAVA_PATH)/java -Xmx12G -Xss8M $(JAVA_OPTIONS) \
         -cp `realpath target/scala-*/foxden.jar` firrtl.stage.FirrtlMain

# --- extension / optimization mixins ----------------------------------------
#
# EXT=zicond,nmi,hypervisor,zbb  -> foxden.WithFoxdenZicond ++ foxden.WithFoxdenNMI ...
# OPT=area | balance | performance -> foxden.WithFoxdenAreaOpt etc.

comma := ,
ext_list := $(subst $(comma), ,$(EXT))

ext_map = $(strip \
  $(if $(filter zicond,$(1)),foxden.WithFoxdenZicond,)\
  $(if $(filter zfh zfhmin,$(1)),foxden.WithFoxdenZfh,)\
  $(if $(filter zihintpause,$(1)),foxden.WithFoxdenZihintpause,)\
  $(if $(filter zba,$(1)),foxden.WithFoxdenZba,)\
  $(if $(filter zbb,$(1)),foxden.WithFoxdenZbb,)\
  $(if $(filter zbs,$(1)),foxden.WithFoxdenZbs,)\
  $(if $(filter zbc,$(1)),foxden.WithFoxdenZbc,)\
  $(if $(filter b bitmanip,$(1)),foxden.WithFoxdenZba foxden.WithFoxdenZbb foxden.WithFoxdenZbs,)\
  $(if $(filter zicbom zicboz,$(1)),foxden.WithFoxdenZicbom,)\
  $(if $(filter zacas,$(1)),foxden.WithFoxdenZacas,)\
  $(if $(filter zk crypto,$(1)),foxden.WithFoxdenZk,)\
  $(if $(filter aia,$(1)),foxden.WithFoxdenAIA,)\
  $(if $(filter svpbmt,$(1)),foxden.WithFoxdenSvpbmt,)\
  $(if $(filter svinval,$(1)),foxden.WithFoxdenSvinval,)\
  $(if $(filter nmi,$(1)),foxden.WithFoxdenNMI,)\
  $(if $(filter rve e,$(1)),foxden.WithFoxdenRVE,)\
  $(if $(filter noc,$(1)),foxden.WithFoxdenNoC,)\
  $(if $(filter cflush,$(1)),foxden.WithFoxdenCFlush,)\
  $(if $(filter clockgate,$(1)),foxden.WithFoxdenClockGate,)\
  $(if $(filter nocease,$(1)),foxden.WithFoxdenNoCease,)\
  $(if $(filter h hypervisor,$(1)),foxden.WithFoxdenHypervisor,)\
  $(if $(filter v vector,$(1)),foxden.WithFoxdenVector,)\
  $(if $(filter v-ara,$(1)),foxden.WithFoxdenVectorAra,)\
  $(if $(filter nofpu,$(1)),foxden.WithFoxdenNoFPU,)\
  $(if $(filter fpu-nodivsqrt,$(1)),foxden.WithFoxdenFPUNoDivSqrt,)\
  $(if $(filter nonblocking-l1,$(1)),foxden.WithFoxdenNonblockingL1,))

opt_map = $(strip \
  $(if $(filter area,$(1)),foxden.WithFoxdenAreaOpt,)\
  $(if $(filter balance,$(1)),foxden.WithFoxdenBalancedOpt,)\
  $(if $(filter performance perf,$(1)),foxden.WithFoxdenPerfOpt,))

EXT_CONFIGS := $(foreach e,$(ext_list),$(call ext_map,$(e)))
OPT_CONFIG  := $(call opt_map,$(OPT))

# Stacked config list (left-to-right = outer-to-inner in CDE)
CONFIG_LIST := $(strip $(EXT_CONFIGS) $(OPT_CONFIG) foxden.$(CONFIG))

# --- clock / timebase --------------------------------------------------------

FOXDEN_FREQ_MHZ ?= $(shell awk '$$3 != "" && "$(BOARD)" ~ $$1 && "$(CONFIG)" ~ ("^" $$2 "$$") {print $$3; exit}' board/common/foxden-freq)
FOXDEN_FREQ_MHZ ?= 100
FOXDEN_CLOCK_FREQ    := $(shell echo - | awk '{printf("%.0f\n", $(FOXDEN_FREQ_MHZ) * 1000000)}')
FOXDEN_TIMEBASE_FREQ := $(shell echo - | awk '{printf("%.0f\n", $(FOXDEN_FREQ_MHZ) * 10000)}')

MEMORY_SIZE ?= 0x80000000
ifeq ($(shell echo $$(($(MEMORY_SIZE) <= 0x80000000))),1)
  MEMORY_ADDR_RANGE32 = 0x80000000 $(MEMORY_SIZE)
  MEMORY_ADDR_RANGE64 = 0x0 0x80000000 0x0 $(MEMORY_SIZE)
else
  MEMORY_ADDR_RANGE32 = 0x80000000 0x80000000
  MEMORY_ADDR_RANGE64 = 0x0 0x80000000 0x3 0x80000000
endif

# --- Chisel sources ----------------------------------------------------------

CHISEL_SRC_DIRS = \
  src/main \
  generators/rocket-chip/src/main \
  generators/rocket-chip/macros/src/main \
  generators/rocket-chip/hardfloat/src/main \
  generators/riscv-boom/src/main \
  generators/sifive-cache/design/craft \
  generators/testchipip/src/main

CHISEL_SRC := $(foreach p,$(CHISEL_SRC_DIRS),$(shell test -d $(p) && find $(p) -iname "*.scala" -not -name ".*"))

# --- HDL generation ----------------------------------------------------------

workspace/$(CONFIG)/system.dts: $(CHISEL_SRC) bootrom/bootrom.img.placeholder
	rm -rf workspace/$(CONFIG)/tmp
	mkdir -p workspace/$(CONFIG)/tmp workspace
	cp bootrom/bootrom.img.placeholder workspace/bootrom.img
	$(SBT) "runMain freechips.rocketchip.diplomacy.Main \
	  --dir `realpath workspace/$(CONFIG)/tmp` \
	  --top foxden.FoxdenSystem \
	  $(foreach c,$(CONFIG_LIST),--config $(c))"
	mv workspace/$(CONFIG)/tmp/$(subst $() ,_,$(CONFIG_LIST)).dts workspace/$(CONFIG)/system.dts 2>/dev/null || \
	  mv workspace/$(CONFIG)/tmp/*.dts workspace/$(CONFIG)/system.dts
	rm -rf workspace/$(CONFIG)/tmp

workspace/$(CONFIG)/system-$(BOARD)/FoxdenSystem.fir: workspace/$(CONFIG)/system.dts $(wildcard bootrom/*)
	rm -rf workspace/$(CONFIG)/system-$(BOARD)
	mkdir -p workspace/$(CONFIG)/system-$(BOARD)
	cat workspace/$(CONFIG)/system.dts board/$(BOARD)/bootrom.dts >bootrom/system.dts
	sed -i "s#reg = <0x80000000 *0x.*>#reg = <$(MEMORY_ADDR_RANGE32)>#g" bootrom/system.dts
	sed -i "s#reg = <0x0 0x80000000 *0x.*>#reg = <$(MEMORY_ADDR_RANGE64)>#g" bootrom/system.dts
	sed -i "s#clock-frequency = <[0-9]*>#clock-frequency = <$(FOXDEN_CLOCK_FREQ)>#g" bootrom/system.dts
	sed -i "s#timebase-frequency = <[0-9]*>#timebase-frequency = <$(FOXDEN_TIMEBASE_FREQ)>#g" bootrom/system.dts
	@# Foxden branding for lscpu / /proc/cpuinfo: rewrite the cpu compatible
	@# node name so Linux shows a Foxden string as the first token
	sed -i 's#compatible = "sifive,rocket0", "riscv"#compatible = "foxden,foxden-core", "sifive,rocket0", "riscv"#g' bootrom/system.dts || true
	sed -i 's#compatible = "ucb-bar,boom0", "riscv"#compatible = "foxden,foxden-ooo-core", "ucb-bar,boom0", "riscv"#g' bootrom/system.dts || true
	sed -i 's#compatible = "sifive,boom0", "riscv"#compatible = "foxden,foxden-ooo-core", "sifive,boom0", "riscv"#g' bootrom/system.dts || true
	if [ ! -z "$(ETHER_MAC)" ] ; then sed -i "s#local-mac-address = \[.*\]#local-mac-address = [$(ETHER_MAC)]#g" bootrom/system.dts ; fi
	if [ ! -z "$(ETHER_PHY)" ] ; then sed -i "s#phy-mode = \".*\"#phy-mode = \"$(ETHER_PHY)\"#g" bootrom/system.dts ; fi
	sed -i "/interrupts-extended = <&.* 65535>;/d" bootrom/system.dts
	$(MAKE) -C bootrom CROSS_COMPILE="$(CROSS_COMPILE_NO_OS_TOOLS)" \
	  CFLAGS="$(CROSS_COMPILE_NO_OS_FLAGS)" BOARD=$(BOARD) clean bootrom.img
	mv bootrom/system.dts workspace/$(CONFIG)/system-$(BOARD).dts
	mv bootrom/bootrom.img workspace/bootrom.img
	$(SBT) "runMain freechips.rocketchip.diplomacy.Main \
	  --dir `realpath workspace/$(CONFIG)/system-$(BOARD)` \
	  --top foxden.FoxdenSystem \
	  $(foreach c,$(CONFIG_LIST),--config $(c))"
	$(SBT) assembly
	rm workspace/bootrom.img

workspace/$(CONFIG)/system-$(BOARD).v: workspace/$(CONFIG)/system-$(BOARD)/FoxdenSystem.fir
	$(FIRRTL) -i $< -o FoxdenSystem.v --compiler verilog \
	  --annotation-file workspace/$(CONFIG)/system-$(BOARD)/FoxdenSystem.anno.json \
	  --custom-transforms firrtl.passes.InlineInstances \
	  --target:fpga
	cp workspace/$(CONFIG)/system-$(BOARD)/FoxdenSystem.v workspace/$(CONFIG)/system-$(BOARD).v

workspace/$(CONFIG)/rocket.vhdl: workspace/$(CONFIG)/system-$(BOARD).v
	mkdir -p vhdl-wrapper/bin
	$(JAVA_PATH)/javac -g -nowarn \
	  -sourcepath vhdl-wrapper/src -d vhdl-wrapper/bin \
	  -classpath vhdl-wrapper/antlr-4.8-complete.jar \
	  vhdl-wrapper/src/net/largest/riscv/vhdl/Main.java
	$(JAVA_PATH)/java -Xmx4G -Xss8M $(JAVA_OPTIONS) -cp \
	  vhdl-wrapper/src:vhdl-wrapper/bin:vhdl-wrapper/antlr-4.8-complete.jar \
	  net.largest.riscv.vhdl.Main -m FoxdenSystem -t FoxdenSystem \
	  workspace/$(CONFIG)/system-$(BOARD).v >$@

bootrom/bootrom.img.placeholder:
	@mkdir -p bootrom
	@printf '\x00%.0s' $$(seq 1 64) > $@

# --- high-level convenience targets -----------------------------------------

.PHONY: all hdl verilog dts clean list-configs list-extensions gui sbt

hdl: workspace/$(CONFIG)/rocket.vhdl
verilog: workspace/$(CONFIG)/system-$(BOARD).v
dts: workspace/$(CONFIG)/system.dts

list-configs:
	@echo "Foxden built-in configurations:"
	@grep -hE "^class Foxden_[A-Z]" src/main/scala/foxden/configs/*.scala | \
	  sed -E 's/class (Foxden_[A-Za-z0-9_]+).*/  \1/'

list-extensions:
	@echo "Foxden EXT options (comma-separated):"
	@echo ""
	@echo "  --- hardware-backed on the vendored rocket-chip ---"
	@echo "  zicond             Zicond (conditional integer ops - czero.eqz/nez)"
	@echo "  zfh, zfhmin        Half-precision float (WithFP16)"
	@echo "  zihintpause        Advisory - always present on rocket tiles"
	@echo "  nmi                Non-maskable interrupts"
	@echo "  rve, e             RV64E embedded ABI (16 registers)"
	@echo "  noc                Drop the C-extension (RVGC -> RVG)"
	@echo "  cflush             Non-standard L1 flush instruction"
	@echo "  clockgate          EICG clock gating for tiles"
	@echo "  nocease            Disable CEASE instruction"
	@echo "  hypervisor, h      H-extension / hypervisor"
	@echo "  nofpu              Drop FPU entirely"
	@echo "  fpu-nodivsqrt      Keep FPU but drop FDIV / FSQRT"
	@echo "  nonblocking-l1     L1 D\$$ -> non-blocking (2 MSHRs)"
	@echo ""
	@echo "  --- advisory-only on this rocket-chip (no HW; DTS only) ---"
	@echo "  zba, zbb, zbs, zbc Bitmanip sub-extensions"
	@echo "  b, bitmanip        Alias for zba + zbb + zbs"
	@echo "  zicbom, zicboz     Cache-block ops"
	@echo "  zacas              Atomic compare-and-swap"
	@echo "  zk, crypto         Zk scalar crypto (NIST)"
	@echo "  aia                Sm/Ss-AIA advanced interrupts"
	@echo "  svpbmt, svinval    Virtual memory sub-extensions"
	@echo ""
	@echo "  --- vector (requires companion generator drop) ---"
	@echo "  vector, v          RVV 1.0 via Saturn    (fails until vendored)"
	@echo "  v-ara              RVV 1.0 via Ara       (fails until vendored)"
	@echo ""
	@echo "Foxden OPT options: area | balance | performance"

sbt:
	$(SBT)

gui:
	python3 gui/foxden_configurator.py

clean:
	rm -rf workspace target project/target project/project/target \
	  generators/*/target generators/rocket-chip/target \
	  generators/rocket-chip/macros/target generators/rocket-chip/hardfloat/target \
	  vhdl-wrapper/bin

# --- Vivado integration ------------------------------------------------------

FPGA_FNM    ?= riscv_wrapper.bit
proj_name   := $(BOARD)-foxden
proj_path   := workspace/$(CONFIG)/vivado-$(proj_name)
proj_file   := $(proj_path)/$(proj_name).xpr
proj_time   := $(proj_path)/timestamp.txt
synthesis   := $(proj_path)/$(proj_name).runs/synth_1/riscv_wrapper.dcp
bitstream   := $(proj_path)/$(proj_name).runs/impl_1/$(FPGA_FNM)
cfgmem_file := workspace/$(CONFIG)/$(proj_name).$(CFG_FORMAT)
prm_file    := workspace/$(CONFIG)/$(proj_name).prm
vivado       = env XILINX_LOCAL_USER_DATA=no vivado -mode batch -nojournal -nolog -notrace -quiet

workspace/$(CONFIG)/system-$(BOARD).tcl: workspace/$(CONFIG)/rocket.vhdl workspace/$(CONFIG)/system-$(BOARD).v board/$(BOARD)/Makefile.inc
	echo "set vivado_board_name $(BOARD)" >$@
	if [ "$(BOARD_PART)" != "" -a "$(BOARD_PART)" != "NONE" ] ; then echo "set vivado_board_part $(BOARD_PART)" >>$@ ; fi
	if [ "$(BOARD_CONFIG)" != "" ] ; then echo "set board_config $(BOARD_CONFIG)" >>$@ ; fi
	echo "set xilinx_part $(XILINX_PART)" >>$@
	echo "set rocket_module_name FoxdenSystem" >>$@
	echo "set riscv_clock_frequency $(FOXDEN_FREQ_MHZ)" >>$@
	echo "set memory_size $(MEMORY_SIZE)" >>$@
	echo 'cd [file dirname [file normalize [info script]]]' >>$@
	echo 'source ../../vivado.tcl' >>$@

vivado-tcl: workspace/$(CONFIG)/system-$(BOARD).tcl

$(proj_time): workspace/$(CONFIG)/system-$(BOARD).tcl
	if [ ! -e $(proj_path) ] ; then $(vivado) -source workspace/$(CONFIG)/system-$(BOARD).tcl || ( rm -rf $(proj_path) ; exit 1 ) ; fi
	date >$@

vivado-project: $(proj_time)

MAX_THREADS ?= 1

$(synthesis): $(proj_time)
	echo "set_param general.maxThreads $(MAX_THREADS)" >$(proj_path)/make-synthesis.tcl
	echo "open_project $(proj_file)" >>$(proj_path)/make-synthesis.tcl
	echo "update_compile_order -fileset sources_1" >>$(proj_path)/make-synthesis.tcl
	echo "reset_run synth_1" >>$(proj_path)/make-synthesis.tcl
	echo "launch_runs -jobs $(MAX_THREADS) synth_1" >>$(proj_path)/make-synthesis.tcl
	echo "wait_on_run synth_1" >>$(proj_path)/make-synthesis.tcl
	$(vivado) -source $(proj_path)/make-synthesis.tcl
	if find $(proj_path) -name "*.log" -exec cat {} \; | grep 'ERROR: ' ; then exit 1 ; fi

$(bitstream): $(synthesis)
	echo "set_param general.maxThreads $(MAX_THREADS)" >$(proj_path)/make-bitstream.tcl
	echo "open_project $(proj_file)" >>$(proj_path)/make-bitstream.tcl
	echo "reset_run impl_1" >>$(proj_path)/make-bitstream.tcl
	echo "launch_runs -to_step write_bitstream -jobs $(MAX_THREADS) impl_1" >>$(proj_path)/make-bitstream.tcl
	echo "wait_on_run impl_1" >>$(proj_path)/make-bitstream.tcl
	$(vivado) -source $(proj_path)/make-bitstream.tcl
	if find $(proj_path) -name "*.log" -exec cat {} \; | grep 'ERROR: ' ; then exit 1 ; fi

ifeq ($(CFG_BOOT),)
  CFG_FILES = $(bitstream)
else
  CFG_FILES = $(bitstream) workspace/boot.elf
endif

$(cfgmem_file) $(prm_file): $(CFG_FILES)
	echo "open_project $(proj_file)" >$(proj_path)/make-mcs.tcl
	echo "write_cfgmem -format $(CFG_FORMAT) -interface $(CFG_DEVICE) -loadbit {up 0x0 $(bitstream)} $(CFG_BOOT) -file $(cfgmem_file) -force" >>$(proj_path)/make-mcs.tcl
	$(vivado) -source $(proj_path)/make-mcs.tcl

bitstream: $(bitstream) $(cfgmem_file)

flash: $(cfgmem_file) $(prm_file)
	env HW_SERVER_URL=tcp:$(HW_SERVER_ADDR) \
	 xsdb -quiet board/common/jtag-freq.tcl
	env HW_SERVER_ADDR=$(HW_SERVER_ADDR) \
	env CFG_PART=$(CFG_PART) \
	env mcs_file=$(cfgmem_file) \
	env prm_file=$(prm_file) \
	 $(vivado) -source board/common/program-flash.tcl

vivado-gui: $(proj_time)
	vivado $(proj_file)
