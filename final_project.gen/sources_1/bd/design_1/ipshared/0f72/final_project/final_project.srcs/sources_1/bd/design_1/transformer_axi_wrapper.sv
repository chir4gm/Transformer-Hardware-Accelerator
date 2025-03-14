module transformer_axi_wrapper_v1_0_S00_AXI #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4
)(
    // AXI Interface
    input  wire                                 S_AXI_ACLK,
    input  wire                                 S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY
);

    // Local parameters
    localparam ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam OPT_MEM_ADDR_BITS = 1;

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1:0]  axi_awaddr;
    reg                           axi_awready;
    reg                           axi_wready;
    reg [1:0]                     axi_bresp;
    reg                           axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]  axi_araddr;
    reg                           axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0]  axi_rdata;
    reg [1:0]                     axi_rresp;
    reg                           axi_rvalid;

    // Example-specific design signals
    reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg0;
    reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg1;
    reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg2;
    reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg3;
    wire                          slv_reg_rden;
    wire                          slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0]  reg_data_out;
    reg                           aw_en;

    // Instance of transformer_encoder
    wire start = slv_reg0[0];
    wire [15:0] data_in_serial = slv_reg1[15:0];
    wire data_in_valid = slv_reg0[1];
    wire data_out_ready = slv_reg0[2];
    wire [15:0] data_out_serial;
    wire data_out_valid;
    wire data_in_ready;
    wire done;

    transformer_encoder encoder (
        .clk(S_AXI_ACLK),
        .rst_n(S_AXI_ARESETN),
        .start(start),
        .data_in_valid(data_in_valid),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .data_in_ready(data_in_ready),
        .data_in_serial(data_in_serial),
        .data_out_serial(data_out_serial),
        .done(done)
    );

    // I/O Connections assignments
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // Write address ready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Write address latching
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_awaddr <= 0;
        else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            axi_awaddr <= S_AXI_AWADDR;
    end

    // Write data ready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_wready <= 1'b0;
        else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en)
            axi_wready <= 1'b1;
        else
            axi_wready <= 1'b0;
    end

    // Write response generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b0;
            end else if (S_AXI_BREADY && axi_bvalid)
                axi_bvalid <= 1'b0;
        end
    end

    // Write to registers
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;
        end else if (slv_reg_wren) begin
            case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                2'b00: slv_reg0 <= S_AXI_WDATA;
                2'b01: slv_reg1 <= S_AXI_WDATA;
                2'b10: slv_reg2 <= S_AXI_WDATA;
                2'b11: slv_reg3 <= S_AXI_WDATA;
            endcase
        end
    end

    // Read address ready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr <= 32'b0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr <= S_AXI_ARADDR;
            end else
                axi_arready <= 1'b0;
        end
    end

    // Read data generation
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

    always @(*) begin
        case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
            2'b00: reg_data_out = {28'h0, data_in_ready, data_out_valid, done, start};
            2'b01: reg_data_out = {16'h0, data_out_serial};
            2'b10: reg_data_out = slv_reg2;
            2'b11: reg_data_out = slv_reg3;
            default: reg_data_out = 0;
        endcase
    end

    // Output register or memory read data
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 0;
            axi_rresp <= 0;
        end else begin
            if (slv_reg_rden) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0;
            end else if (axi_rvalid && S_AXI_RREADY)
                axi_rvalid <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_rdata <= 0;
        else if (slv_reg_rden)
            axi_rdata <= reg_data_out;
    end

endmodule