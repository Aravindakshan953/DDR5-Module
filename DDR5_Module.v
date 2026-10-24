`timescale 1ns / 1ps

module DDR5_Module (
    input  wire        clk_P,
    input  wire        clk_N,
    input  wire        CS_N,
    input  wire        RAS_N,
    input  wire        CAS_N,
    input  wire        WE_N,
    input  wire [3:0]  BA,
    input  wire [13:0] ADDR,
    inout  wire [63:0] DQ,
    inout  wire [7:0]  DM,
    inout  wire [7:0]  DQS_P,
    inout  wire [7:0]  DQS_N
);
    reg [63:0] memory [0:1048575];
    reg [63:0] data_out;
    reg        output_enable;
    reg [1:0]  read_delay;
    reg [19:0] rd_index;
    reg [13:0] row_addr [0:15];
    integer i;
    initial begin
        for (i = 0; i < 1048576; i = i + 1) memory[i] = 64'h0;
        for (i = 0; i < 16;    i = i + 1) row_addr[i] = 14'h0;
        output_enable = 1'b0;
        data_out      = 64'h0;
        read_delay    = 2'd0;
        rd_index      = 20'h0;
    end
    wire [19:0] cmd_index = {2'b00, BA, row_addr[BA]};
    always @(posedge clk_P) begin
        output_enable <= 1'b0;
        if (read_delay != 2'd0) read_delay <= read_delay - 2'd1;
        if (read_delay == 2'd1) begin
            data_out      <= memory[rd_index];
            output_enable <= 1'b1;
        end
        if (!CS_N) begin
            if (!RAS_N && CAS_N && WE_N) begin
                row_addr[BA] <= ADDR;
            end else if (RAS_N && !CAS_N && WE_N) begin
                rd_index   <= cmd_index;
                read_delay <= 2'd2;
            end else if (RAS_N && !CAS_N && !WE_N) begin
                if (^DQ !== 1'bx)
                    memory[cmd_index] <= DQ;
            end
        end
    end
    assign DQ = output_enable ? data_out : 64'hzzzzzzzzzzzzzzzz;
endmodule
