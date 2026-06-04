# AXI-Stream Skid Buffer

A synthesizable, high-performance Verilog implementation of an AXI-Stream Skid Buffer. This module provides complete timing isolation (pipelining) for the `TDATA` and `TVALID` paths without sacrificing throughput or violating the AXI4-Stream handshake protocol during downstream backpressure.

## 1. The Core Problem: Why Do We Need a Skid Buffer?

In high-speed digital design (FPGA/ASIC), achieving a high maximum clock frequency ($F_{max}$) requires breaking long combinational paths by inserting registers. In the AXI-Stream protocol, a data transfer occurs (a "handshake") only on the clock edge when **both** `TVALID` and `TREADY` are high. 

* **The Pipeline Dilemma:** To isolate output timing, we must register `m_axis_tdata` and `m_axis_tvalid`. 
* **The Backpressure Dilemma:** If the downstream module suddenly drops `m_axis_tready` to `0`, our registered output cannot stop instantly; it already committed to sending data on that clock cycle. If we simply register `TREADY` back to the sender, it creates a 1-clock-cycle delay. During that single cycle, the upstream sender might send one last piece of valid data.

Without a skid buffer, you are forced to choose between a terrible trade-off:
1. **Lose Data:** Let the upstream data overwrite your register.
2. **Destroy Timing:** Allow `m_axis_tready` to combinationally loop back into `s_axis_tready`, creating a massive timing path that slows down your whole chip design.

### The Solution
The **Skid Buffer** acts like an elastic runway ramp. It provides a temporary, 1-deep backup register (`skid_data_reg`). If the downstream module stalls, the main register holds its ground, and any "in-flight" upstream data skids safely into the backup register until the stall clears.

---

## 2. Architecture & Hardware Block Diagram

The design utilizes two distinct register stages:
1. **Main Registers (`m_data_reg`, `m_valid_reg`):** These directly drive the output ports, ensuring perfect output timing isolation.
2. **Skid Registers (`skid_data_reg`, `skid_valid_reg`):** This behaves as the overflow tank.



### Ready Logic
```verilog
assign s_axis_tready = !skid_valid_reg;
## Verification & Simulation

A comprehensive testbench (`axi_stream_skid_buffer_tb.v`) is included to validate the protocol compliance and timing isolation of the design. 

The simulation tests three critical phases of data flow:
1. **Sustained Stream:** Validates maximum throughput (1 data word per cycle) when downstream is completely ready.
2. **Backpressure Injection:** Drops `m_axis_tready` while upstream is transmitting to verify that data safely "skids" into the backup storage without corruption.
3. **Stall Recovery:** Restores `m_axis_tready` to demonstrate the skid buffer unloading back onto the primary data path with zero dead cycles.

### Simulation Log Output
When executed, the testbench monitors the internal interfaces and outputs the following verification logs:

```text
--- Starting AXI-Stream Skid Buffer Testbench ---
TC1: Starting normal back-to-back streaming...
[SLAVE HANDSHAKE] Accepted Data: 0x00000001 at time 35000
[MASTER HANDSHAKE] Transferred Data: 0x00000001 at time 45000
[SLAVE HANDSHAKE] Accepted Data: 0x00000002 at time 45000
[MASTER HANDSHAKE] Transferred Data: 0x00000002 at time 55000

TC2: Injecting downstream stall while upstream is transmitting...
[SLAVE HANDSHAKE] Accepted Data: 0x00000100 at time 115000
[STALL] Downstream dropped READY. Data 0x100 should hold at output.
[SLAVE HANDSHAKE] Accepted Data: 0x00000200 at time 125000  <-- Data safely skids!

TC3: Clearing downstream stall. Observing skid buffer unloading...
[MASTER HANDSHAKE] Transferred Data: 0x00000100 at time 155000
[MASTER HANDSHAKE] Transferred Data: 0x00000200 at time 165000
--- Testbench Completed Successfully ---
