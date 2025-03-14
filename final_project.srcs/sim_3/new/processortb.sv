module processor_tb;
    // Parameters
    parameter DATA_WIDTH = 16;
    parameter MATRIX_SIZE = 16;
    parameter NUM_PES = 4;
    parameter FIXED_POINT = 8;
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic [1:0] proc_mode;
    logic [DATA_WIDTH-1:0] data_in_a [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] data_in_b [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] data_out [MATRIX_SIZE];
    logic done;

    // DUT instantiation
    processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .proc_mode(proc_mode),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .data_out(data_out),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    task initialize_inputs();
        start = 0;
        proc_mode = 2'b00;
        for (int i = 0; i < MATRIX_SIZE; i++) begin
            data_in_a[i] = 16'h0100; // 1.0 in fixed point
            data_in_b[i] = 16'h0100; // 1.0 in fixed point
        end
    endtask

    task reset_system();
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);
    endtask

    task wait_for_done();
        while (!done) @(posedge clk);
        #(CLK_PERIOD);
    endtask

    function void check_multiply_results();
        automatic bit error = 0;
        for (int i = 0; i < MATRIX_SIZE; i++) begin
            if (data_out[i] !== 16'h0100) begin // Expected: 1.0 * 1.0 = 1.0
                $display("Error at index %0d: Expected 16'h0100, Got %h", i, data_out[i]);
                error = 1;
            end
        end
        if (!error) $display("Multiplication test passed!");
    endfunction

    function void check_accumulation_results();
        automatic bit error = 0;
        for (int i = 0; i < MATRIX_SIZE; i++) begin
            automatic logic [DATA_WIDTH-1:0] expected;
            expected = 16'h0100 * (i + 1);
            if (data_out[i] !== expected) begin
                $display("Error at index %0d: Expected %h, Got %h", i, expected, data_out[i]);
                error = 1;
            end
        end
        if (!error) $display("Accumulation test passed!");
    endfunction

    // Main test sequence
    initial begin
        $display("Starting processor testbench...");
        
        // Initialize and reset
        initialize_inputs();
        reset_system();

        // Test 1: Basic multiplication (Q*K mode)
        $display("\nTest 1: Basic multiplication");
        proc_mode = 2'b00;
        start = 1;
        #(CLK_PERIOD * 2);
        start = 0;
        wait_for_done();
        check_multiply_results();

        // Test 2: Accumulation (V mode)
        $display("\nTest 2: Accumulation");
        proc_mode = 2'b11;
        start = 1;
#(CLK_PERIOD * 2);
        start = 0;
        wait_for_done();
        check_accumulation_results();

        // Test 3: Scale operation
        $display("\nTest 3: Scale operation");
        proc_mode = 2'b01;
        start = 1;
#(CLK_PERIOD * 2);
        start = 0;
        wait_for_done();
        $display("Scale operation completed");

        // Test 4: Softmax operation
        $display("\nTest 4: Softmax operation");
        proc_mode = 2'b10;
        start = 1;
#(CLK_PERIOD * 2);
        start = 0;
        wait_for_done();
        $display("Softmax operation completed");

        $display("\nAll tests completed!");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 1000);
        $display("Timeout! Test failed to complete within expected time.");
        $finish;
    end

    // Optional: Waveform dumping
    initial begin
        $dumpfile("processor_tb.vcd");
        $dumpvars(0, processor_tb);
    end

endmodule