# SPDX-License-Identifier: Apache-2.0
# Foxden Vivado project scaffold. The generated SoC module is FoxdenSystem
# (wrapped by rocket.vhdl) and is instanced inside the board's RiscV block
# design as "RocketChip" - we keep that instance name for source compatibility
# with the vivado-risc-v board definitions.

set _board_files_path [file normalize "../../board/${vivado_board_name}/board_files"]
if {[file isdirectory $_board_files_path]} {
   set_param board.repoPaths [list $_board_files_path]
}

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project ${vivado_board_name}-foxden vivado-${vivado_board_name}-foxden -part ${xilinx_part}
   if {[info exists vivado_board_part]} {
      set_property BOARD_PART ${vivado_board_part} [current_project]
   }
}

if {[string equal [get_filesets -quiet sources_1] ""]} { create_fileset -srcset sources_1 }
if {[string equal [get_filesets -quiet constrs_1] ""]} { create_fileset -constrset constrs_1 }

set source_fileset [get_filesets sources_1]
set constraint_fileset [get_filesets constrs_1]

set files [list \
 [file normalize "rocket.vhdl"] \
 [file normalize "system-${vivado_board_name}.v"] \
 [file normalize "../../uart/uart.v"] \
 [file normalize "../../sdc/sd_defines.h"] \
 [file normalize "../../sdc/axi_sdc_controller.v"] \
 [file normalize "../../sdc/sd_cmd_master.v"] \
 [file normalize "../../sdc/sd_cmd_serial_host.v"] \
 [file normalize "../../sdc/sd_data_master.v"] \
 [file normalize "../../sdc/sd_data_serial_host.v"] \
 [file normalize "../../vhdl-wrapper/src/net/largest/riscv/vhdl/bscan2jtag.vhdl"] \
 [file normalize "../../board/common/mem-reset-control.v"] \
 [file normalize "../../board/common/fan-control.v"] \
]
add_files -norecurse -fileset $source_fileset $files

if {[file exists "../../board/${vivado_board_name}/ethernet-${vivado_board_name}.v"]} {
  add_files -norecurse -fileset $source_fileset [file normalize "../../board/${vivado_board_name}/ethernet-${vivado_board_name}.v"]
}

set files [list \
 [file normalize ../../board/${vivado_board_name}/top.xdc] \
 [file normalize ../../board/${vivado_board_name}/sdc.xdc] \
 [file normalize ../../board/${vivado_board_name}/uart.xdc] \
]
add_files -norecurse -fileset $constraint_fileset $files

set block_design_ver [split [version -short] .]
set block_design_tcl "riscv-[lindex $block_design_ver 0].[lindex $block_design_ver 1].tcl"

source ../../board/${vivado_board_name}/ethernet-${vivado_board_name}.tcl

add_files -norecurse -fileset $constraint_fileset [file normalize ../../board/common/timing-constraints.tcl]

set file_obj [get_files -of_objects $source_fileset [list "*/*.vhdl"]]
set_property -name "file_type" -value "VHDL" -objects $file_obj

set file_obj [get_files -of_objects $constraint_fileset [list "*/*.xdc"]]
set_property -name "file_type" -value "XDC" -objects $file_obj
set_property -name "used_in" -value "implementation" -objects $file_obj
set_property -name "used_in_synthesis" -value "0" -objects $file_obj

set file_obj [get_files -of_objects $constraint_fileset [list "*/*.tcl"]]
set_property -name "file_type" -value "TCL" -objects $file_obj
set_property -name "used_in" -value "implementation" -objects $file_obj
set_property -name "used_in_synthesis" -value "0" -objects $file_obj

# Make sure the fileset is indexed before the board's BD TCL runs.
# NOTE: Vivado 2023.2 has a known quirk where auto-inference of AXI4
# bus interfaces on a VHDL entity added via `create_bd_cell -type
# module -reference` can silently fail on a completely fresh project,
# producing `[BD 5-232] No interface pins matched RocketChip/DMA_AXI4`
# during the subsequent `connect_bd_intf_net`. The VHDL we emit does
# carry the full set of X_INTERFACE_INFO attributes, so existing /
# cached projects work fine. For a fresh project, the reliable
# workaround is to build Foxden via the legacy RISC-V-CPU flow with
# FOXDEN=1, which has the IP catalog already primed. See docs/STATUS.md.
update_compile_order -fileset $source_fileset

source ../../board/${vivado_board_name}/${block_design_tcl}

if { [llength [get_bd_intf_pins -quiet RocketChip/JTAG]] == 1 } {
  create_bd_cell -type module -reference bscan2jtag JTAG
  connect_bd_intf_net -intf_net JTAG [get_bd_intf_pins JTAG/JTAG] [get_bd_intf_pins RocketChip/JTAG]
  create_bd_cell -type ip -vlnv xilinx.com:ip:debug_bridge:3.0 BSCAN
  set_property -dict [list CONFIG.C_DEBUG_MODE {7} CONFIG.C_USER_SCAN_CHAIN {1} CONFIG.C_NUM_BS_MASTER {1}] [get_bd_cells BSCAN]
  connect_bd_intf_net -intf_net BSCAN [get_bd_intf_pins BSCAN/m0_bscan] [get_bd_intf_pins JTAG/S_BSCAN]
} elseif { [llength [get_bd_intf_pins -quiet RocketChip/S_BSCAN]] == 1 } {
  create_bd_cell -type ip -vlnv xilinx.com:ip:debug_bridge:3.0 BSCAN
  set_property -dict [list CONFIG.C_DEBUG_MODE {7} CONFIG.C_USER_SCAN_CHAIN {1} CONFIG.C_NUM_BS_MASTER {1}] [get_bd_cells BSCAN]
  connect_bd_intf_net -intf_net BSCAN [get_bd_intf_pins BSCAN/m0_bscan] [get_bd_intf_pins RocketChip/S_BSCAN]
}

set_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $riscv_clock_frequency [get_bd_cells clk_wiz_0]
validate_bd_design
regenerate_bd_layout
save_bd_design

if { [get_files -quiet -of_objects $source_fileset [list "*/riscv_wrapper.v"]] == "" } {
  make_wrapper -files [get_files riscv.bd] -top -import
}
set_property top riscv_wrapper $source_fileset
update_compile_order -fileset $source_fileset
