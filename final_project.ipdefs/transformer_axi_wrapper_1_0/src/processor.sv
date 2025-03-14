module processor #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,
    parameter NUM_PES = 4,
    parameter FIXED_POINT = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [1:0] proc_mode,  // 00: Q*K, 01: Scale, 10: Softmax, 11: V
    input  logic [DATA_WIDTH-1:0] data_in_a [MATRIX_SIZE],
    input  logic [DATA_WIDTH-1:0] data_in_b [MATRIX_SIZE],
    output logic [DATA_WIDTH-1:0] data_out [MATRIX_SIZE],
    output logic done
);
    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        COMPUTE,
        WAIT_VALID,
        STORE,
        DONE
    } state_t;
    
    state_t state;
    
    // Internal signals
    logic valid_in_array [NUM_PES];
    logic [2:0] op_code_array [NUM_PES];
    logic [DATA_WIDTH-1:0] data_in_a_array [NUM_PES];
    logic [DATA_WIDTH-1:0] data_in_b_array [NUM_PES];
    logic [DATA_WIDTH-1:0] data_in_acc_array [NUM_PES];
    logic valid_out_array [NUM_PES];
    logic acc_valid_array [NUM_PES];
    logic [DATA_WIDTH-1:0] data_out_array [NUM_PES];
    logic pe_active [NUM_PES];
    
    logic [$clog2(MATRIX_SIZE):0] idx;
    logic [DATA_WIDTH-1:0] data_out_buffer [MATRIX_SIZE];
    
    logic all_valid;
    
    assign all_valid = (proc_mode == 2'b11) ? 
        (valid_out_array[0] && acc_valid_array[0]) :  // Sequential for accumulation
        (valid_out_array[NUM_PES-1] && valid_out_array[NUM_PES-2] && 
         valid_out_array[NUM_PES-3] && valid_out_array[NUM_PES-4]);  // Parallel for others
    
    // PE array instantiation
    genvar i;
    generate
        for (i = 0; i < NUM_PES; i++) begin : pe_array
            pe #(
                .DATA_WIDTH(DATA_WIDTH),
                .FIXED_POINT(FIXED_POINT)
            ) pe_inst (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(valid_in_array[i]),
                .op_code(op_code_array[i]),
                .data_in_a(data_in_a_array[i]),
                .data_in_b(data_in_b_array[i]),
                .acc_in(data_in_acc_array[i]),
                .data_out(data_out_array[i]),
                .valid_out(valid_out_array[i]),
                .acc_valid(acc_valid_array[i])
            );
        end
    endgenerate
    
    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= '0;
            done <= 1'b0;
            
            for (int j = 0; j < NUM_PES; j++) begin
                valid_in_array[j] <= 1'b0;
                op_code_array[j] <= 3'b000;
                data_in_a_array[j] <= '0;
                data_in_b_array[j] <= '0;
                data_in_acc_array[j] <= '0;
                pe_active[j] <= 1'b0;
            end
            
            for (int j = 0; j < MATRIX_SIZE; j++) begin
                data_out_buffer[j] <= '0;
                data_out[j] <= '0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        idx <= '0;
                        done <= 1'b0;
                    end
                end
                
                LOAD: begin
                    if (proc_mode == 2'b11) begin
                        // Sequential execution for accumulation
                        // Only activate one PE at a time
                        for (int i = 0; i < NUM_PES; i++) begin
                            if (i == 0) begin  // Only work with first PE
                                automatic int data_idx = idx;
                                if (data_idx < MATRIX_SIZE) begin
                                    op_code_array[i] <= 3'b001;  // V multiply with acc
                                    valid_in_array[i] <= 1'b1;
                                    data_in_a_array[i] <= data_in_a[data_idx];
                                    data_in_b_array[i] <= data_in_b[data_idx];
                                    data_in_acc_array[i] <= (data_idx == 0) ? '0 : data_out_buffer[data_idx - 1];
                                    pe_active[i] <= 1'b1;
                                end else begin
                                    valid_in_array[i] <= 1'b0;
                                    pe_active[i] <= 1'b0;
                                end
                            end else begin
                                // Disable all other PEs
                                valid_in_array[i] <= 1'b0;
                                pe_active[i] <= 1'b0;
                            end
                        end
                        if (valid_out_array[0] && acc_valid_array[0]) begin
                            state <= COMPUTE;
                        end
                    end else begin
                        // Original parallel execution for non-accumulation operations
                        for (int i = 0; i < NUM_PES; i++) begin
                            automatic int data_idx = idx + i;
                            if (data_idx < MATRIX_SIZE) begin
                                case (proc_mode)
                                    2'b00: op_code_array[i] <= 3'b000;  // QK multiply
                                    2'b01: op_code_array[i] <= 3'b010;  // Scale
                                    2'b10: op_code_array[i] <= 3'b011;  // Softmax
                                endcase
                                valid_in_array[i] <= 1'b1;
                                data_in_a_array[i] <= data_in_a[data_idx];
                                data_in_b_array[i] <= data_in_b[data_idx];
                                pe_active[i] <= 1'b1;
                            end else begin
                                valid_in_array[i] <= 1'b0;
                                pe_active[i] <= 1'b0;
                            end
                        end
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    for (int i = 0; i < NUM_PES; i++) begin
                        valid_in_array[i] <= 1'b0;
                    end
                    state <= WAIT_VALID;
                end
                
                WAIT_VALID: begin
                    if (all_valid) begin
                        state <= STORE;
                    end
                end
                
                STORE: begin
                    if (proc_mode == 2'b11) begin
                        // Store single result for accumulation
                        if (pe_active[0]) begin
                            data_out_buffer[idx] <= data_out_array[0];
                        end
                        idx <= idx + 1;  // Increment by 1 for sequential operation
                        if (idx + 1 >= MATRIX_SIZE) begin
                            state <= DONE;
                        end else begin
                            state <= LOAD;
                        end
                    end else begin
                        // Original parallel store
                        for (int i = 0; i < NUM_PES; i++) begin
                            if (pe_active[i]) begin
                                automatic int data_idx = idx + i;
                                if (data_idx < MATRIX_SIZE) begin
                                    data_out_buffer[data_idx] <= data_out_array[i];
                                end
                            end
                        end
                        idx <= idx + NUM_PES;
                        if (idx + NUM_PES >= MATRIX_SIZE) begin
                            state <= DONE;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end
                
                DONE: begin
                    for (int i = 0; i < MATRIX_SIZE; i++) begin
                        data_out[i] <= data_out_buffer[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule