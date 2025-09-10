`timescale 1ns / 1ps

module DDR5_Module (
    input wire clk_P,
    input wire clk_N,
    input wire CS_N,
    input wire RAS_N,
    input wire CAS_N,
    input wire WE_N,
    input wire [3:0] BA,
    input wire [13:0] ADDR,
    inout wire [63:0] DQ
);

    // Minimal memory storage
    reg [63:0] memory [0:255];
    reg [63:0] data_out;
    reg output_enable;
    reg [1:0] read_delay;
    
    // Simple address registers
    reg [13:0] row_addr;
    reg [7:0] mem_addr;
    
    integer i;
    
    // Initialize
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 64'h0;
        end
        output_enable = 0;
        data_out = 64'h0;
        read_delay = 0;
    end
    
    // Simplified command processing
    always @(posedge clk_P) begin
        if (!CS_N) begin
            // ACTIVATE - store row address
            if (!RAS_N && CAS_N && WE_N) begin
                row_addr <= ADDR;
            end
            // READ
            else if (RAS_N && !CAS_N && WE_N) begin
                mem_addr <= {BA, ADDR[7:4]};
                read_delay <= 2'd2; // Reduced CAS latency
            end
            // WRITE
            else if (RAS_N && !CAS_N && !WE_N) begin
                mem_addr <= {BA, ADDR[7:4]};
                if (DQ !== 64'hzzzzzzzzzzzzzzzz) begin
                    memory[mem_addr] <= DQ;
                end
                output_enable <= 0;
            end
            // PRECHARGE/REFRESH - just clear output
            else begin
                output_enable <= 0;
            end
        end
    end
    
    // Handle read delay
    always @(posedge clk_P) begin
        if (read_delay > 0) begin
            read_delay <= read_delay - 1;
            if (read_delay == 1) begin
                data_out <= memory[mem_addr];
                output_enable <= 1;
            end
        end else if (read_delay == 0 && !(!CS_N && RAS_N && !CAS_N && WE_N)) begin
            output_enable <= 0;
        end
    end
    
    // Data output
    assign DQ = output_enable ? data_out : 64'hzzzzzzzzzzzzzzzz;

endmodule
