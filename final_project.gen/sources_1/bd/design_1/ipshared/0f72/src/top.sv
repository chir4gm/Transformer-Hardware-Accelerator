module transformer_encoder #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,
    parameter NUM_PES = 4,
    parameter FIXED_POINT = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic data_in_valid,
    output  logic data_out_valid,
    input  logic data_out_ready,
    output logic data_in_ready,
    input  logic [DATA_WIDTH-1:0] data_in_serial,
    output logic [DATA_WIDTH-1:0] data_out_serial,
    output logic done
);
    // Internal matrices
    logic [DATA_WIDTH-1:0] data_in [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] data_out [MATRIX_SIZE];
    logic [$clog2(MATRIX_SIZE) + 1:0] data_io_state;

    logic [DATA_WIDTH-1:0] q_matrix [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] k_matrix [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] v_matrix [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] qk_scores [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] qk_scaled [MATRIX_SIZE];
    logic [DATA_WIDTH-1:0] attention_weights [MATRIX_SIZE];

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

    // Processor instances
    processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) proc_qk (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_qk),
        .proc_mode(2'b00),  // QK mode
        .data_in_a(q_matrix),
        .data_in_b(k_matrix),
        .data_out(qk_scores),
        .done(qk_done)
    );

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
        .data_in_a(qk_scores),
        .data_in_b(),  // Not used in scale mode
        .data_out(qk_scaled),
        .done(scale_done)
    );

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

    processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) proc_v (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_v),
        .proc_mode(2'b11),  // V mode
        .data_in_a(attention_weights),
        .data_in_b(v_matrix),
        .data_out(data_out),
        .done(v_done)
    );

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
            for (int i = 0; i < MATRIX_SIZE; i++) begin
                q_matrix[i] <= '0;
                k_matrix[i] <= '0;
                v_matrix[i] <= '0;
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
                    // Initialize matrices with scaled input
                    for (int i = 0; i < MATRIX_SIZE; i++) begin
                        q_matrix[i] <= data_in[i] >>> 2;  // Q = input * 0.25
                        k_matrix[i] <= data_in[i] >>> 2;  // K = input * 0.25
                        v_matrix[i] <= data_in[i];        // V = input
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
                    
                    data_out_serial <= data_out[data_io_state];
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