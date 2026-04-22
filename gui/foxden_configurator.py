#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Foxden-risc-v Configurator
#
# Vivado-IP-configurator-style GUI for picking a Foxden SoC configuration,
# extensions, optimisation profile and board.  Emits a workspace/config
# file that the top-level Makefile picks up, then optionally invokes
# `make hdl` or `make bitstream` in a terminal.
#
# Design notes:
#   - Pure standard-library Tk/ttk; no pip install needed.
#   - Mirrors the layout of Xilinx MicroBlaze IP configurator: a left
#     summary pane + a right tabbed configuration pane.
#   - Saves / loads .foxden JSON presets so teams can share a profile.

import json
import os
import re
import subprocess
import sys
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

FOXDEN_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CONFIGS_DIR = os.path.join(FOXDEN_ROOT, "src", "main", "scala", "foxden", "configs")
WORKSPACE   = os.path.join(FOXDEN_ROOT, "workspace")

# ---------------------------------------------------------------------------
# Introspect Foxden configs from the Scala sources

CONFIG_FAMILIES = {
    "1. In-order RV64GC (Linux)":          "Foxden_IO_RV64GC_",
    "2. Lowest-area out-of-order":         "Foxden_OoO_Small_",
    "3. Medium out-of-order":              "Foxden_OoO_Medium_",
    "4. Highest-performance single core":  "Foxden_OoO_",      # Large_1 / Mega_1
    "5. XiangShan Nanhu flagship (reserved)": "Foxden_OoO_XS_", # placeholder
}

def scan_configs():
    if not os.path.isdir(CONFIGS_DIR):
        return []
    names = []
    for fn in os.listdir(CONFIGS_DIR):
        if not fn.endswith(".scala"): continue
        with open(os.path.join(CONFIGS_DIR, fn)) as fh:
            for line in fh:
                m = re.match(r"\s*class\s+(Foxden_[A-Za-z0-9_]+)\b", line)
                if m: names.append(m.group(1))
    return sorted(set(names))

def configs_for_family(prefix):
    return [c for c in scan_configs() if c.startswith(prefix)]

# ---------------------------------------------------------------------------
# GUI

BOARDS = ["rk-xcku5p", "nexys-video", "genesys2", "vc707", "u200", "u250"]
OPTIMIZATIONS = ["balance", "area", "performance"]
EXTENSIONS = [
    # Hardware-backed on the vendored rocket-chip
    ("zicond",         "Zicond (conditional integer)"),
    ("zfh",            "Zfh (half-precision float)"),
    ("nmi",            "Non-maskable interrupts"),
    ("hypervisor",     "H-extension / hypervisor"),
    ("rve",            "RV64E embedded (16 regs)"),
    ("noc",            "Disable compressed (RVG)"),
    ("cflush",         "Non-standard L1 flush instruction"),
    ("clockgate",      "EICG clock-gate tiles"),
    ("nocease",        "Disable CEASE instruction"),
    ("zihintpause",    "Zihintpause (always present; advisory)"),
    # Advisory only
    ("zba",            "Zba bitmanip - advisory (DTS only)"),
    ("zbb",            "Zbb bitmanip - advisory (DTS only)"),
    ("zbs",            "Zbs bitmanip - advisory (DTS only)"),
    ("zbc",            "Zbc carryless mul - advisory"),
    ("b",              "B (Zba+Zbb+Zbs bundle)"),
    ("zicbom",         "Zicbom/Zicboz cache ops - advisory"),
    ("zacas",          "Zacas atomic CAS - advisory"),
    ("zk",             "Zk scalar crypto - advisory"),
    ("aia",            "Sm/Ss-AIA advanced interrupts - advisory"),
    ("svpbmt",         "Svpbmt page memtypes - advisory"),
    ("svinval",        "Svinval fine-grain TLB inval - advisory"),
    # Vector (requires companion generator)
    ("vector",         "RVV 1.0 via Saturn (not vendored)"),
    ("v-ara",          "RVV 1.0 via Ara (not vendored)"),
    # FPU / memory trim
    ("nofpu",          "Drop FPU entirely"),
    ("fpu-nodivsqrt",  "FPU without FDIV/FSQRT"),
    ("nonblocking-l1", "Non-blocking L1 D$ (2 MSHRs)"),
]

class FoxdenConfiguratorApp(tk.Tk):

    def __init__(self):
        super().__init__()
        self.title("Foxden-risc-v Configurator - v1.0")
        self.geometry("980x680")
        self.minsize(900, 600)
        self._apply_style()
        self._build()
        self._reload_configs()
        self._update_summary()

    # ---- style ---------------------------------------------------------

    def _apply_style(self):
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("Header.TLabel", font=("TkDefaultFont", 12, "bold"))
        style.configure("Title.TLabel",  font=("TkDefaultFont", 14, "bold"))
        style.configure("Summary.TLabel", font=("TkFixedFont", 10))

    # ---- layout --------------------------------------------------------

    def _build(self):
        root = ttk.Frame(self, padding=8)
        root.pack(fill="both", expand=True)

        banner = ttk.Frame(root)
        banner.pack(fill="x", pady=(0, 8))
        ttk.Label(banner, text="Foxden-risc-v Configurator",
                  style="Title.TLabel").pack(side="left")
        ttk.Label(banner, text="Vivado / KU5P ready softcore generator",
                  foreground="#555").pack(side="left", padx=12)

        body = ttk.Frame(root)
        body.pack(fill="both", expand=True)

        left = ttk.LabelFrame(body, text="Summary", padding=8)
        left.pack(side="left", fill="y", padx=(0, 8))
        self.summary = tk.Text(left, width=38, height=30, wrap="word",
                               font=("TkFixedFont", 10),
                               relief="flat", background="#f3f3f5")
        self.summary.pack(fill="both", expand=True)
        self.summary.configure(state="disabled")

        nb = ttk.Notebook(body)
        nb.pack(side="left", fill="both", expand=True)
        self._build_tab_general(nb)
        self._build_tab_memory(nb)
        self._build_tab_extensions(nb)
        self._build_tab_optimization(nb)
        self._build_tab_peripherals(nb)

        actions = ttk.Frame(root)
        actions.pack(fill="x", pady=(10, 0))
        ttk.Button(actions, text="Load preset",
                   command=self._load_preset).pack(side="left")
        ttk.Button(actions, text="Save preset",
                   command=self._save_preset).pack(side="left", padx=(6, 16))
        ttk.Button(actions, text="Write workspace/config",
                   command=self._write_workspace_config).pack(side="left")
        ttk.Button(actions, text="Generate HDL (make hdl)",
                   command=lambda: self._run_make("hdl")).pack(side="left", padx=6)
        ttk.Button(actions, text="Open in Vivado (make vivado-project)",
                   command=lambda: self._run_make("vivado-project")).pack(side="left")
        ttk.Button(actions, text="Close",
                   command=self.destroy).pack(side="right")

    # ---- tabs ----------------------------------------------------------

    def _build_tab_general(self, nb):
        f = ttk.Frame(nb, padding=12); nb.add(f, text="General")

        ttk.Label(f, text="Configuration family", style="Header.TLabel")\
            .grid(row=0, column=0, sticky="w", pady=(0, 4))
        self.var_family = tk.StringVar(value=list(CONFIG_FAMILIES.keys())[0])
        cb_family = ttk.Combobox(f, values=list(CONFIG_FAMILIES.keys()),
                                 state="readonly", textvariable=self.var_family,
                                 width=45)
        cb_family.grid(row=0, column=1, sticky="we", pady=(0, 4))
        cb_family.bind("<<ComboboxSelected>>", lambda _: self._reload_configs())

        ttk.Label(f, text="Configuration", style="Header.TLabel")\
            .grid(row=1, column=0, sticky="w", pady=(4, 4))
        self.var_config = tk.StringVar()
        self.cb_config = ttk.Combobox(f, state="readonly",
                                      textvariable=self.var_config, width=45)
        self.cb_config.grid(row=1, column=1, sticky="we", pady=(4, 4))
        self.cb_config.bind("<<ComboboxSelected>>", lambda _: self._update_summary())

        ttk.Label(f, text="Target board", style="Header.TLabel")\
            .grid(row=2, column=0, sticky="w", pady=(4, 4))
        self.var_board = tk.StringVar(value="rk-xcku5p")
        ttk.Combobox(f, values=BOARDS, state="readonly", width=45,
                     textvariable=self.var_board)\
            .grid(row=2, column=1, sticky="we", pady=(4, 4))

        ttk.Label(f, text="Target clock (MHz)", style="Header.TLabel")\
            .grid(row=3, column=0, sticky="w", pady=(4, 4))
        self.var_clk = tk.StringVar(value="100")
        ttk.Spinbox(f, from_=25, to=250, increment=5, textvariable=self.var_clk,
                    width=10).grid(row=3, column=1, sticky="w", pady=(4, 4))

        ttk.Label(f, text="DRAM size (bytes, hex)", style="Header.TLabel")\
            .grid(row=4, column=0, sticky="w", pady=(4, 4))
        self.var_mem = tk.StringVar(value="0x80000000")
        ttk.Entry(f, textvariable=self.var_mem, width=20)\
            .grid(row=4, column=1, sticky="w", pady=(4, 4))

        f.columnconfigure(1, weight=1)
        for v in (self.var_family, self.var_config, self.var_board,
                  self.var_clk, self.var_mem):
            v.trace_add("write", lambda *_: self._update_summary())

    def _build_tab_memory(self, nb):
        f = ttk.Frame(nb, padding=12); nb.add(f, text="Memory subsystem")
        ttk.Label(f, text="The L1 cache sizes follow the optimisation profile.",
                  foreground="#555").grid(row=0, column=0, columnspan=3, sticky="w")

        self.var_l2_enable = tk.BooleanVar(value=True)
        ttk.Checkbutton(f, text="Enable SiFive inclusive L2 (WithInclusiveCache)",
                        variable=self.var_l2_enable,
                        command=self._update_summary)\
            .grid(row=1, column=0, columnspan=3, sticky="w", pady=6)
        self.var_l2_size = tk.StringVar(value="512KB")
        ttk.Label(f, text="L2 nominal size").grid(row=2, column=0, sticky="w")
        ttk.Combobox(f, values=["256KB", "512KB", "1MB", "2MB"], state="readonly",
                     textvariable=self.var_l2_size, width=12)\
            .grid(row=2, column=1, sticky="w", pady=(2, 6))

        self.var_wide_bus = tk.BooleanVar(value=True)
        ttk.Checkbutton(f, text="Use 256-bit memory edge (FoxdenWideBusConfig)",
                        variable=self.var_wide_bus,
                        command=self._update_summary)\
            .grid(row=3, column=0, columnspan=3, sticky="w", pady=6)

        ttk.Label(f, text="DRAM channels").grid(row=4, column=0, sticky="w")
        self.var_channels = tk.StringVar(value="1")
        ttk.Combobox(f, values=["1", "2", "4"], state="readonly",
                     textvariable=self.var_channels, width=6)\
            .grid(row=4, column=1, sticky="w", pady=(2, 6))

        for v in (self.var_l2_enable, self.var_l2_size,
                  self.var_wide_bus, self.var_channels):
            v.trace_add("write", lambda *_: self._update_summary())

    def _build_tab_extensions(self, nb):
        f = ttk.Frame(nb, padding=12); nb.add(f, text="Extensions")
        ttk.Label(f,
            text=("Foxden exposes optional RISC-V extensions via the EXT=... make\n"
                  "variable.  Some extensions (V) require additional vendor drops -\n"
                  "see docs/EXTENSIONS.md."),
            foreground="#555")\
            .grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 8))

        # Many extensions - lay them out in 3 columns so they fit without scrolling.
        self.vars_ext = {}
        per_col = (len(EXTENSIONS) + 2) // 3
        for i, (key, label) in enumerate(EXTENSIONS):
            v = tk.BooleanVar(value=False)
            self.vars_ext[key] = v
            col = i // per_col
            row = (i % per_col) + 1
            ttk.Checkbutton(f, text=label, variable=v,
                            command=self._update_summary)\
                .grid(row=row, column=col, sticky="w", padx=(0, 18), pady=2)

    def _build_tab_optimization(self, nb):
        f = ttk.Frame(nb, padding=12); nb.add(f, text="Optimisation")
        ttk.Label(f,
            text="Pick the synthesis profile for the soft-core.\n"
                 "Applied as an additional CDE mixin on top of the selected config.",
            foreground="#555").grid(row=0, column=0, sticky="w", pady=(0, 8))

        self.var_opt = tk.StringVar(value="balance")
        for i, o in enumerate(OPTIMIZATIONS):
            ttk.Radiobutton(f, text=o.capitalize(), value=o, variable=self.var_opt,
                            command=self._update_summary)\
                .grid(row=i+1, column=0, sticky="w", pady=4)

        hint = {
            "area": "Shrinks L1 caches, disables BTB, 2-way sets.  Fits tight LUT budgets.",
            "balance": "64-set / 4-way L1s, default BTB.  Sensible default.",
            "performance": "128-set / 8-way L1s, fast mul/div, fast load-word/byte.",
        }
        self.lbl_opt = ttk.Label(f, text=hint["balance"], foreground="#333",
                                 wraplength=500)
        self.lbl_opt.grid(row=10, column=0, sticky="w", pady=(10, 0))
        self.var_opt.trace_add("write",
            lambda *_: (self.lbl_opt.configure(text=hint[self.var_opt.get()]),
                        self._update_summary()))

    def _build_tab_peripherals(self, nb):
        f = ttk.Frame(nb, padding=12); nb.add(f, text="Peripherals")
        self.var_uart = tk.BooleanVar(value=True)
        self.var_eth  = tk.BooleanVar(value=True)
        self.var_sd   = tk.BooleanVar(value=True)
        self.var_debug_jtag = tk.BooleanVar(value=True)
        self.var_debug_bscan = tk.BooleanVar(value=True)
        ttk.Checkbutton(f, text="AXI UART (console)", variable=self.var_uart,
                        command=self._update_summary).grid(sticky="w", pady=2)
        ttk.Checkbutton(f, text="Gigabit Ethernet (RGMII)", variable=self.var_eth,
                        command=self._update_summary).grid(sticky="w", pady=2)
        ttk.Checkbutton(f, text="SD-card controller", variable=self.var_sd,
                        command=self._update_summary).grid(sticky="w", pady=2)
        ttk.Separator(f).grid(sticky="we", pady=6)
        ttk.Checkbutton(f, text="RISC-V debug over BSCAN (xsdb / OpenOCD)",
                        variable=self.var_debug_bscan,
                        command=self._update_summary).grid(sticky="w", pady=2)
        ttk.Checkbutton(f, text="Expose JTAG pins on connector",
                        variable=self.var_debug_jtag,
                        command=self._update_summary).grid(sticky="w", pady=2)

    # ---- behaviour -----------------------------------------------------

    def _reload_configs(self):
        prefix = CONFIG_FAMILIES[self.var_family.get()]
        candidates = configs_for_family(prefix)
        if prefix == "Foxden_OoO_":   # family #4 = Large / Mega
            candidates = [c for c in candidates
                          if c.startswith("Foxden_OoO_Large") or c.startswith("Foxden_OoO_Mega")]
        if not candidates:
            candidates = ["(no configs matched)"]
        self.cb_config.configure(values=candidates)
        if self.var_config.get() not in candidates:
            self.var_config.set(candidates[0])
        self._update_summary()

    def _collect(self):
        ext_list = [k for k, v in self.vars_ext.items() if v.get()]
        return {
            "CONFIG":   self.var_config.get(),
            "BOARD":    self.var_board.get(),
            "FOXDEN_FREQ_MHZ": self.var_clk.get(),
            "MEMORY_SIZE": self.var_mem.get(),
            "EXT":      ",".join(ext_list),
            "OPT":      self.var_opt.get(),
            "_gui_extra": {
                "l2_enable": self.var_l2_enable.get(),
                "l2_size":   self.var_l2_size.get(),
                "wide_bus":  self.var_wide_bus.get(),
                "channels":  self.var_channels.get(),
                "uart":      self.var_uart.get(),
                "eth":       self.var_eth.get(),
                "sd":        self.var_sd.get(),
                "bscan":     self.var_debug_bscan.get(),
                "jtag":      self.var_debug_jtag.get(),
            },
        }

    def _update_summary(self):
        cfg = self._collect()
        ext = cfg["EXT"] or "(none)"
        lines = [
            "== Foxden summary ==",
            "",
            f"Configuration   : {cfg['CONFIG']}",
            f"Board           : {cfg['BOARD']}",
            f"Core clock      : {cfg['FOXDEN_FREQ_MHZ']} MHz",
            f"DRAM size       : {cfg['MEMORY_SIZE']}",
            f"Optimisation    : {cfg['OPT']}",
            f"Extensions      : {ext}",
            "",
            "Memory subsystem:",
            f"  L2 enable     : {cfg['_gui_extra']['l2_enable']}",
            f"  L2 nominal    : {cfg['_gui_extra']['l2_size']}",
            f"  256-bit edge  : {cfg['_gui_extra']['wide_bus']}",
            f"  channels      : {cfg['_gui_extra']['channels']}",
            "",
            "Peripherals:",
            f"  UART   : {cfg['_gui_extra']['uart']}",
            f"  Eth    : {cfg['_gui_extra']['eth']}",
            f"  SD     : {cfg['_gui_extra']['sd']}",
            "",
            "Make invocation:",
            f"  make BOARD={cfg['BOARD']} CONFIG={cfg['CONFIG']} \\",
            f"       OPT={cfg['OPT']} EXT={cfg['EXT']} \\",
            f"       FOXDEN_FREQ_MHZ={cfg['FOXDEN_FREQ_MHZ']} \\",
            f"       MEMORY_SIZE={cfg['MEMORY_SIZE']} hdl",
        ]
        self.summary.configure(state="normal")
        self.summary.delete("1.0", "end")
        self.summary.insert("1.0", "\n".join(lines))
        self.summary.configure(state="disabled")

    # ---- file I/O ------------------------------------------------------

    def _write_workspace_config(self):
        cfg = self._collect()
        os.makedirs(WORKSPACE, exist_ok=True)
        path = os.path.join(WORKSPACE, "config")
        with open(path, "w") as fh:
            fh.write("# Written by foxden_configurator.py\n")
            for k in ("CONFIG", "BOARD", "FOXDEN_FREQ_MHZ",
                      "MEMORY_SIZE", "EXT", "OPT"):
                fh.write(f"{k} := {cfg[k]}\n")
        messagebox.showinfo("Foxden", f"Wrote {path}")

    def _save_preset(self):
        p = filedialog.asksaveasfilename(
            defaultextension=".foxden",
            filetypes=[("Foxden preset", "*.foxden"), ("All files", "*.*")])
        if not p: return
        with open(p, "w") as fh:
            json.dump(self._collect(), fh, indent=2)

    def _load_preset(self):
        p = filedialog.askopenfilename(
            filetypes=[("Foxden preset", "*.foxden"), ("All files", "*.*")])
        if not p: return
        with open(p) as fh:
            data = json.load(fh)
        self.var_config.set(data.get("CONFIG", ""))
        self.var_board.set(data.get("BOARD", "rk-xcku5p"))
        self.var_clk.set(str(data.get("FOXDEN_FREQ_MHZ", "100")))
        self.var_mem.set(data.get("MEMORY_SIZE", "0x80000000"))
        self.var_opt.set(data.get("OPT", "balance"))
        for k, v in self.vars_ext.items():
            v.set(k in (data.get("EXT") or "").split(","))
        extra = data.get("_gui_extra", {})
        self.var_l2_enable.set(extra.get("l2_enable", True))
        self.var_l2_size.set(extra.get("l2_size", "512KB"))
        self.var_wide_bus.set(extra.get("wide_bus", True))
        self.var_channels.set(extra.get("channels", "1"))
        self.var_uart.set(extra.get("uart", True))
        self.var_eth.set(extra.get("eth", True))
        self.var_sd.set(extra.get("sd", True))
        self.var_debug_bscan.set(extra.get("bscan", True))
        self.var_debug_jtag.set(extra.get("jtag", True))
        self._reload_configs()

    def _run_make(self, target):
        self._write_workspace_config()
        cfg = self._collect()
        cmd = ["make",
               f"BOARD={cfg['BOARD']}",
               f"CONFIG={cfg['CONFIG']}",
               f"OPT={cfg['OPT']}",
               f"EXT={cfg['EXT']}",
               f"FOXDEN_FREQ_MHZ={cfg['FOXDEN_FREQ_MHZ']}",
               f"MEMORY_SIZE={cfg['MEMORY_SIZE']}",
               target]
        print("Running:", " ".join(cmd))
        # Run in same terminal - builds are noisy and long
        subprocess.Popen(cmd, cwd=FOXDEN_ROOT)

# ---------------------------------------------------------------------------

def main():
    if not sys.stdout.isatty() and os.environ.get("DISPLAY") is None:
        print("Foxden configurator requires a graphical display ($DISPLAY).",
              file=sys.stderr)
        sys.exit(1)
    app = FoxdenConfiguratorApp()
    app.mainloop()

if __name__ == "__main__":
    main()
