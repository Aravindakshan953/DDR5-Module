
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
    parameter tINIT = 200,   // clk cycles DDR5_RST_N is held low after reset
    parameter tRL = 5,       // clk cycles from READ command to DQ sample point
    // State Machine Parameters
    parameter IDLE = 4'b0000,
    parameter PRECHARGE = 4'b0001,
    parameter ACTIVATE = 4'b0010,
    parameter READ = 4'b0011,
    parameter WRITE = 4'b0100,
    parameter REFRESH = 4'b0101,
    parameter MODE_REG_SET = 4'b0110,
    parameter DONE = 4'b0111
)
(
    input wire clk,
    input wire rst,                       // active low
    input wire [add_width-1:0] CPU_ADDR,
    input wire [data_width-1:0] CPU_WRT_DATA,
    output reg [data_width-1:0] CPU_RD_DATA,
    input wire CPU_VALID,
    input wire CPU_WE,
    output reg CPU_READY,                 // one-cycle pulse when a request completes
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
 
// Tri-state buffer for the DQ bus
reg [data_width-1:0] dq_out_reg;
reg dq_en;
assign DDR5_DQ = dq_en ? dq_out_reg : {data_width{1'bz}};
 
// State machine and control registers
reg [3:0] curr_state, nxt_state;
reg [15:0] refresh_cnt;
reg [7:0] timing_cnt;
reg [3:0] burst_cnt;
reg refresh_rq;
reg [reg_bank_width-1:0] active_bank;
reg [13:0] active_row;
reg bank_active;
reg cmd_issued;                           // command of the current state already sent
 
// Write burst buffer
reg [data_width-1:0] WRT_BUFF [0:burst_length-1];
integer j;
 
// A command registered on a clk edge is sampled by the DRAM only if DDR5_CLK_P
// rises on that same edge, i.e. if DDR5_CLK_P is still low before the edge.
wire slot = ~DDR5_CLK_P;
 
wire row_hit = bank_active &&
               (active_bank == CPU_ADDR[reg_bank_width+13:14]) &&
               (active_row  == CPU_ADDR[13:0]);
 
// DDR5 clock generator
always @ (posedge clk or negedge rst) begin
    if (!rst) begin
        DDR5_CLK_P <= 1'b0;
        DDR5_CLK_N <= 1'b1;
    end else begin
        DDR5_CLK_P <= ~DDR5_CLK_P;
        DDR5_CLK_N <= ~DDR5_CLK_N;
    end
end
 
// Sequential control and command generation
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        curr_state  <= IDLE;
        refresh_cnt <= 0;
        refresh_rq  <= 1'b0;
        timing_cnt  <= tINIT;
        burst_cnt   <= 0;
        cmd_issued  <= 1'b0;
        CPU_READY   <= 1'b0;
        CPU_RD_DATA <= 0;
        bank_active <= 1'b0;
        active_bank <= 0;
        active_row  <= 0;
        DDR5_RST_N  <= 1'b0;
        DDR5_CS_N   <= 1'b1;
        DDR5_RAS_N  <= 1'b1;
        DDR5_CAS_N  <= 1'b1;
        DDR5_WE_N   <= 1'b1;
        DDR5_BA     <= 0;
        DDR5_ADDR   <= 0;
        dq_out_reg  <= 0;
        dq_en       <= 1'b0;
    end else begin
        curr_state <= nxt_state;
        if (nxt_state != curr_state) cmd_issued <= 1'b0;
 
        // Refresh interval timer
        if (refresh_cnt >= tREFI) begin
            refresh_cnt <= 0;
            refresh_rq  <= 1'b1;
        end else begin
            refresh_cnt <= refresh_cnt + 1;
        end
 
        // General purpose down-counter; DRAM reset released when it reaches 0
        if (timing_cnt > 0) timing_cnt <= timing_cnt - 1;
        if (timing_cnt == 0) DDR5_RST_N <= 1'b1;
 
        // Defaults (commands last exactly one clk cycle)
        DDR5_CS_N  <= 1'b1;
        DDR5_RAS_N <= 1'b1;
        DDR5_CAS_N <= 1'b1;
        DDR5_WE_N  <= 1'b1;
        CPU_READY  <= 1'b0;
        dq_en      <= 1'b0;
 
        case (curr_state)
            IDLE: begin
                burst_cnt <= 0;
                if (CPU_VALID && CPU_WE)
                    for (j = 0; j < burst_length; j = j + 1)
                        WRT_BUFF[j] <= CPU_WRT_DATA;   // word-wide CPU port fills the burst
            end
 
            PRECHARGE: begin
                if (!cmd_issued && slot) begin
                    DDR5_CS_N   <= 1'b0;
                    DDR5_RAS_N  <= 1'b0;
                    DDR5_CAS_N  <= 1'b1;
                    DDR5_WE_N   <= 1'b0;
                    DDR5_ADDR   <= 14'h0400;           // A10 = 1: precharge all banks
                    timing_cnt  <= tRP;
                    bank_active <= 1'b0;
                    cmd_issued  <= 1'b1;
                end
            end
 
            ACTIVATE: begin
                if (!cmd_issued && slot) begin
                    DDR5_CS_N   <= 1'b0;
                    DDR5_RAS_N  <= 1'b0;
                    DDR5_CAS_N  <= 1'b1;
                    DDR5_WE_N   <= 1'b1;
                    DDR5_BA     <= CPU_ADDR[reg_bank_width+13:14];
                    DDR5_ADDR   <= CPU_ADDR[13:0];
                    active_bank <= CPU_ADDR[reg_bank_width+13:14];
                    active_row  <= CPU_ADDR[13:0];
                    timing_cnt  <= tRCD;
                    bank_active <= 1'b1;
                    cmd_issued  <= 1'b1;
                end
            end
 
            READ: begin
                if (!cmd_issued) begin
                    if (slot) begin
                        DDR5_CS_N  <= 1'b0;
                        DDR5_RAS_N <= 1'b1;
                        DDR5_CAS_N <= 1'b0;
                        DDR5_WE_N  <= 1'b1;
                        DDR5_ADDR  <= CPU_ADDR[13:0];
                        DDR5_BA    <= CPU_ADDR[reg_bank_width+13:14];
                        timing_cnt <= tRL;
                        cmd_issued <= 1'b1;
                    end
                end else if (timing_cnt == 1) begin
                    CPU_RD_DATA <= DDR5_DQ;            // read data valid in this cycle
                    CPU_READY   <= 1'b1;
                    timing_cnt  <= 1;                  // DONE holds off for 2 cycles
                end
            end
 
            WRITE: begin
                if (!cmd_issued) begin
                    // data is driven one cycle BEFORE the command (write data setup)
                    dq_out_reg <= WRT_BUFF[0];
                    dq_en      <= 1'b1;
                    if (slot && dq_en) begin           // dq_en=1 -> data already on the bus
                        DDR5_CS_N  <= 1'b0;
                        DDR5_RAS_N <= 1'b1;
                        DDR5_CAS_N <= 1'b0;
                        DDR5_WE_N  <= 1'b0;
                        DDR5_ADDR  <= CPU_ADDR[13:0];
                        DDR5_BA    <= CPU_ADDR[reg_bank_width+13:14];
                        burst_cnt  <= 1;
                        cmd_issued <= 1'b1;
                    end
                end else begin
                    dq_out_reg <= WRT_BUFF[burst_cnt]; // beats 1 .. burst_length-1
                    dq_en      <= 1'b1;
                    burst_cnt  <= burst_cnt + 1;
                    if (burst_cnt == burst_length-1) begin
                        CPU_READY  <= 1'b1;
                        timing_cnt <= 1;
                    end
                end
            end
 
            REFRESH: begin
                if (!cmd_issued && slot) begin
                    DDR5_CS_N   <= 1'b0;
                    DDR5_RAS_N  <= 1'b0;
                    DDR5_CAS_N  <= 1'b0;               // RAS=0, CAS=0, WE=1 : refresh
                    DDR5_WE_N   <= 1'b1;
                    timing_cnt  <= tRFC;
                    refresh_rq  <= 1'b0;
                    bank_active <= 1'b0;
                    cmd_issued  <= 1'b1;
                end
            end
 
            default: ;                                 // DONE: just wait
        endcase
    end
end
 
// Next-state logic
always @(*) begin
    nxt_state = curr_state;
    case (curr_state)
        IDLE: begin
            if (timing_cnt == 0) begin
                if (refresh_rq)
                    nxt_state = bank_active ? PRECHARGE : REFRESH;
                else if (CPU_VALID) begin
                    if (row_hit)          nxt_state = CPU_WE ? WRITE : READ;
                    else if (bank_active) nxt_state = PRECHARGE;
                    else                  nxt_state = ACTIVATE;
                end
            end
        end
        PRECHARGE: if (cmd_issued && timing_cnt == 0) nxt_state = refresh_rq ? REFRESH : ACTIVATE;
        ACTIVATE:  if (cmd_issued && timing_cnt == 0) nxt_state = CPU_WE ? WRITE : READ;
        READ:      if (cmd_issued && timing_cnt == 1) nxt_state = DONE;
        WRITE:     if (cmd_issued && burst_cnt == burst_length-1) nxt_state = DONE;
        REFRESH:   if (cmd_issued && timing_cnt == 0) nxt_state = IDLE;
        DONE:      if (timing_cnt == 0) nxt_state = IDLE;
        default:   nxt_state = IDLE;
    endcase
end
 
endmodule
