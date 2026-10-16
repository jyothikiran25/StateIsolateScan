# State-Isolated Scan (SIS) on ISCAS89 s27

Implementation and evaluation of **State-Isolated Scan**, a secure, low-power scan architecture proposed in
C. P. Ravikumar and Kushal C., *"State-Isolated Scan - A Secure Low-Power Scan Architecture"*, IEEE, 2026.

The design was taken from RTL through simulation, synthesis and layout in Cadence
(NCLaunch / SimVision, Genus, Innovus) on the 90 nm `gsclib090` standard-cell library, and compared
against conventional scan on the same circuit.

## The idea

In conventional scan, the state flip-flops are also the shift chain. Every shift clock changes the inputs of
the logic, which wastes power, and the scan pins can read or overwrite the internal state directly.

SIS gives each state flip-flop three helper cells:

| Cell | Job |
| --- | --- |
| **ISR-a** | Separate shift chain that receives the test pattern bit by bit |
| **ISR-b** | Holds the pattern steady; takes the new one only when it is complete |
| **MUXDFF** | The real state flip-flop; loads from ISR-b or captures the logic output |
| **OSR** | Copies the state and shifts the response out on its own chain |

During shift only ISR-a and OSR move, so the state and the logic stay frozen, and the scan-out pin never
connects to the real state.

Test sequence (N + 4 cycles per test): shift into ISR-a → transfer to ISR-b → load the state →
capture the logic response → copy to OSR and shift out (overlapped with the next shift-in).

## Results

| Check | Tool | Result |
| --- | --- | --- |
| Stuck-at test, 6 patterns, both designs | NCLaunch | 12/12 PASS, identical responses |
| Logic-node toggles during shift | NCLaunch | **59** (conventional) vs **0** (SIS) |
| Test time, 6 tests | NCLaunch | 27 vs 45 cycles, matching N+(N+1)t vs N+(N+4)t |
| At-speed LOS and LOC, 5 ns slow-to-rise defect on G11 | NCLaunch | Detected with 2 ns capture, missed with 20 ns |
| Security lifecycle modes (MFG / DEBUG / SECURE) | NCLaunch | Scan read and write blocked outside MFG |
| Cell area | Genus, slow.lib | 90.07 µm² (conventional) vs 283.08 µm² (SIS), 3.1× |
| Area overhead on logic area | Genus | 671% measured vs 600% from the paper's formula 20 × nff/ng |
| Timing at 10 ns clock | Genus | Met; worst path about 0.6 ns |
| Layout of s27_sis | Innovus | 33.06 × 31.32 µm block, 0 DRC violations, 0 connectivity errors |

s27 has only 3 flip-flops for 10 gates, so its area overhead is high; the paper estimates 3.6–30% for real
SoCs, and recommends hybrid SIS (only on security-critical flops) to reduce it further.

## Repository layout

| Folder | Contents |
| --- | --- |
| `SIM/` | RTL and testbenches, run in NCLaunch |
| `SYN/` | Genus synthesis files and logs |
| `PD/` | Innovus layout: netlist, SDC, MMMC setup, saved designs |

Key files in `SIM/`:

| File | What it is |
| --- | --- |
| `sis_cells.v` | ISR, MUXDFF and OSR cells (Fig. 2 of the paper), plus a conventional scan flop |
| `s27_sis.v` | s27 with State-Isolated Scan |
| `s27_conv_scan.v` | s27 with conventional scan (baseline) |
| `tb_s27.v` | Stuck-at test of both designs, with toggle counting during shift |
| `tb_atspeed.v` | LOS and LOC at-speed tests, with a slow-to-rise defect injected on G11 |
| `tb_secure.v` | Lifecycle-mode wrapper and attacker read/write tests |

## How to run

**Simulation** (in `SIM/`): start `nclaunch`, choose Multiple Step, compile `sis_cells.v`, `s27_sis.v`,
`s27_conv_scan.v` and a testbench, elaborate its top module (`tb_s27`, `tb_atspeed` or `tb_secure`) with
Access Visibility set to All, then simulate and run.

**Synthesis** (in `SYN/`, Genus):

```
set_db init_lib_search_path /home/install/FOUNDRY/digital/90nm/dig/lib
set_db library slow.lib
read_hdl {sis_cells.v s27_sis.v}
elaborate s27_sis
create_clock -name clk -period 10 [get_ports clk]
syn_generic
syn_map
syn_opt
report_area
write_hdl > ../PD/s27_sis_netlist.v
write_sdc > ../PD/s27_sis.sdc
```

**Layout** (in `PD/`, Innovus): import with `gsclib090_translated_ref.lef`, the netlist and `mmmc.tcl`;
then floorplan, power ring and rails, pin placement, `placeDesign`, `ccopt_design`, `routeDesign`,
`verifyConnectivity`, `verify_drc` and `timeDesign -postRoute`.

## Author

Jyothikiran ([@jyothikiran25](https://github.com/jyothikiran25)), ECE.
