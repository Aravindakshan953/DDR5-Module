# DDR5-Style Memory Controller on a Virtex-7 FPGA

*Project DDR5_Finale · Verilog RTL · Xilinx/AMD Vivado v2026.1 · Synthesis run of 17 Oct 2026*

## Contents

1. [Overview](#1-overview)
2. [Target Device](#2-target-device)
3. [Architecture](#3-architecture)
4. [Subcomponents](#4-subcomponents)
5. [Parameters](#5-parameters)
6. [Variables (internal signals)](#6-variables-internal-signals)
7. [User I/O](#7-user-io)
8. [Synthesis Results](#8-synthesis-results-vivado-20261)
9. [XDC Constraints](#9-xdc-constraints-ddr5_constraintsxdc)
10. [Timing Summary](#10-timing-summary)
11. [Power Summary](#11-power-summary)
12. [Verification](#12-verification)

## 1. Overview

This project implements a simplified, DDR5-inspired memory controller in Verilog. A CPU-side handshake interface (`CPU_VALID`, `CPU_WE`, `CPU_READY`) accepts 64-bit read and write requests with a 20-bit address. The controller turns each request into the command sequence a DRAM needs: precharge, activate, burst read or write, and periodic refresh. It drives a 64-bit bidirectional data bus, a 4-bit bank address, a 14-bit row/column address and the command strobes toward an external memory.

The whole design is one flat module, `DDR5`, built around a six-state finite state machine (FSM), a refresh timer, a general-purpose timing counter and a 16-beat burst buffer pair.

> **Scope note.** The command interface (RAS#/CAS#/WE#, SSTL15 I/O, 14-bit address) follows the classic DDR3/DDR4 style, with DDR5's burst length of 16. It is a functional, DDR5-inspired controller, not a JEDEC-compliant DDR5 PHY.

## 2. Target Device

| Item | Value |
|---|---|
| Device | **xc7vx485tffg1930-2** (Virtex-7 VX485T) |
| Package / speed grade | FFG1930 / -2 |
| Tool | Vivado v2026.1 (win64), Build 6511674 |
| Top module | `DDR5` (simulation top: `DDR5_tb`) |
| Device resources | 303,600 LUTs · 607,200 flip-flops · 1,030 RAMB36 · 2,800 DSP · 700 bonded IOB |

## 3. Architecture

### 3.1 Data path and control flow

1. The CPU asserts `CPU_VALID` with `CPU_ADDR`, `CPU_WE` and, for writes, `CPU_WRT_DATA`.
2. In `IDLE`, the controller captures the write word into the write buffer and checks whether the target bank and row are already open.
3. If a different row is open, it goes through `PRECHARGE`, then `ACTIVATE`. If the bank is closed, it goes straight to `ACTIVATE`. If the row is already open (a row hit), it goes straight to `READ` or `WRITE`.
4. `READ` samples the DQ bus into a 16-entry read buffer. `WRITE` drives 16 words onto DQ through a tri-state buffer.
5. A refresh timer raises a refresh request every `tREFI` clocks. `IDLE` gives refresh priority over CPU requests.

### 3.2 Address mapping

| `CPU_ADDR` bits | Use |
|---|---|
| [13:0] | Row / column address (`DDR5_ADDR`) |
| [17:14] | Bank address (`DDR5_BA`) |
| [19:18] | Unused (removed by synthesis) |

### 3.3 FSM states

| State | Code | Action |
|---|---|---|
| `IDLE` | 4'b0000 | Asserts `CPU_READY`, clears burst counter, latches first write word, decides next state |
| `PRECHARGE` | 4'b0001 | Issues precharge (A10 high), waits `tRP`, marks bank closed |
| `ACTIVATE` | 4'b0010 | Issues activate with bank/row, waits `tRCD`, records active bank and row |
| `READ` | 4'b0011 | Issues read command, captures 16 beats into the read buffer |
| `WRITE` | 4'b0100 | Issues write command, drives 16 beats on DQ |
| `REFRESH` | 4'b0101 | Issues refresh, waits `tRFC`, clears refresh request |
| `MODE_REG_SET` | 4'b0110 | Encoding defined; no transition reaches it in the current RTL |

## 4. Subcomponents

The design contains **6 functional sub-blocks** inside the single `DDR5` module (3 `always` blocks and 1 continuous assignment):

| # | Sub-block | Implemented by | Function |
|---|---|---|---|
| 1 | DDR clock generator | `always @(posedge clk or negedge rst)` | Toggles `DDR5_CLK_P` / `DDR5_CLK_N` as complementary clocks |
| 2 | Sequential control and command generator | main `always` block | State register, refresh timer, timing counter, reset release, command strobes, bank/row tracking |
| 3 | Next-state logic | `always @(*)` | Combinational FSM transitions (row-hit / row-miss decision) |
| 4 | Tri-state DQ driver | `assign DDR5_DQ = dq_en ? dq_out_reg : 'bz` | Shares the 64-bit DQ bus between read and write |
| 5 | Write buffer | `WRT_BUFF[0:15]` | 16 × 64-bit write burst storage |
| 6 | Read buffer | `RD_BUFF[0:15]` | 16 × 64-bit read burst storage |

The RTL statistics reported by Vivado list 19 × 64-bit registers, 1 × 16-bit, 2 × 14-bit, 1 × 8-bit, 3 × 4-bit and 11 × 1-bit registers, plus three adders (counters).

For verification, the project also has a testbench (`DDR5_tb`) that instantiates the controller and an external DRAM behavioural model (`DDR5_Module`).

## 5. Parameters

| Parameter | Value | Meaning |
|---|---|---|
| `data_width` | 64 | Data bus width |
| `add_width` | 20 | CPU address width |
| `reg_bank_width` | 4 | Bank address width |
| `burst_length` | 16 | Beats per burst |
| `tclk` | 625 | Declared clock period constant (not referenced in logic) |
| `tRP` | 4 | Precharge wait (cycles) |
| `tRCD` | 4 | Activate-to-read/write wait (cycles) |
| `tRAS` | 10 | Declared row-active time (not referenced in logic) |
| `tREFI` | 1950 | Refresh interval (cycles) |
| `tRFC` | 128 | Refresh cycle time (cycles) |
| `IDLE … MODE_REG_SET` | 4'b0000 … 4'b0110 | FSM state encodings |

## 6. Variables (internal signals)

| Name | Width | Purpose |
|---|---|---|
| `curr_state`, `nxt_state` | 4 | Current and next FSM state |
| `refresh_cnt` | 16 | Counts clocks toward `tREFI` |
| `refresh_rq` | 1 | Refresh request flag |
| `timing_cnt` | 8 | Down-counter for `tRP`, `tRCD`, `tRFC` and read latency |
| `burst_cnt` | 4 | Beat index within a burst |
| `active_bank` | 4 | Currently open bank |
| `active_row` | 14 | Currently open row |
| `bank_active` | 1 | Row-open flag |
| `dq_out_reg` | 64 | Write data driven onto DQ |
| `dq_en` | 1 | DQ output-enable (tri-state control) |
| `WRT_BUFF` | 16 × 64 | Write burst buffer |
| `RD_BUFF` | 16 × 64 | Read burst buffer |

## 7. User I/O

| Group | Signals | Direction | Bits declared |
|---|---|---|---|
| System | `clk`, `rst` | In | 2 |
| CPU request | `CPU_ADDR[19:0]`, `CPU_WRT_DATA[63:0]`, `CPU_VALID`, `CPU_WE` | In | 86 |
| CPU response | `CPU_RD_DATA[63:0]`, `CPU_READY` | Out | 65 |
| DDR control | `DDR5_CLK_P/N`, `DDR5_RST_N`, `DDR5_CS_N`, `DDR5_RAS_N`, `DDR5_CAS_N`, `DDR5_WE_N` | Out | 7 |
| DDR address | `DDR5_BA[3:0]`, `DDR5_ADDR[13:0]` | Out | 18 |
| DDR data | `DDR5_DQ[63:0]` | Inout | 64 |
| DDR strobes / mask | `DDR5_DQS_P[7:0]`, `DDR5_DQS_N[7:0]`, `DDR5_DM[7:0]` | Inout | 24 |

**Totals:** 266 port bits declared. After synthesis, the 24 unused strobe/mask bits and the 2 unused address bits `CPU_ADDR[19:18]` are removed. **240 bonded user I/Os** are used (86 inputs, 90 outputs, 64 bidirectional), which is 34.29% of the 700 available.

## 8. Synthesis Results (Vivado 2026.1)

| Resource | Used | Available | Util % |
|---|---|---|---|
| Slice LUTs (all logic) | 357 | 303,600 | 0.12 |
| Slice registers (flip-flops) | 1,292 | 607,200 | 0.21 |
| F7 muxes | 128 | 151,800 | 0.08 |
| F8 muxes | 64 | 75,900 | 0.08 |
| Block RAM | 0 | 1,030 | 0.00 |
| DSP | 0 | 2,800 | 0.00 |
| Bonded IOB | 240 | 700 | 34.29 |
| BUFGCTRL | 1 | 32 | 3.13 |
| Unique control sets | 26 | 75,900 | 0.03 |

Primitive breakdown: LUT6 286, LUT5 33, LUT4 28, LUT2 11, LUT3 9, LUT1 3, CARRY4 2, FDRE 1,239, FDCE 34, FDSE 13, FDPE 6, IBUF 86, OBUF 90, IOBUF 64 (mapped to IBUF + OBUFT), BUFG 1.

The flip-flop count is dominated by the 16 × 64-bit read buffer (1,024 FFs), because Vivado could not infer block RAM for it and built it from registers. Synthesis finished with 0 errors. The synthesis stage reported 27 warnings and 0 critical warnings; across the whole run, Vivado reported 229 warnings and 2 critical warnings.

**Figure (synthesized schematic).** Vivado's schematic of the synthesized design shows the control logic (counters, comparators, state decoding) on the left and a tall column of repeated mux and register slices on the right, consistent with the 16 × 64-bit read/write buffers and the DQ output stage.

![Synthesized schematic of the DDR5 controller from Vivado](https://github.com/Aravindakshan953/DDR5-Module/blob/main/DDR5_Synthesized%20Design.png)

## 9. XDC Constraints (`DDR5_Constraints.xdc`)

### 9.1 Clocks

```tcl
create_clock -period 3.333 -name CLK_P [get_ports clk] -waveform {0.000 1.666}
create_clock -period 1.25  -name DDR5_CLK_P [get_ports DDR5_CLK_P] -waveform {0.000 0.625}
set_clock_uncertainty -setup 0.050 [get_clocks CLK_P]
set_clock_uncertainty -hold  0.030 [get_clocks CLK_P]
set_clock_uncertainty -setup 0.080 [get_clocks DDR5_CLK_P]
set_clock_uncertainty -hold  0.050 [get_clocks DDR5_CLK_P]
set_clock_groups -asynchronous -group [get_clocks CLK_P] -group [get_clocks DDR5_CLK_P]
```

The system clock is constrained at about 300 MHz (3.333 ns) and the DDR clock at 800 MHz (1.25 ns). The two clocks are declared asynchronous.

### 9.2 Pin and I/O standard assignments

| Signals | Pins | I/O standard |
|---|---|---|
| `clk`, `rst`, `CPU_VALID`, `CPU_WE`, `CPU_READY` | K21, K22, C22, D22, E22 | LVCMOS33 |
| `CPU_ADDR`, `CPU_WRT_DATA`, `CPU_RD_DATA` | not yet assigned | LVCMOS18 |
| `DDR5_CLK_P` / `DDR5_CLK_N` | AN8 / AM8 | DIFF_SSTL15 |
| `DDR5_RST_N`, `DDR5_CAS_N`, `DDR5_RAS_N`, `DDR5_WE_N` | B7, AN7, AL7, AL8 | SSTL15 |
| `DDR5_ADDR[0..10, 12, 13]` | AN9, AP9, AL9, AL10, AM10, AN10, AP10, AM11, AN11, AP11, AL11, AM12, AN12 | SSTL15 |
| `DDR5_BA[3:0]` | AP12, AL13, AM13, AN13 | SSTL15 |
| `DDR5_DQ[63:0]` | AJ6 … R9 (one unique pin per bit) | SSTL15_T_DCI |
| `DDR5_CS_N`, `DDR5_ADDR[11]` | not yet assigned | SSTL15 |

Of the 240 used I/Os, **92 have pin assignments**; 148 are still unassigned (146 CPU-side bits plus `DDR5_CS_N` and `DDR5_ADDR[11]`). `INTERNAL_VREF` is set to 0.750 V on the DQ banks.

### 9.3 Timing exceptions and I/O timing

```tcl
# DQ: +/-0.300 ns, ADDR/BA: +/-0.400 ns, RAS/CAS/WE: +/-0.350 ns
# (input and output delays referenced to DDR5_CLK_P, rise and fall edges for DQ)
set_multicycle_path -setup 2 -through [get_pins -hier *refresh_cnt*]
set_multicycle_path -hold  1 -through [get_pins -hier *refresh_cnt*]
set_multicycle_path -setup 4 -from [get_pins -hier *curr_state*] -to [get_ports {DDR5_ADDR[*]}]
set_multicycle_path -hold  3 -from [get_pins -hier *curr_state*] -to [get_ports {DDR5_ADDR[*]}]
set_false_path -from [get_ports rst]
set_false_path -to   [get_ports DDR5_RST_N]
set_false_path -from [get_ports CPU_*] -to [get_clocks DDR5_CLK_P]
set_false_path -from [get_clocks DDR5_CLK_P] -to [get_ports CPU_*]
set_property SLEW FAST [get_ports {DDR5_ADDR[*] DDR5_BA[*] DDR5_DQ[*] DDR5_RAS_N DDR5_CAS_N DDR5_WE_N}]
```

### 9.4 Configuration

```tcl
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
```

## 10. Timing Summary

All user-specified timing constraints are met: worst setup slack is +0.170 ns, worst hold slack is +0.097 ns and worst pulse-width slack is +1.267 ns, with no failing endpoints.

| Check | Worst slack | Total negative slack | Failing endpoints | Total endpoints |
|---|---|---|---|---|
| Setup (WNS / TNS) | 0.170 ns | 0.000 ns | 0 | 1,514 |
| Hold (WHS / THS) | 0.097 ns | 0.000 ns | 0 | 1,514 |
| Pulse width (WPWS / TPWS) | 1.267 ns | 0.000 ns | 0 | 1,293 |

Source: Vivado Design Timing Summary, evaluated against the clocks and I/O delays listed in section 9.

![Vivado Design Timing Summary: WNS 0.170 ns, WHS 0.097 ns, WPWS 1.267 ns, all constraints met](https://github.com/Aravindakshan953/DDR5-Module/blob/main/DDR5_Timing%20constraint.png)

## 11. Power Summary

Total on-chip power is 1.23 W (typical process), and 97% of the dynamic power is spent in the I/O.

| Metric | Value |
|---|---|
| Total on-chip power | 1.23 W |
| Dynamic power | 0.981 W (80%) |
| Dynamic: clocks | 0.009 W (1%) |
| Dynamic: signals | 0.007 W (1%) |
| Dynamic: logic | 0.001 W (under 1%) |
| Dynamic: I/O | 0.964 W (97%) |
| Device static power | 0.249 W (20%) |
| Junction temperature | 26.1 °C |
| Thermal margin | 58.9 °C (66.8 W) |
| Ambient temperature | 25.0 °C |
| Effective θJA | 0.9 °C/W |
| Design power budget | Not specified |
| Power supplied to off-chip devices | 0 W |

Source: Vivado power analysis of the implemented netlist. Percentages under dynamic power are shares of the 0.981 W dynamic total.

![Vivado power summary: 1.23 W total, 0.981 W dynamic, 0.249 W static, junction temperature 26.1 C](https://github.com/Aravindakshan953/DDR5-Module/blob/main/DDR5_Report_Power.png)

## 12. Verification

The testbench drives a 100 MHz clock and runs six test groups: basic DC patterns, alternating bank/row access, burst sequential patterns, walking-bit patterns, refresh behaviour and random access (20 random address/data pairs). Each mismatch or handshake timeout is counted as an error, and the testbench prints a pass/fail line per test.

The saved log and the waveform screenshot agree. The stimulus is applied (addresses 00000, 00008, 00010, then the bank/row sweep 00000, 10000, 20000, 00100 … with data patterns such as all-zeros, all-ones, aaaa…, beefcafe…, feedbeef… and deadbeef…), but the 64-bit read-data bus stays at `x` for the whole captured 0–60 µs window. The log ends at the 500 µs limit with write/read timeouts and 140 error lines, so the read path is not yet verified.

![Simulation waveform, 0 to 60 microseconds, read-data bus at x](images/ddr5_waveform.png)
