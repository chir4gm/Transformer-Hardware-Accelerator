module matrix_multiply_tb();
    parameter DATA_WIDTH = 16;
    parameter MATRIX_DIM = 4;
    parameter FIXED_POINT = 8;
    parameter CLK_PERIOD = 10;
    parameter MAX_VALUE = 4;  // Maximum random value to keep products manageable

    // Testbench signals
    logic clk;
    logic rst_n;
    logic start;
    logic [DATA_WIDTH-1:0] matrix_a [MATRIX_DIM][MATRIX_DIM];
    logic [DATA_WIDTH-1:0] matrix_b [MATRIX_DIM][MATRIX_DIM];
    logic [DATA_WIDTH-1:0] matrix_out [MATRIX_DIM][MATRIX_DIM];
    logic [DATA_WIDTH-1:0] expected_out [MATRIX_DIM][MATRIX_DIM];
    logic all_done;

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // DUT instantiation
    matrix_multiply #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_DIM(MATRIX_DIM),
        .FIXED_POINT(FIXED_POINT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_out(matrix_out),
        .all_done(all_done)
    );

    // Function to generate random fixed-point number
    function logic [DATA_WIDTH-1:0] random_fixed();
        logic [3:0] rand_int;  // Using 4 bits for small random numbers
        rand_int = $urandom() % MAX_VALUE;  // Keep values small to avoid overflow
        return (rand_int << FIXED_POINT);  // Convert to fixed-point
    endfunction

    // Task to calculate expected output
    task calculate_expected_output();
        for (int i = 0; i < MATRIX_DIM; i++) begin
            for (int j = 0; j < MATRIX_DIM; j++) begin
                expected_out[i][j] = 0;
                for (int k = 0; k < MATRIX_DIM; k++) begin
                    // For fixed-point multiplication:
                    // 1. Multiply the values
                    // 2. Shift right by FIXED_POINT to adjust fixed-point position
                    logic [2*DATA_WIDTH-1:0] temp_mult;
                    temp_mult = (matrix_a[i][k] * matrix_b[k][j]) >> FIXED_POINT;
                    expected_out[i][j] += temp_mult[DATA_WIDTH-1:0];
                end
            end
        end
    endtask

    // Task to print matrix
    task print_matrix(input string name, input logic [DATA_WIDTH-1:0] matrix [MATRIX_DIM][MATRIX_DIM]);
        $display("\n%s:", name);
        for (int i = 0; i < MATRIX_DIM; i++) begin
            for (int j = 0; j < MATRIX_DIM; j++) begin
                $write("%f ", real'(matrix[i][j]) / real'(1 << FIXED_POINT));
            end
            $display("");
        end
    endtask

    // Task to verify results
    task verify_results();
        logic failed = 0;
        for (int i = 0; i < MATRIX_DIM; i++) begin
            for (int j = 0; j < MATRIX_DIM; j++) begin
                // Allow for small rounding differences
                if (abs(expected_out[i][j] - matrix_out[i][j]) > (1 << (FIXED_POINT-4))) begin
                    $display("Mismatch at [%0d][%0d]: Expected %f, Got %f", 
                            i, j, 
                            real'(expected_out[i][j]) / real'(1 << FIXED_POINT),
                            real'(matrix_out[i][j]) / real'(1 << FIXED_POINT));
                    failed = 1;
                end
            end
        end
        if (!failed) begin
            $display("Test PASSED - All results match within tolerance!");
        end else begin
            $display("Test FAILED - See mismatches above");
        end
    endtask

    function int abs(logic [DATA_WIDTH-1:0] value);
        return (value[DATA_WIDTH-1]) ? -value : value;
    endfunction

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        
        // Generate random matrices
        for (int i = 0; i < MATRIX_DIM; i++) begin
            for (int j = 0; j < MATRIX_DIM; j++) begin
                matrix_a[i][j] = random_fixed();
                matrix_b[i][j] = random_fixed();
            end
        end

        // Calculate expected result
        calculate_expected_output();

        // Reset sequence
        @(posedge clk);
        #1 rst_n = 1;
        
        // Start computation
        @(posedge clk);
        #1 start = 1;
        @(posedge clk);
        #1 start = 0;

        // Wait for completion
        wait(all_done);
        @(posedge clk);

        // Display and verify results
        print_matrix("Matrix A", matrix_a);
        print_matrix("Matrix B", matrix_b);
        print_matrix("Result Matrix", matrix_out);
        print_matrix("Expected Matrix", expected_out);
        verify_results();

        // Add some cycles after completion
        repeat(5) @(posedge clk);
        
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 1000);
        $display("Timeout: Test failed to complete within specified time");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("matrix_multiply.vcd");
        $dumpvars(0, matrix_multiply_tb);
    end

endmodule