`timescale 1ns / 1ps

module axi_stream_skid_buffer_tb;

    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz clock

    // Testbench Signals
    reg                    clk;
    reg                    rst_n;

    // Slave Interface (Inputs to DUT)
    reg [DATA_WIDTH-1:0]   s_axis_tdata;
    reg                    s_axis_tvalid;
    wire                   s_axis_tready;

    // Master Interface (Outputs from DUT)
    wire [DATA_WIDTH-1:0]  m_axis_tdata;
    wire                   m_axis_tvalid;
    reg                    m_axis_tready;

    // Instantiate the Device Under Test (DUT)
    axi_stream_skid_buffer #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // variables for test control
    integer i;

    initial begin
        // Initialize Signals
        clk = 0;
        rst_n = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 0;

        // Reset Sequence
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);
        
        $display("--- Starting AXI-Stream Skid Buffer Testbench ---");

        //----------------------------------------------------------------------
        // TESTCASE 1: Normal Streaming (No Backpressure)
        //----------------------------------------------------------------------
        $display("TC1: Starting normal back-to-back streaming...");
        m_axis_tready = 1; // Downstream is ready
        
        for (i = 1; i <= 5; i = i + 1) begin
            @(posedge clk);
            s_axis_tvalid = 1;
            s_axis_tdata = i; // Sending 1, 2, 3, 4, 5
        end
        
        // Clear input after sending 5 words
        @(posedge clk);
        s_axis_tvalid = 0;
        s_axis_tdata = 0;
        #(CLK_PERIOD * 2);

        //----------------------------------------------------------------------
        // TESTCASE 2: Downstream Stall (Backpressure Injection)
        //----------------------------------------------------------------------
        $display("TC2: Injecting downstream stall while upstream is transmitting...");
        
        // Start transmitting Data 100
        @(posedge clk);
        s_axis_tvalid = 1;
        s_axis_tdata = 32'h100;
        
        // Transmit Data 200, but downstream suddenly stalls on this cycle
        @(posedge clk);
        s_axis_tdata = 32'h200;
        m_axis_tready = 0; // STALL!
        $display("[STALL] Downstream dropped READY. Data 0x100 should hold at output.");

        // Transmit Data 300. Since s_axis_tready was still 1, this transaction is committed
        // and MUST "skid" into the buffer.
        @(posedge clk);
        s_axis_tdata = 32'h300; 
        
        // Hold state to observe frozen outputs and low s_axis_tready
        #(CLK_PERIOD * 2);
        
        // Clear upstream valid because input is now halted by s_axis_tready going low
        s_axis_tvalid = 0;

        //----------------------------------------------------------------------
        // TESTCASE 3: Clearing the Stall
        //----------------------------------------------------------------------
        $display("TC3: Clearing downstream stall. Observing skid buffer unloading...");
        @(posedge clk);
        m_axis_tready = 1; // Downstream recovers
        
        // Let it run to drain the registers
        #(CLK_PERIOD * 4);

        $display("--- Testbench Completed Successfully ---");
        $finish;
    end

    // Monitor Output Transactions
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            $display("[MASTER HANDSHAKE] Transferred Data: 0x%h at time %0t", m_axis_tdata, $time);
        end
        if (s_axis_tvalid && s_axis_tready) begin
            $display("[SLAVE HANDSHAKE] Accepted Data: 0x%h at time %0t", s_axis_tdata, $time);
        end
    end

endmodule
