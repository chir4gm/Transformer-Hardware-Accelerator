// Processing Element Module
module PE #(
    parameter DATA_WIDTH = 16
) (
    input clk,
    input reset,
    input logic [DATA_WIDTH-1:0] a_in,
    input logic [DATA_WIDTH-1:0] b_in,
    input logic [DATA_WIDTH-1:0] sum_in,
    output logic [DATA_WIDTH-1:0] a_out,
    output logic [DATA_WIDTH-1:0] b_out,
    output logic [DATA_WIDTH-1:0] sum_out
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sum_out <= 0;
            a_out <= 0;
            b_out <= 0;
        end else begin
            sum_out <= sum_in + a_in * b_in;
            a_out <= a_in;
            b_out <= b_in;
        end
    end

endmodule

module systolic_array_matrix_multiply #(
    parameter N = 4,                      // Matrix size (NxN)
    parameter DATA_WIDTH = 16             // Bit width of matrix elements
) (
    input clk,
    input reset,
    input logic [DATA_WIDTH-1:0] A_flat [0:N*N-1], // Flattened input matrix A
    input logic [DATA_WIDTH-1:0] B_flat [0:N*N-1], // Flattened input matrix B
    output logic [DATA_WIDTH-1:0] C_flat [0:N*N-1] // Flattened output matrix C
);

    // Internal 2D representations of the matrices
    logic [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] C [0:N-1][0:N-1];

    genvar i, j;
    generate
        // Reconstruct 2D matrices from flattened inputs
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                assign A[i][j] = A_flat[i*N + j];
                assign B[i][j] = B_flat[i*N + j];
                assign C_flat[i*N + j] = C[i][j];
            end
        end
    endgenerate

    // Internal signals for PE connections
    logic [DATA_WIDTH-1:0] a_in [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] b_in [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] sum_in [0:N-1][0:N-1];

    logic [DATA_WIDTH-1:0] a_out [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] b_out [0:N-1][0:N-1];
    logic [DATA_WIDTH-1:0] sum_out [0:N-1][0:N-1];

    // Instantiate PEs and set up connections
    generate
        for (i = 0; i < N; i++) begin : row
            for (j = 0; j < N; j++) begin : col
                PE #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .a_in(a_in[i][j]),
                    .b_in(b_in[i][j]),
                    .sum_in(sum_in[i][j]),
                    .a_out(a_out[i][j]),
                    .b_out(b_out[i][j]),
                    .sum_out(sum_out[i][j])
                );

                // Feed inputs and outputs appropriately
                if (j == 0) begin
                    assign a_in[i][j] = A[i][j];
                end else begin
                    assign a_in[i][j] = a_out[i][j-1];
                end

                if (i == 0) begin
                    assign b_in[i][j] = B[i][j];
                end else begin
                    assign b_in[i][j] = b_out[i-1][j];
                end

                if (i == 0 || j == 0) begin
                    assign sum_in[i][j] = 0;
                end else begin
                    assign sum_in[i][j] = sum_out[i-1][j-1];
                end

                // Collect the outputs
                assign C[i][j] = sum_out[i][j];
            end
        end
    endgenerate

endmodule