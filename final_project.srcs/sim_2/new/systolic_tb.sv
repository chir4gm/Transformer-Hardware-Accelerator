module systolic_array_matrix_multiply_tb;

    parameter N = 4;
    parameter DATA_WIDTH = 16;

    reg clk;
    reg reset;
    reg [DATA_WIDTH-1:0] A_flat [0:N*N-1];
    reg [DATA_WIDTH-1:0] B_flat [0:N*N-1];
    wire [DATA_WIDTH-1:0] C_flat [0:N*N-1];

    // Instantiate the systolic array module
    systolic_array_matrix_multiply #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .A_flat(A_flat),
        .B_flat(B_flat),
        .C_flat(C_flat)
    );

    // Clock generation (100MHz clock)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer i, j;

    initial begin
        // Initialize inputs
        reset = 1;
        #10;
        reset = 0;

        // Initialize matrices A and B with example values
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                A_flat[i*N + j] = i + j + 1;              // Example values
                B_flat[i*N + j] = i + j + 1;       // Identity matrix
            end
        end

        // Wait for computations to finish
        #(20*N); // Wait sufficient cycles for computations

        // Display results
        $display("Matrix A:");
        for (i = 0; i < N; i++) begin
            $write("| ");
            for (j = 0; j < N; j++) begin
                $write("%0d ", A_flat[i*N + j]);
            end
            $write("|\n");
        end

        $display("Matrix B:");
        for (i = 0; i < N; i++) begin
            $write("| ");
            for (j = 0; j < N; j++) begin
                $write("%0d ", B_flat[i*N + j]);
            end
            $write("|\n");
        end

        $display("Matrix C = A x B:");
        for (i = 0; i < N; i++) begin
            $write("| ");
            for (j = 0; j < N; j++) begin
                $write("%0d ", C_flat[i*N + j]);
            end
            $write("|\n");
        end

        $stop;
    end

endmodule