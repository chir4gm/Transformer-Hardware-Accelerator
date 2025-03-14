module top (
    // System Clock (125 MHz)
    input  logic        sysclk,
    
    // Control pins
    input  logic        rpio_02_r,  // Reset
    input  logic        rpio_03_r,  // Start
    input  logic        rpio_04_r,  // data_in_valid
    input  logic        rpio_05_r,  // data_out_ready
    
    // Bidirectional data pins
    inout  logic [15:0] rpio_data   // Map to rpio_06_r through rpio_21_r
);

    // Parameters from transformer_encoder
    localparam DATA_WIDTH = 16;
    localparam MATRIX_SIZE = 16;
    localparam NUM_PES = 4;
    localparam FIXED_POINT = 8;

    // Internal signals
    logic rst_n;
    logic start;
    logic data_in_valid;
    logic data_out_valid;
    logic data_out_ready;
    logic data_in_ready;
    logic [DATA_WIDTH-1:0] data_in_serial;
    logic [DATA_WIDTH-1:0] data_out_serial;
    logic done;

    // Control signal assignments
    assign rst_n = ~rpio_02_r;          // Active low reset
    assign start = rpio_03_r;           // Start signal
    assign data_in_valid = rpio_04_r;   // Input valid signal
    assign data_out_ready = rpio_05_r;  // Output ready signal

    // Bidirectional data handling
    assign data_in_serial = rpio_data;  // Read input from GPIO pins
    
    // Tristate buffer for bidirectional data
    // When data_out_valid is high, drive the outputs
    // Otherwise, set to high impedance
    generate
        for (genvar i = 0; i < DATA_WIDTH; i++) begin : gen_tristate
            assign rpio_data[i] = data_out_valid ? data_out_serial[i] : 1'bz;
        end
    endgenerate

    // Instantiate transformer_encoder
    transformer_encoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) encoder_inst (
        .clk(sysclk),
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

endmodule