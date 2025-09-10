`timescale 1ns / 1ps

module DDR5_tb;

    parameter data_width = 64;
    parameter addr_width = 20;
    parameter reg_bank_width = 4;
    parameter burst_length = 16;

    // Clock and reset
    reg clk;
    reg rst;
    
    // CPU interface signals
    reg [addr_width-1:0] CPU_ADDR;
    reg [data_width-1:0] CPU_WRT_DATA;
    wire [data_width-1:0] CPU_RD_DATA;
    reg CPU_VALID;
    reg CPU_WE;
    wire CPU_READY;

    // DDR5 interface signals
    // Corrected the bit widths to match the controller
    wire DDR5_CLK_P, DDR5_CLK_N;
    wire DDR5_RST_N, DDR5_CS_N;
    wire DDR5_RAS_N, DDR5_CAS_N, DDR5_WE_N;
    wire [reg_bank_width-1:0] DDR5_BA;
    wire [13:0] DDR5_ADDR;
    wire [data_width-1:0] DDR5_DQ;
    wire [7:0] DDR5_DQS_P, DDR5_DQS_N;
    wire [7:0] DDR5_DM;

    integer i;
    integer read_count = 0, write_count = 0;

    // Instantiate the DDR5 controller
    // This instantiation is now correct.
    DDR5 uut (
        .clk(clk),
        .rst(rst),
        .CPU_ADDR(CPU_ADDR),
        .CPU_WRT_DATA(CPU_WRT_DATA),
        .CPU_RD_DATA(CPU_RD_DATA),
        .CPU_VALID(CPU_VALID),
        .CPU_WE(CPU_WE),
        .CPU_READY(CPU_READY),
        .DDR5_CLK_P(DDR5_CLK_P),
        .DDR5_CLK_N(DDR5_CLK_N),
        .DDR5_RST_N(DDR5_RST_N),
        .DDR5_CS_N(DDR5_CS_N),
        .DDR5_RAS_N(DDR5_RAS_N),
        .DDR5_CAS_N(DDR5_CAS_N),
        .DDR5_WE_N(DDR5_WE_N),
        .DDR5_BA(DDR5_BA),
        .DDR5_ADDR(DDR5_ADDR),
        .DDR5_DQ(DDR5_DQ),
        .DDR5_DQS_P(DDR5_DQS_P),
        .DDR5_DQS_N(DDR5_DQS_N),
        .DDR5_DM(DDR5_DM)
    );

    // Simplified DDR5 memory model
    // Corrected the port connections to remove the 'unconnected port' warning
    DDR5_Module sim_mem (
        .clk_P(DDR5_CLK_P),
        .clk_N(DDR5_CLK_N),
        .CS_N(DDR5_CS_N),
        .RAS_N(DDR5_RAS_N),
        .CAS_N(DDR5_CAS_N),
        .WE_N(DDR5_WE_N),
        .BA(DDR5_BA),
        .ADDR(DDR5_ADDR),
        .DQ(DDR5_DQ)
    );
    
    // Clock generation - 20ns period (50MHz for faster sim)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("DDR5.vcd");
        $dumpvars(0, DDR5_tb);
    end
    
    // Main test sequence - optimized for speed
    initial begin
        $display("=== DDR5 CONTROLLER TESTBENCH - FAST VERSION ===");
        
        // Initialize
        rst = 0;
        CPU_VALID = 0;
        CPU_WE = 0;
        CPU_ADDR = 0;
        CPU_WRT_DATA = 0;
        
        // Quick reset
        #40 rst = 1;
        $display("Reset released at %0t", $time);
        
        // Wait for controller initialization (reduced)
        #2500;
        $display("Initialization done at %0t", $time);
        
        // Test 1: Basic Write
        $display("\n=== Test 1: Basic Write ===");
        write_data_fast(20'h01000, 64'hDEADBEEFCAFEBABE);
        
        // Test 2: Basic Read
        $display("=== Test 2: Basic Read ===");
        read_data_fast(20'h01000);
        
        // Test 3: Bank Switch Test
        $display("=== Test 3: Bank Switch ===");
        write_data_fast(20'h11000, 64'hAAAABBBBCCCCDDDD);
        read_data_fast(20'h11000);
        
        // Test 4: Back to original bank
        $display("=== Test 4: Return to Bank 0 ===");
        read_data_fast(20'h01000);
        
        // Test 5: Multiple operations
        $display("=== Test 5: Sequential Operations ===");
        for (i = 0; i < 3; i = i+1) begin
            write_data_fast(20'h02000 + (i*16), 64'h1000000000000000 + i);
        end
        
        for (i = 0; i < 3; i = i+1) begin
            read_data_fast(20'h02000 + (i*16));
        end
        
        // Test 6: Reduced refresh test
        $display("=== Test 6: Short Refresh Test ===");
        #4000;  // Reduced wait time
        
        $display("=== RESULTS ===");
        $display("Total Writes: %0d", write_count);
        $display("Total Reads: %0d", read_count);
        $display("Simulation time: %0t", $time);
        $display("=== TEST COMPLETE ===");
        
        #200;  // Short final wait
        $finish;
    end
    
    // Fast write task - minimal delays
    task write_data_fast;
        input [addr_width-1:0] addr;
        input [data_width-1:0] data;
        reg [15:0] timeout_count;
        begin
            timeout_count = 0;
            $display("  Write: Addr=0x%05h, Data=0x%016h", addr, data);
            
            @(posedge clk);
            CPU_ADDR = addr;
            CPU_WRT_DATA = data;
            CPU_WE = 1;
            CPU_VALID = 1;
            
            // Fast timeout-protected wait
            while (!CPU_READY && timeout_count < 1000) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            
            if (timeout_count >= 1000) begin
                $display("  ERROR: Write timeout!");
            end else begin
                write_count = write_count + 1;
            end
            
            @(posedge clk);
            CPU_VALID = 0;
            CPU_WE = 0;
        end
    endtask
    
    // Fast read task - minimal delays
    task read_data_fast;
        input [addr_width-1:0] addr;
        reg [15:0] timeout_count;
        begin
            timeout_count = 0;
            $display("  Read:  Addr=0x%05h", addr);
            
            @(posedge clk);
            CPU_ADDR = addr;
            CPU_WE = 0;
            CPU_VALID = 1;
            
            // Fast timeout-protected wait
            while (!CPU_READY && timeout_count < 1000) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            
            if (timeout_count >= 1000) begin
                $display("  ERROR: Read timeout!");
            end else begin
                $display("  Data:  0x%016h", CPU_RD_DATA);
                read_count = read_count + 1;
            end
            
            @(posedge clk);
            CPU_VALID = 0;
        end
    endtask
    
    // Simplified command monitor (less verbose)
    always @(posedge clk) begin
        if (!DDR5_CS_N && DDR5_RST_N) begin
            case ({DDR5_RAS_N, DDR5_CAS_N, DDR5_WE_N})
                3'b011: $display("CMD: ACTIVATE Bank=%0d", DDR5_BA);
                3'b101: $display("CMD: READ");
                3'b100: $display("CMD: WRITE");
                3'b010: $display("CMD: PRECHARGE");
                3'b001: $display("CMD: REFRESH");
            endcase
        end
    end
    
    // Simple timeout protection
    initial begin
        #20000;  // 20us timeout
        $display("TIMEOUT: Simulation exceeded time limit");
        $display("Final state: Ready=%b, Valid=%b", CPU_READY, CPU_VALID);
        $finish;
    end
    
endmodule
