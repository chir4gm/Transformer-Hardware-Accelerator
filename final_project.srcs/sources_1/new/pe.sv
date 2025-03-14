module pe #(
    parameter DATA_WIDTH = 16,
    parameter FIXED_POINT = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [2:0] op_code,
    input  logic signed [DATA_WIDTH-1:0] data_in_a,
    input  logic signed [DATA_WIDTH-1:0] data_in_b,
    input  logic signed [DATA_WIDTH-1:0] acc_in,    // For accumulation
    output logic signed [DATA_WIDTH-1:0] data_out,
    output logic valid_out,
    output logic acc_valid
);
    // Operation codes
    localparam OP_MULT = 3'b000;    // Basic multiplication
    localparam OP_ACC  = 3'b001;    // Accumulate
    localparam OP_SCALE= 3'b010;    // Scale by constant (1/sqrt(d_k))
    localparam OP_SOFT = 3'b011;    // Softmax approximation
    localparam OP_PASS = 3'b100;    // Pass through

    // Internal registers
    logic signed [2*DATA_WIDTH-1:0] mult_result;
    logic signed [DATA_WIDTH-1:0] acc_reg;
    logic signed [DATA_WIDTH-1:0] stage1_reg;
    logic valid_stage1, valid_stage2;
    logic [2:0] op_code_reg;

    // Scaling constant (1/sqrt(16))
    localparam SCALE_FACTOR = 16'h0040; // 0.25 in fixed point

    assign valid_out = valid_stage2;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result <= '0;
            acc_reg <= '0;
            stage1_reg <= '0;
            data_out <= '0;
            valid_stage1 <= 1'b0;
            valid_stage2 <= 1'b0;
            acc_valid <= 1'b0;
            op_code_reg <= '0;
        end else begin
            // Stage 1: Input and Multiplication
            valid_stage1 <= valid_in;
            if (valid_in) begin
                case (op_code)
                    OP_MULT, OP_ACC: begin
                        mult_result <= data_in_a * data_in_b;
                    end
                    OP_SCALE: begin
                        mult_result <= data_in_a * SCALE_FACTOR;
                    end
                    default: begin
                        mult_result <= '0;
                    end
                endcase
                op_code_reg <= op_code;
            end

            // Stage 2: Operation and Output
            valid_stage2 <= valid_stage1;
            if (valid_stage1) begin
                case (op_code_reg)
                    OP_MULT: begin
                        data_out <= mult_result[DATA_WIDTH+FIXED_POINT-1:FIXED_POINT];
                        acc_valid <= 1'b0;
                    end
                    OP_ACC: begin
                        data_out <= acc_in + mult_result[DATA_WIDTH+FIXED_POINT-1:FIXED_POINT];  // Store current result
                        acc_valid <= 1'b1;
                    end
                    OP_SCALE: begin
                        data_out <= mult_result[DATA_WIDTH+FIXED_POINT-1:FIXED_POINT];
                        acc_valid <= 1'b0;
                    end
                    OP_SOFT: begin
                        // Simple ReLU-like operation for demonstration
                        data_out <= (data_in_a[DATA_WIDTH-1]) ? '0 : data_in_a;
                        acc_valid <= 1'b0;
                    end
                    OP_PASS: begin
                        data_out <= data_in_a;
                        acc_valid <= 1'b0;
                    end
                    default: begin
                        data_out <= '0;
                        acc_valid <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule