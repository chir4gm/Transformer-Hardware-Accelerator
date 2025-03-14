module top (
    // PS DDR Interface
    inout  logic [14:0] DDR_addr,
    inout  logic [2:0]  DDR_ba,
    inout  logic        DDR_cas_n,
    inout  logic        DDR_ck_n,
    inout  logic        DDR_ck_p,
    inout  logic        DDR_cke,
    inout  logic        DDR_cs_n,
    inout  logic [3:0]  DDR_dm,
    inout  logic [31:0] DDR_dq,
    inout  logic [3:0]  DDR_dqs_n,
    inout  logic [3:0]  DDR_dqs_p,
    inout  logic        DDR_odt,
    inout  logic        DDR_ras_n,
    inout  logic        DDR_reset_n,
    inout  logic        DDR_we_n,
    
    // PS Fixed IO
    inout  logic        FIXED_IO_ddr_vrn,
    inout  logic        FIXED_IO_ddr_vrp,
    inout  logic [53:0] FIXED_IO_mio,
    inout  logic        FIXED_IO_ps_clk,
    inout  logic        FIXED_IO_ps_porb,
    inout  logic        FIXED_IO_ps_srstb,
    
    // System Clock
    input  logic        sysclk,
    
    // Board I/O
    input  logic [1:0]  sw,
    input  logic [3:0]  btn,
    output logic [3:0]  led,
    
    // RGB LEDs
    output logic        led4_b,
    output logic        led4_g,
    output logic        led4_r,
    output logic        led5_b,
    output logic        led5_g,
    output logic        led5_r
);

    // Instance of the block design wrapper
    design_1_wrapper design_1_wrapper_i (
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
  //  .FIXED_IO_mio(sw),
     //   .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_clk(sysclk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb)
    );

    // LED control logic
    always_ff @(posedge sysclk) begin
        // Connect buttons to LEDs
        led <= btn;
        
        // RGB LED control
        led4_r <= sw[0];
        led4_g <= sw[1];
        led4_b <= sw[0] & sw[1];
        
        led5_r <= ~sw[0];
        led5_g <= ~sw[1];
        led5_b <= ~(sw[0] & sw[1]);
    end

endmodule