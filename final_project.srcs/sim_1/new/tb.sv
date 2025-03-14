module transformer_encoder_tb;
    // Parameters
    parameter DATA_WIDTH = 16;
    parameter MATRIX_SIZE = 16;
    parameter MATRIX_SIDE = 4;  // Added for 2D arrays
    parameter NUM_PES = 4;
    parameter FIXED_POINT = 8;
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic data_in_valid;
    logic data_out_valid;
    logic data_out_ready;
    logic data_in_ready;
    logic [DATA_WIDTH-1:0] data_in_serial;
    logic [DATA_WIDTH-1:0] data_out_serial;
    logic done;

    // Test matrices
    logic [DATA_WIDTH-1:0] test_input [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] test_input_flat [MATRIX_SIZE];  // For serial input
    logic [DATA_WIDTH-1:0] received_output [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] received_output_flat [MATRIX_SIZE];  // For serial output
    int input_idx, output_idx;

    // DUT instantiation
    transformer_encoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .MATRIX_SIDE(MATRIX_SIDE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in_valid(data_in_valid),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .data_in_ready(data_in_ready),
        .data_in_serial(data_in_serial),
        .data_out_serial(data_out_serial),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Initialize test data with simple sequential values
    initial begin
        // Fill 2D array with sequential values
        for (int i = 0; i < MATRIX_SIDE; i++) begin
            for (int j = 0; j < MATRIX_SIDE; j++) begin
                test_input[i][j] = ((i * MATRIX_SIDE + j) + 1) << FIXED_POINT;
                // Also create flat array for serial input
                test_input_flat[i * MATRIX_SIDE + j] = test_input[i][j];
            end
        end
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        data_in_valid = 0;
        data_out_ready = 0;
        data_in_serial = 0;
        input_idx = 0;
        output_idx = 0;

        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Start transaction
        start = 1;
        @(posedge clk);
        start = 0;

        // Input data sequence
        $display("Starting input sequence at time %0t", $time);
        while (input_idx <= MATRIX_SIZE) begin
            @(posedge clk);
            if (data_in_ready) begin
                data_in_valid = 1;
                data_in_serial = test_input_flat[input_idx];
                $display("Sending input[%0d][%0d] = %h at time %0t", 
                        input_idx/MATRIX_SIDE, input_idx%MATRIX_SIDE,
                        data_in_serial, $time);
                input_idx++;
            end else begin
                data_in_valid = 0;
            end
        end
        data_in_valid = 0;

        // Wait for processing
        $display("Waiting for processing to complete at time %0t", $time);
        wait(done);
        $display("Processing completed at time %0t", $time);

        // Output data sequence
        $display("Starting output sequence at time %0t", $time);
        data_out_ready = 1;
        while (output_idx < MATRIX_SIZE) begin
            @(posedge clk);
            if (data_out_valid) begin
                received_output_flat[output_idx] = data_out_serial;
                // Convert to 2D array
                received_output[output_idx/MATRIX_SIDE][output_idx%MATRIX_SIDE] = data_out_serial;
                $display("Received output[%0d][%0d] = %h at time %0t", 
                        output_idx/MATRIX_SIDE, output_idx%MATRIX_SIDE,
                        data_out_serial, $time);
                output_idx++;
            end
        end

        // Display results in matrix format
        $display("\nTest Results:");
        $display("Input Matrix (Fixed Point %0d.%0d format):", 
                DATA_WIDTH-FIXED_POINT, FIXED_POINT);
        for (int i = 0; i < MATRIX_SIDE; i++) begin
            for (int j = 0; j < MATRIX_SIDE; j++) begin
                $write("%8.3f ", $itor(test_input[i][j]) / $itor(1 << FIXED_POINT));
            end
            $display("");
        end
        
        $display("\nOutput Matrix (Fixed Point %0d.%0d format):", 
                DATA_WIDTH-FIXED_POINT, FIXED_POINT);
        for (int i = 0; i < MATRIX_SIDE; i++) begin
            for (int j = 0; j < MATRIX_SIDE; j++) begin
                $write("%8.3f ", $itor(received_output[i][j]) / $itor(1 << FIXED_POINT));
            end
            $display("");
        end

        #(CLK_PERIOD * 10);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000);
        $display("Timeout! Test failed.");
        $finish;
    end

    // Monitor state transitions
    always @(posedge clk) begin
        if (dut.state != dut.state) begin
            $display("State change to %s at time %0t", 
                    dut.state.name(), $time);
        end
    end

endmodule