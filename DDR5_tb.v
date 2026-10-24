`timescale 1ns/1ps

module DDR5_tb;

    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter data_width     = 64;
    parameter addr_width     = 20;
    parameter reg_bank_width = 4;
    parameter burst_length   = 16;

    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg clk;
    reg rst;

    // CPU interface
    reg  [addr_width-1:0] CPU_ADDR;
    reg  [data_width-1:0] CPU_WRT_DATA;
    wire [data_width-1:0] CPU_RD_DATA;
    reg  CPU_VALID;
    reg  CPU_WE;
    wire CPU_READY;

    // DDR5 interface
    wire DDR5_CLK_P, DDR5_CLK_N;
    wire DDR5_RST_N, DDR5_CS_N;
    wire DDR5_RAS_N, DDR5_CAS_N, DDR5_WE_N;
    wire [reg_bank_width-1:0] DDR5_BA;
    wire [13:0] DDR5_ADDR;
    wire [data_width-1:0] DDR5_DQ;
    wire [7:0] DDR5_DQS_P, DDR5_DQS_N;
    wire [7:0] DDR5_DM;

    integer i;
    integer read_count  = 0;
    integer write_count = 0;
    integer error_count = 0;     // every mismatch / timeout is counted
    integer err_mark;            // error_count at the start of a test
    integer seed;
    integer n;

    // values for the random test (kept so the read-back can compare them)
    reg [addr_width-1:0] rnd_addr [0:19];
    reg [data_width-1:0] rnd_data [0:19];

    // =========================================================================
    // DUT AND MEMORY MODEL
    // =========================================================================
    DDR5 uut (
        .clk        (clk),
        .rst        (rst),
        .CPU_ADDR   (CPU_ADDR),
        .CPU_WRT_DATA(CPU_WRT_DATA),
        .CPU_RD_DATA(CPU_RD_DATA),
        .CPU_VALID  (CPU_VALID),
        .CPU_WE     (CPU_WE),
        .CPU_READY  (CPU_READY),
        .DDR5_CLK_P (DDR5_CLK_P),
        .DDR5_CLK_N (DDR5_CLK_N),
        .DDR5_RST_N (DDR5_RST_N),
        .DDR5_CS_N  (DDR5_CS_N),
        .DDR5_RAS_N (DDR5_RAS_N),
        .DDR5_CAS_N (DDR5_CAS_N),
        .DDR5_WE_N  (DDR5_WE_N),
        .DDR5_BA    (DDR5_BA),
        .DDR5_ADDR  (DDR5_ADDR),
        .DDR5_DQ    (DDR5_DQ),
        .DDR5_DQS_P (DDR5_DQS_P),
        .DDR5_DQS_N (DDR5_DQS_N),
        .DDR5_DM    (DDR5_DM)
    );

    DDR5_Module sim_mem (
        .clk_P (DDR5_CLK_P),
        .clk_N (DDR5_CLK_N),
        .CS_N  (DDR5_CS_N),
        .RAS_N (DDR5_RAS_N),
        .CAS_N (DDR5_CAS_N),
        .WE_N  (DDR5_WE_N),
        .BA    (DDR5_BA),
        .ADDR  (DDR5_ADDR),
        .DQ    (DDR5_DQ),
        .DM    (DDR5_DM),
        .DQS_P (DDR5_DQS_P),
        .DQS_N (DDR5_DQS_N)
    );

    // =========================================================================
    // CLOCK: 10 ns period (100 MHz)
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // WAVEFORM DUMP (Vivado xsim also records waves by itself)
    // =========================================================================
    initial begin
        $dumpfile("DDR5_tb.vcd");
        $dumpvars(0, DDR5_tb);
    end

    // =========================================================================
    // MAIN SEQUENCE
    // =========================================================================
    initial begin
        $display("==================================================");
        $display("=== DDR5 CONTROLLER TESTBENCH ====================");
        $display("==================================================");
        initialize_signals();
        apply_reset();
        wait_for_init();
        run_test_suite();
        finish_simulation();
    end

    // =========================================================================
    // TASKS
    // =========================================================================
    task initialize_signals;
        begin
            $display("Initializing signals...");
            rst          = 0;
            CPU_VALID    = 0;
            CPU_WE       = 0;
            CPU_ADDR     = {addr_width{1'b0}};
            CPU_WRT_DATA = {data_width{1'b0}};
        end
    endtask

    task apply_reset;
        begin
            $display("Applying reset...");
            rst = 1;
            #40;
            rst = 0;
            $display("Reset released at %0t", $time);
        end
    endtask

    task wait_for_init;
        begin
            $display("Waiting for controller initialization...");
            #2500;
            $display("Initialization done at %0t", $time);
        end
    endtask

    task run_test_suite;
        begin
            test_basic_patterns;      // 1: DC patterns
            test_alternating_access;  // 2: bank / row hopping
            test_burst_patterns;      // 3: sequential bursts
            test_data_integrity;      // 4: walking bits
            test_refresh_behavior;    // 5: access across a refresh
            test_random_access;       // 6: random addresses / data
        end
    endtask

    task finish_simulation;
        begin
            #200;
            $display("==================================================");
            $display("=== FINAL RESULTS ================================");
            $display("Total writes : %0d", write_count);
            $display("Total reads  : %0d", read_count);
            $display("Errors       : %0d", error_count);
            $display("Sim time     : %0t", $time);
            if (error_count == 0) $display("=== ALL TESTS PASSED ===");
            else                  $display("=== TEST FAILED: %0d error(s) ===", error_count);
            $display("==================================================");
            #100;
            $finish;
        end
    endtask

    // ---- prints PASSED/FAILED for the test that just ran ----------------------
    task report_test;
        input [8*32-1:0] name;
        begin
            if (error_count == err_mark) $display("%0s test PASSED", name);
            else                         $display("%0s test FAILED", name);
        end
    endtask

    // =========================================================================
    // TEST CASES
    // =========================================================================
    task test_basic_patterns;
        begin
            $display("=== TEST 1: BASIC DC PATTERNS ===");
            err_mark = error_count;

            write_data(20'h00000, 64'h0000000000000000);
            read_check_data(20'h00000, 64'h0000000000000000);

            write_data(20'h00008, 64'hFFFFFFFFFFFFFFFF);
            read_check_data(20'h00008, 64'hFFFFFFFFFFFFFFFF);

            write_data(20'h00010, 64'hAAAAAAAAAAAAAAAA);
            read_check_data(20'h00010, 64'hAAAAAAAAAAAAAAAA);

            report_test("Basic patterns");
        end
    endtask

    task test_alternating_access;
        begin
            $display("=== TEST 2: ALTERNATING BANK/ROW ACCESS ===");
            err_mark = error_count;

            for (i = 0; i < 8; i = i+1) begin
                write_data(20'h00000 + (i*256), 64'hBEEFCAFEBEEFCAFE + i);
                write_data(20'h10000 + (i*256), 64'hFEEDBEEFFEEDBEEF + i);
                write_data(20'h20000 + (i*256), 64'hDEADBEEFDEADBEEF + i);
            end
            for (i = 0; i < 8; i = i+1) begin
                read_check_data(20'h20000 + (i*256), 64'hDEADBEEFDEADBEEF + i);
                read_check_data(20'h10000 + (i*256), 64'hFEEDBEEFFEEDBEEF + i);
                read_check_data(20'h00000 + (i*256), 64'hBEEFCAFEBEEFCAFE + i);
            end

            report_test("Alternating access");
        end
    endtask

    task test_burst_patterns;
        begin
            $display("=== TEST 3: BURST SEQUENTIAL PATTERNS ===");
            err_mark = error_count;

            for (i = 0; i < burst_length; i = i+1)
                write_data(20'h03000 + i, 64'h1111111111111111 + i);
            for (i = 0; i < burst_length; i = i+1)
                write_data(20'h03100 + i, 64'hEEEEEEEEEEEEEEEE - i);

            for (i = 0; i < burst_length; i = i+1) begin
                read_check_data(20'h03000 + i, 64'h1111111111111111 + i);
                read_check_data(20'h03100 + i, 64'hEEEEEEEEEEEEEEEE - i);
            end

            report_test("Burst patterns");
        end
    endtask

    task test_data_integrity;
        begin
            $display("=== TEST 4: WALKING BIT PATTERNS ===");
            err_mark = error_count;

            // walking ones
            for (i = 0; i < 64; i = i+1) begin
                write_data(20'h04000 + (i/4), 64'h0000000000000001 << (i % 64));
                read_check_data(20'h04000 + (i/4), 64'h0000000000000001 << (i % 64));
            end
            // walking zeros
            for (i = 0; i < 64; i = i+1) begin
                write_data(20'h04200 + (i/4), 64'hFFFFFFFFFFFFFFFF ^ (64'h0000000000000001 << (i % 64)));
                read_check_data(20'h04200 + (i/4), 64'hFFFFFFFFFFFFFFFF ^ (64'h0000000000000001 << (i % 64)));
            end

            report_test("Data integrity");
        end
    endtask

    task test_refresh_behavior;
        begin
            $display("=== TEST 5: REFRESH BEHAVIOR ===");
            err_mark = error_count;

            write_data(20'h05000, 64'hABCDEF0123456789);

            // wait so that the next accesses fall near a refresh
            // (adjust to your controller's refresh interval)
            #1900;

            write_data(20'h05008, 64'h123456789ABCDEF0);
            read_check_data(20'h05008, 64'h123456789ABCDEF0);

            read_check_data(20'h05000, 64'hABCDEF0123456789);

            report_test("Refresh behavior");
        end
    endtask

    task test_random_access;
        begin
            $display("=== TEST 6: RANDOM ACCESS PATTERNS ===");
            err_mark = error_count;

            // fixed seed -> same values on every run; values are stored for the read-back
            seed = 12345;
            for (n = 0; n < 20; n = n + 1) begin
                rnd_addr[n] = $random(seed);
                rnd_data[n] = {$random(seed), $random(seed)};
                write_data(rnd_addr[n], rnd_data[n]);
            end

            // read back in reverse order
            for (n = 19; n >= 0; n = n - 1)
                read_check_data(rnd_addr[n], rnd_data[n]);

            report_test("Random access");
        end
    endtask

    // =========================================================================
    // HELPER TASKS
    // =========================================================================
    task write_data;
        input [addr_width-1:0] addr;
        input [data_width-1:0] data;
        reg [15:0] timeout_count;
        begin
            @(posedge clk);
            CPU_ADDR     = addr;
            CPU_WRT_DATA = data;
            CPU_WE       = 1;
            CPU_VALID    = 1;

            timeout_count = 0;
            while (!CPU_READY && timeout_count < 500) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 500) begin
                $display("ERROR: Write timeout at address 0x%05h!", addr);
                error_count = error_count + 1;
            end else begin
                write_count = write_count + 1;
            end

            @(posedge clk);
            CPU_VALID = 0;
            CPU_WE    = 0;
        end
    endtask

    task read_data;
        input [addr_width-1:0] addr;
        reg [15:0] timeout_count;
        begin
            @(posedge clk);
            CPU_ADDR  = addr;
            CPU_WE    = 0;
            CPU_VALID = 1;

            timeout_count = 0;
            while (!CPU_READY && timeout_count < 500) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 500) begin
                $display("ERROR: Read timeout at address 0x%05h!", addr);
                error_count = error_count + 1;
            end

            @(posedge clk);
            CPU_VALID = 0;
        end
    endtask

    task read_check_data;
        input [addr_width-1:0] addr;
        input [data_width-1:0] expected_data;
        begin
            read_data(addr);
            if (CPU_RD_DATA !== expected_data) begin
                $display("ERROR: Data mismatch at address 0x%05h!", addr);
                $display("  Expected: 0x%016h", expected_data);
                $display("  Received: 0x%016h", CPU_RD_DATA);
                error_count = error_count + 1;
            end else begin
                read_count = read_count + 1;
                $display("  Read verified: 0x%016h at 0x%05h", expected_data, addr);
            end
        end
    endtask

    // =========================================================================
    // COMMAND MONITOR (decode visible in the log)
    // =========================================================================
    always @(posedge clk) begin
        if (!DDR5_CS_N && DDR5_RST_N) begin
            case ({DDR5_RAS_N, DDR5_CAS_N, DDR5_WE_N})
                3'b011: $display("[%0t] CMD: ACTIVATE Bank=%0d", $time, DDR5_BA);
                3'b101: $display("[%0t] CMD: READ", $time);
                3'b100: $display("[%0t] CMD: WRITE", $time);
                3'b010: $display("[%0t] CMD: PRECHARGE", $time);
                3'b001: $display("[%0t] CMD: REFRESH", $time);
                default: ;
            endcase
        end
    end

    // =========================================================================
    // TIMEOUT PROTECTION (500 us)
    // =========================================================================
    initial begin
        #500000;
        $display("ERROR: Simulation exceeded time limit");
        $display("Final state: Ready=%b, Valid=%b", CPU_READY, CPU_VALID);
        $finish;
    end

endmodule
