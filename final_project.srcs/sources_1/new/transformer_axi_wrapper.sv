module transformer_axi_wrapper #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,
    parameter NUM_PES = 4,
    parameter FIXED_POINT = 8
)(
    // AXI-Lite interface
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    // Write address channel
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    // Write data channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    // Write response channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    // Read address channel
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    // Read data channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

    // Register map
    localparam CTRL_REG      = 4'h0;  // Control register (start bit, etc)
    localparam STATUS_REG    = 4'h4;  // Status register (done bit, etc)
    localparam DATA_IN_REG   = 4'h8;  // Data input register
    localparam DATA_OUT_REG  = 4'hC;  // Data output register

    // Internal registers
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] data_in_reg;
    wire [31:0] data_out_reg;

    // Control bits
    wire start = ctrl_reg[0];
    wire reset_n = !ctrl_reg[1];

    // Status bits
    wire done;
    wire data_in_ready;
    wire data_out_valid;

    // Processor interface signals
    wire [DATA_WIDTH-1:0] data_in_serial;
    wire [DATA_WIDTH-1:0] data_out_serial;
    
    // Instance of your processor
    transformer_encoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .MATRIX_SIZE(MATRIX_SIZE),
        .NUM_PES(NUM_PES),
        .FIXED_POINT(FIXED_POINT)
    ) processor_inst (
        .clk(s_axi_aclk),
        .rst_n(reset_n & s_axi_aresetn),
        .start(start),
        .data_in_valid(s_axi_wvalid && s_axi_awaddr[3:0] == DATA_IN_REG),
        .data_out_valid(data_out_valid),
        .data_out_ready(1'b1),  // Always ready to output
        .data_in_ready(data_in_ready),
        .data_in_serial(data_in_reg[DATA_WIDTH-1:0]),
        .data_out_serial(data_out_serial),
        .done(done)
    );

    // AXI-Lite write logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            ctrl_reg <= 32'h0;
            data_in_reg <= 32'h0;
        end else begin
            if (s_axi_wvalid && s_axi_awvalid) begin
                case (s_axi_awaddr[3:0])
                    CTRL_REG: ctrl_reg <= s_axi_wdata;
                    DATA_IN_REG: data_in_reg <= s_axi_wdata;
                endcase
            end
        end
    end

    // Status register
    assign status_reg = {28'h0, data_out_valid, data_in_ready, done, 1'b0};
    
    // Data output register
    assign data_out_reg = {{(32-DATA_WIDTH){1'b0}}, data_out_serial};

    // AXI-Lite read logic
    reg [31:0] read_data;
    always @(*) begin
        case (s_axi_araddr[3:0])
            CTRL_REG: read_data = ctrl_reg;
            STATUS_REG: read_data = status_reg;
            DATA_OUT_REG: read_data = data_out_reg;
            default: read_data = 32'h0;
        endcase
    end

    // AXI-Lite interface assignments
    assign s_axi_awready = 1'b1;  // Always ready to accept write address
    assign s_axi_wready = 1'b1;   // Always ready to accept write data
    assign s_axi_bresp = 2'b00;   // Always OK response
    assign s_axi_bvalid = s_axi_wvalid && s_axi_awvalid;
    assign s_axi_arready = 1'b1;  // Always ready to accept read address
    assign s_axi_rdata = read_data;
    assign s_axi_rresp = 2'b00;   // Always OK response
    assign s_axi_rvalid = s_axi_arvalid;

endmodule