module transformer_encoder #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,    // Total size (e.g., 16)
    parameter MATRIX_SIDE = 4,     // Square root of MATRIX_SIZE (e.g., 4)
    parameter NUM_PES = 4,
    parameter FIXED_POINT = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic data_in_valid,
    output logic data_out_valid,
    input  logic data_out_ready,
    output logic data_in_ready,
    input  logic [DATA_WIDTH-1:0] data_in_serial,
    output logic [DATA_WIDTH-1:0] data_out_serial,
    output logic done
);
    // Internal 1D arrays for serial I/O
    logic [DATA_WIDTH-1:0] data_in [MATRIX_SIZE];
    logic [$clog2(MATRIX_SIZE) + 1:0] data_io_state;

    // 2D matrix signals for computation
    logic [DATA_WIDTH-1:0] q_matrix [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] k_matrix [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] k_matrix_t [MATRIX_SIDE][MATRIX_SIDE];  // Transposed K
    logic [DATA_WIDTH-1:0] v_matrix [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] qk_scores [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] qk_scores_flat [MATRIX_SIZE];  // For scale/softmax
    logic [DATA_WIDTH-1:0] qk_scaled [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] attention_weights [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] attention_matrix [MATRIX_SIDE][MATRIX_SIDE];
    logic [DATA_WIDTH-1:0] output_matrix [MATRIX_SIDE][MATRIX_SIDE];

    // Control signals
    logic start_qk, start_scale, start_softmax, start_v;
    logic qk_done, scale_done, softmax_done, v_done;

    // State machine
    typedef enum logic [3:0] {
        IDLE,
        LOAD_DATA,
        INIT_QKV,
        COMPUTE_QK,
        WAIT_QK,
        SCALE_QK,
        WAIT_SCALE,
        COMPUTE_SOFTMAX,
        WAIT_SOFTMAX,
        COMPUTE_V,
        WAIT_V,
        OUTPUT_DATA
    } state_t;

    state_t state;

    // Matrix multiply for Q-K multiplication
    matrix_multiply #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_DIM(MATRIX_SIDE),
        .FIXED_POINT(FIXED_POINT)
    ) qk_multiply (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_qk),
        .matrix_a(q_matrix),
        .matrix_b(k_matrix_t),
        .matrix_out(qk_scores),
        .all_done(qk_done)
    );

    // Processor for scaling
    processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) proc_scale (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_scale),
        .proc_mode(2'b01),  // Scale mode
        .data_in_a(qk_scores_flat),
        .data_in_b(),  // Not used in scale mode
        .data_out(qk_scaled),
        .done(scale_done)
    );

    // Processor for softmax
    processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) proc_softmax (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_softmax),
        .proc_mode(2'b10),  // Softmax mode
        .data_in_a(qk_scaled),
        .data_in_b(),  // Not used in softmax mode
        .data_out(attention_weights),
        .done(softmax_done)
    );

    // Matrix multiply for attention-V multiplication
    matrix_multiply #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_DIM(MATRIX_SIDE),
        .FIXED_POINT(FIXED_POINT)
    ) v_multiply (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_v),
        .matrix_a(attention_matrix),
        .matrix_b(v_matrix),
        .matrix_out(output_matrix),
        .all_done(v_done)
    );

    // Convert between 2D and 1D arrays
    always_comb begin
        // Flatten QK scores for scaling
        for (int i = 0; i < MATRIX_SIDE; i++) begin
            for (int j = 0; j < MATRIX_SIDE; j++) begin
                qk_scores_flat[i*MATRIX_SIDE + j] = qk_scores[i][j];
            end
        end

        // Reshape attention weights to 2D for V multiplication
        for (int i = 0; i < MATRIX_SIDE; i++) begin
            for (int j = 0; j < MATRIX_SIDE; j++) begin
                attention_matrix[i][j] = attention_weights[i*MATRIX_SIDE + j];
            end
        end
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            start_qk <= 1'b0;
            start_scale <= 1'b0;
            start_softmax <= 1'b0;
            start_v <= 1'b0;
            data_io_state <= '0;
            data_in_ready <= 1'b1;
            data_out_valid <= 1'b0;
            data_out_serial <= '0;
            for (int i = 0; i < MATRIX_SIDE; i++) begin
                for (int j = 0; j < MATRIX_SIDE; j++) begin
                    q_matrix[i][j] <= '0;
                    k_matrix[i][j] <= '0;
                    k_matrix_t[i][j] <= '0;
                    v_matrix[i][j] <= '0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_DATA;
                        done <= 1'b0;
                    end
                end
                
                LOAD_DATA: begin
                    if (data_io_state == MATRIX_SIZE) begin
                        state <= INIT_QKV;
                        data_io_state <= '0;
                        data_in_ready <= 1'b0;
                    end
                    else if (data_in_valid && data_io_state < MATRIX_SIZE) begin
                        data_in[data_io_state] <= data_in_serial;
                        data_io_state <= data_io_state + 1;
                        data_in_ready <= 1'b1;
                    end
                end

                INIT_QKV: begin
                    // Convert 1D input to 2D matrices and create transpose
                    for (int i = 0; i < MATRIX_SIDE; i++) begin
                        for (int j = 0; j < MATRIX_SIDE; j++) begin
                            q_matrix[i][j] <= data_in[i*MATRIX_SIDE + j] >>> 2;
                            k_matrix[i][j] <= data_in[i*MATRIX_SIDE + j] >>> 2;
                            k_matrix_t[j][i] <= data_in[i*MATRIX_SIDE + j] >>> 2; // Transpose
                            v_matrix[i][j] <= data_in[i*MATRIX_SIDE + j];
                        end
                    end
                    state <= COMPUTE_QK;
                end

                COMPUTE_QK: begin
                    start_qk <= 1'b1;
                    state <= WAIT_QK;
                end

                WAIT_QK: begin
                    start_qk <= 1'b0;
                    if (qk_done) begin
                        state <= SCALE_QK;
                    end
                end

                SCALE_QK: begin
                    start_scale <= 1'b1;
                    state <= WAIT_SCALE;
                end

                WAIT_SCALE: begin
                    start_scale <= 1'b0;
                    if (scale_done) begin
                        state <= COMPUTE_SOFTMAX;
                    end
                end

                COMPUTE_SOFTMAX: begin
                    start_softmax <= 1'b1;
                    state <= WAIT_SOFTMAX;
                end

                WAIT_SOFTMAX: begin
                    start_softmax <= 1'b0;
                    if (softmax_done) begin
                        state <= COMPUTE_V;
                    end
                end

                COMPUTE_V: begin
                    start_v <= 1'b1;
                    state <= WAIT_V;
                end

                WAIT_V: begin
                    start_v <= 1'b0;
                    if (v_done) begin
                        state <= OUTPUT_DATA;
                        data_io_state <= '0;
                        done <= 1'b1;
                    end
                end
                
                OUTPUT_DATA: begin
                    if (data_io_state == MATRIX_SIZE) begin
                        state <= IDLE;
                        data_out_valid <= 1'b0;
                        done <= 1'b1;
                    end
                    
                    data_out_serial <= output_matrix[data_io_state/MATRIX_SIDE][data_io_state%MATRIX_SIDE];
                    data_out_valid <= 1'b1;
                    if (data_out_ready) begin
                        data_io_state <= data_io_state + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule