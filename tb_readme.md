
### Verification & Simulation

A comprehensive testbench (`axi_stream_skid_buffer_tb.v`) is included to validate the protocol compliance and timing isolation of the design. 

The simulation tests three critical phases of data flow:
1. **Sustained Stream:** Validates maximum throughput (1 data word per cycle) when downstream is completely ready.
2. **Backpressure Injection:** Drops `m_axis_tready` while upstream is transmitting to verify that data safely "skids" into the backup storage without corruption.
3. **Stall Recovery:** Restores `m_axis_tready` to demonstrate the skid buffer unloading back onto the primary data path with zero dead cycles.

## Simulation Log Output
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
