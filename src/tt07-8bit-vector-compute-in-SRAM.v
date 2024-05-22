`default_nettype none

module tt_um_8bit_vector_compute_in_SRAM (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    wire rst = !rst_n;

    // Use IO as I
    assign uio_oe  = 0;
    assign uio_out = 0;

    // output
    reg [7:0] data_out = s_adder_tree[7:0];
    assign uo_out = data_out;

    // inputs
    wire [1:0] op = ui_in[7:6];           // op code or control
    wire [5:0] address = ui_in[5:0];      // MAC unit address
    wire [7:0] data_in = uio_in[7:0];          // Data in for loading

    // MACs
    wire [7:0]  mac_in[0:7];
    reg         mac_en_wr_w[0:7];
    reg         mac_en_wr_a[0:7];
    wire [15:0] mac_out[0:7];

    // Assigning outside genvar, not sure why cocotb throws an error if inside
    assign mac_in[0] = data_in;
    assign mac_in[1] = data_in;
    assign mac_in[2] = data_in;
    assign mac_in[3] = data_in;
    assign mac_in[4] = data_in;
    assign mac_in[5] = data_in;
    assign mac_in[6] = data_in;
    assign mac_in[7] = data_in;

    // Instantiate 8 MAC modules using a generate block
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : mac_gen
            MAC u_mac (
                .clk(clk),
                .rst(rst),
                .in(mac_in[i]),
                .en_wr_w(mac_en_wr_w[i]),
                .en_wr_a(mac_en_wr_a[i]),
                .out(mac_out[i])
            );
        end
    endgenerate

    // Adder Tree Level 1
    wire [15:0] l1_0_s;
    wire        l1_0_c;
    wire [15:0] l1_1_s;
    wire        l1_1_c;
    wire [15:0] l1_2_s;
    wire        l1_2_c;
    wire [15:0] l1_3_s;
    wire        l1_3_c;

    cla #(16) adder_l1_0 (
            .a_in(mac_out[0]),
            .b_in(mac_out[1]),
            .c_in(1'b0),
            .s_out(l1_0_s),
            .c_out(l1_0_c)
        );

    cla #(16) adder_l1_1 (
            .a_in(mac_out[2]),
            .b_in(mac_out[3]),
            .c_in(1'b0),
            .s_out(l1_1_s),
            .c_out(l1_1_c)
        );

    cla #(16) adder_l1_2 (
            .a_in(mac_out[4]),
            .b_in(mac_out[5]),
            .c_in(1'b0),
            .s_out(l1_2_s),
            .c_out(l1_2_c)
        );

    cla #(16) adder_l1_3 (
            .a_in(mac_out[6]),
            .b_in(mac_out[7]),
            .c_in(1'b0),
            .s_out(l1_3_s),
            .c_out(l1_3_c)
        );


    // Adder Tree Level 2
    wire [16:0] l2_0_s;
    wire        l2_0_c;
    wire [16:0] l2_1_s;
    wire        l2_1_c;

    cla #(17) adder_l2_0 (
            .a_in({l1_0_c, l1_0_s}),
            .b_in({l1_1_c, l1_1_s}),
            .c_in(1'b0),
            .s_out(l2_0_s),
            .c_out(l2_0_c)
        );

    cla #(17) adder_l2_1 (
            .a_in({l1_2_c, l1_2_s}),
            .b_in({l1_3_c, l1_3_s}),
            .c_in(1'b0),
            .s_out(l2_1_s),
            .c_out(l2_1_c)
        );

    // Adder Tree Level 3
    wire [17:0] l3_0_s;
    wire        l3_0_c;

    cla #(18) adder_l3_0 (
        .a_in({l2_0_c, l2_0_s}),
        .b_in({l2_1_c, l2_1_s}),
        .c_in(1'b0),
        .s_out(l3_0_s),
        .c_out(l3_0_c)
    );

    wire [18:0] s_adder_tree =  {l3_0_c, l3_0_s};



    // Control & Op
    always @(*) begin
        // Default values
        integer j;
        for (j = 0; j < 8; j = j + 1) begin
            mac_en_wr_w[j] = 0;
            mac_en_wr_a[j] = 0;
        end

        case (op)
            2'b00: begin
                if (address < 8) begin
                    mac_en_wr_w[address] = 1;
                end
            end
            2'b01: begin
                if (address < 8) begin
                    mac_en_wr_a[address] = 1;
                end
            end
            default: begin
                // Do nothing for other op codes
            end
        endcase
    end

endmodule


// MAC -------------------------------------------------------------
module MAC #(
    parameter BIT_WIDTH = 8
)(
    input                           clk,
    input                           rst,
    input   wire  [BIT_WIDTH-1:0]   in,
    input   wire                    en_wr_w,
    input   wire                    en_wr_a,

    output  reg   [BIT_WIDTH*2-1:0] out
);

    reg [BIT_WIDTH-1:0] w;
    reg [BIT_WIDTH-1:0] a;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            w <= {BIT_WIDTH{1'b0}};
            a <= {BIT_WIDTH{1'b0}};
        end
        else if (en_wr_w) begin
            w <= in;
        end
        else if (en_wr_a) begin
            a <= in;
        end
    end

    always @(*) begin
        out = a * w;
    end


    endmodule


// Adder Carry Look ahead from https://github.com/Hammersamatom/cla
// must verify, it says it verfied till 32 bits
module cla #(
    parameter BITS = 16
)(
    input wire [BITS - 1:0] a_in,
    input wire [BITS - 1:0] b_in,
    input wire c_in,
    output wire [BITS - 1:0] s_out,
    output wire c_out
);
    // Propagate / Generate
    wire [BITS - 1:0] w_prop;
    assign w_prop[BITS - 1:0] = a_in[BITS - 1:0] ^ b_in[BITS - 1:0];

    wire [BITS - 1:0] w_gen;
    assign w_gen[BITS - 1:0] = a_in[BITS - 1:0] & b_in[BITS - 1:0];

    wire [BITS:0] w_carry;

    assign w_carry[0] = c_in; // Sets w_carry[0] = c_in

    // Carry Lookahead Unit
    genvar carryBitIndex;
    generate
        for (carryBitIndex = 1; carryBitIndex <= BITS; carryBitIndex = carryBitIndex + 1)
        begin
            wire [carryBitIndex:0] components;

            assign components[0] = w_gen[carryBitIndex - 1];

            genvar i;
            for (i = 1; i < carryBitIndex; i = i + 1)
            begin
                assign components[i] = w_gen[carryBitIndex - i - 1] & &w_prop[carryBitIndex - 1 : carryBitIndex - i];
            end
            assign components[carryBitIndex] = w_carry[0] & &w_prop[carryBitIndex - 1:0];


            assign w_carry[carryBitIndex] = |components;

        end
    endgenerate

    // Assigning outputs
    assign s_out[BITS - 1:0] = w_prop[BITS - 1:0] ^ w_carry[BITS - 1:0];
    assign c_out = w_carry[BITS];

    endmodule