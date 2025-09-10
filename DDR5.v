`timescale 1ns / 1ps

module DDR5
#(
    parameter data_width = 64,
    parameter add_width = 20,
    parameter reg_bank_width = 4,
    parameter burst_length = 16,
    parameter tclk = 625,
    parameter tRP = 4,
    parameter tRCD = 4,
    parameter tRAS = 10,
    parameter tREFI = 1950,
    parameter tRFC = 128,
    // State Machine Parameters
    parameter IDLE = 4'b0000,
    parameter PRECHARGE = 4'b0001,
    parameter ACTIVATE = 4'b0010,
    parameter READ = 4'b0011,
    parameter WRITE = 4'b0100,
    parameter REFRESH = 4'b0101,
    parameter MODE_REG_SET = 4'b0110
)
(
    input wire clk,
    input wire rst,
    input wire [add_width-1:0] CPU_ADDR,
    input wire [data_width-1:0] CPU_WRT_DATA,
    output reg [data_width-1:0] CPU_RD_DATA,
    input wire CPU_VALID,
    input wire CPU_WE,
    output reg CPU_READY,
    output reg DDR5_CLK_P,
    output reg DDR5_CLK_N,
    output reg DDR5_RST_N,
    output reg DDR5_CS_N,
    output reg DDR5_RAS_N,
    output reg DDR5_CAS_N,
    output reg DDR5_WE_N,
    output reg [reg_bank_width-1:0] DDR5_BA,
    output reg [13:0] DDR5_ADDR,
    inout wire [data_width-1:0] DDR5_DQ,
    inout wire [7:0] DDR5_DQS_P,
    inout wire [7:0] DDR5_DQS_N,
    inout wire [7:0] DDR5_DM
);

// Internal registers for output and tri-state control
reg [data_width-1:0] dq_out_reg;
reg dq_en;

// Tri-state buffer assignment for DQ bus
assign DDR5_DQ = dq_en ? dq_out_reg : 'bz;

// State machine registers
reg [3:0] curr_state, nxt_state;

// Timing and control registers
reg [15:0] refresh_cnt;
reg [7:0] timing_cnt;
reg [3:0] burst_cnt;
reg refresh_rq;
reg [reg_bank_width-1:0] active_bank;
reg [13:0] active_row;
reg bank_active;

// Data buffers for reads and writes
reg [data_width-1:0] WRT_BUFF [0:burst_length-1];
reg [data_width-1:0] RD_BUFF [0:burst_length-1];

// This logic block generates the DDR5 clocks
always @ (posedge clk or negedge rst) begin
    if (!rst) begin
        DDR5_CLK_P <= 1'b0;
        DDR5_CLK_N <= 1'b1;
    end else begin
        DDR5_CLK_P <= ~DDR5_CLK_P;
        DDR5_CLK_N <= ~DDR5_CLK_N;
    end
end

// All synchronous logic for state machine and control signals in a single block
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        curr_state <= IDLE;
        refresh_cnt <= 0;
        timing_cnt <= 0;
        burst_cnt <= 0;
        CPU_READY <= 1'b0;
        refresh_rq <= 1'b0;
        bank_active <= 1'b0;
        DDR5_RST_N <= 1'b0;
        dq_en <= 1'b0;
        DDR5_CS_N <= 1'b1;
        DDR5_RAS_N <= 1'b1;
        DDR5_CAS_N <= 1'b1;
        DDR5_WE_N <= 1'b1;
    end else begin
        curr_state <= nxt_state;
        
        // Refresh timer logic
        if (refresh_cnt >= tREFI) begin
            refresh_cnt <= 0;
            refresh_rq <= 1'b1;
        end else begin
            refresh_cnt <= refresh_cnt + 1;
        end
        
        // General purpose timing counter
        if(timing_cnt > 0)
            timing_cnt <= timing_cnt - 1;
        
        // Release reset after a delay
        if (timing_cnt < 100)
            DDR5_RST_N <= 1'b1;
            
        // Default assignments to be overwritten in the case statement
        DDR5_CS_N <= 1'b1;
        DDR5_RAS_N <= 1'b1;
        DDR5_CAS_N <= 1'b1;
        DDR5_WE_N <= 1'b1;
        CPU_READY <= 1'b0;
        dq_en <= 1'b0;

        case(curr_state)
            IDLE: begin
                CPU_READY <= 1'b1;
                burst_cnt <= 0; // Reset burst counter in IDLE state
                if (CPU_VALID && CPU_WE) begin
                    WRT_BUFF[0] <= CPU_WRT_DATA; // Load first word of burst
                end
            end

            PRECHARGE: begin
                if(timing_cnt == 0) begin
                    DDR5_CS_N <= 1'b0;
                    DDR5_RAS_N <= 1'b0;
                    DDR5_CAS_N <= 1'b1;
                    DDR5_WE_N <= 1'b0;
                    DDR5_ADDR[10] <= 1'b1;
                    timing_cnt <= tRP;
                    bank_active <= 1'b0;
                end
            end

            ACTIVATE: begin
                if (timing_cnt == 0) begin
                    DDR5_CS_N <= 1'b0;
                    DDR5_RAS_N <= 1'b0;
                    DDR5_CAS_N <= 1'b1;
                    DDR5_WE_N <= 1'b1;
                    DDR5_BA <= CPU_ADDR[reg_bank_width+13:14];
                    DDR5_ADDR <= CPU_ADDR[13:0];
                    active_bank <= CPU_ADDR[reg_bank_width+13:14];
                    active_row <= CPU_ADDR[13:0];
                    timing_cnt <= tRCD;
                    bank_active <= 1'b1;
                end
            end

            READ: begin
                if (timing_cnt == 0) begin
                    DDR5_CS_N <= 1'b0;
                    DDR5_RAS_N <= 1'b1;
                    DDR5_CAS_N <= 1'b0;
                    DDR5_WE_N <= 1'b1;
                    DDR5_ADDR <= CPU_ADDR[13:0];
                    DDR5_BA <= CPU_ADDR[reg_bank_width+13:14];
                    timing_cnt <= 4;
                end else if (timing_cnt == 1) begin
                    // Capture data from DQ bus on last cycle of latency
                    RD_BUFF[burst_cnt] <= DDR5_DQ;
                    burst_cnt <= burst_cnt + 1;
                end

                if (burst_cnt >= burst_length-1) begin
                    CPU_RD_DATA <= RD_BUFF[burst_cnt];
                    CPU_READY <= 1'b1;
                end
            end

            WRITE: begin
                if (timing_cnt == 0 && burst_cnt == 0) begin
                    DDR5_CS_N <= 1'b0;
                    DDR5_RAS_N <= 1'b1;
                    DDR5_CAS_N <= 1'b0;
                    DDR5_WE_N <= 1'b0;
                    DDR5_ADDR <= CPU_ADDR[13:0];
                    DDR5_BA <= CPU_ADDR[reg_bank_width+13:14];
                    
                    // Drive the first word of the burst
                    dq_out_reg <= WRT_BUFF[0];
                    dq_en <= 1'b1;
                    burst_cnt <= burst_cnt + 1;
                end else if (burst_cnt < burst_length) begin
                    // Drive the next data word in the burst
                    dq_out_reg <= WRT_BUFF[burst_cnt];
                    burst_cnt <= burst_cnt + 1;
                    dq_en <= 1'b1;
                end

                if (burst_cnt >= burst_length-1) begin
                    CPU_READY <= 1'b1;
                    dq_en <= 1'b0;
                end
            end

            REFRESH: begin
                if (timing_cnt == 0) begin
                    DDR5_CS_N <= 1'b0;
                    DDR5_RAS_N <= 1'b0;
                    DDR5_WE_N <= 1'b1;
                    timing_cnt <= tRFC;
                    refresh_rq <= 1'b0;
                    bank_active <= 1'b0;
                end
            end
        endcase
    end
end

// Combinational logic for state transitions
always@(*) begin
    nxt_state = curr_state;
    case(curr_state)
        IDLE: begin
            if (refresh_rq) begin
                nxt_state = REFRESH;
            end else if (CPU_VALID && timing_cnt == 0) begin
                if (!bank_active || (active_bank != CPU_ADDR[reg_bank_width+13:14]) || (active_row != CPU_ADDR[13:0])) begin
                    nxt_state = bank_active ? PRECHARGE : ACTIVATE;
                end else begin
                    nxt_state = CPU_WE ? WRITE : READ;
                end
            end
        end

        PRECHARGE: begin
            if(timing_cnt == 0)
                nxt_state = ACTIVATE;
        end

        ACTIVATE: begin
            if(timing_cnt == 0)
                nxt_state = CPU_WE ? WRITE : READ;
        end

        READ: begin
            if(burst_cnt >= burst_length-1)
                nxt_state = IDLE;
        end

        WRITE: begin
            if (burst_cnt >= burst_length-1)
                nxt_state = IDLE;
        end

        REFRESH: begin
            if(timing_cnt == 0)
                nxt_state = IDLE;
        end
    endcase
end
