`default_nettype none
`timescale 1ns/1ps

// set RAM_ADDR_BITS <= ADDR_PINS*2**LOG2_CYCLES
module serial_ram #( parameter ADDR_PINS=4, DATA_PINS=4, LOG2_CYCLES=2, RAM_ADDR_BITS=12, DELAY=2) (
        input wire clk,
        input wire reset,
        input wire enable,

        input wire  [ADDR_PINS-1:0] addr_in,
        output wire [DATA_PINS-1:0] data_out
    );

    localparam CYCLES = 2**LOG2_CYCLES;

    localparam ADDR_BITS = ADDR_PINS*CYCLES;
    localparam DATA_BITS = DATA_PINS*CYCLES;

    reg [LOG2_CYCLES-1:0] counter;
    reg [ADDR_BITS-1:0] addr;
    reg [DATA_BITS-1:0] data;

    reg [DATA_BITS-1:0] ram[2**RAM_ADDR_BITS];

    reg [DATA_PINS*DELAY-1:0] sr;

    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
        end else if (enable) begin
            addr[ADDR_PINS*counter + ADDR_PINS-1 -: ADDR_PINS] <= addr_in;
            if (counter == 0) data <= ram[addr[RAM_ADDR_BITS-1:0]];
            else data <= data >> DATA_PINS;
            counter <= counter + 1;

            sr <= {data[DATA_PINS-1:0], sr[DATA_PINS*DELAY-1:DATA_PINS]};
        end
    end

    assign data_out = sr[DATA_PINS-1:0];
endmodule


// testbench is controlled by test.py
module tb #( parameter RAM_PINS=4, RAM_LOG2_CYCLES=2, RAM_ADDR_BITS=16, RAM_EXTRA_DELAY=3) ();

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    localparam DATA_PINS = RAM_PINS;
    localparam ADDR_PINS = RAM_PINS;

    // wire up the inputs and outputs
    reg  clk;
    reg  rst_n;
    reg  ena;

    //reg  [7:0] ui_in;
    reg  [7-DATA_PINS:0] ui_in;
    wire [DATA_PINS-1:0] data;
    wire [7:0] ui_in_full = {data, ui_in};

    reg  [7:0] uio_in;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_toivoh_test #(.RAM_LOG2_CYCLES(RAM_LOG2_CYCLES), .RAM_PINS(RAM_PINS)) dut (
    // include power ports for the Gate Level test
    `ifdef GL_TEST
        .VPWR( 1'b1),
        .VGND( 1'b0),
    `endif
        .ui_in      (ui_in_full),    // Dedicated inputs
        .uo_out     (uo_out),   // Dedicated outputs
        .uio_in     (uio_in),   // IOs: Input path
        .uio_out    (uio_out),  // IOs: Output path
        .uio_oe     (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena        (ena),      // enable - goes high when design is selected
        .clk        (clk),      // clock
        .rst_n      (rst_n)     // not reset
        );

    serial_ram #(.ADDR_PINS(RAM_PINS), .DATA_PINS(RAM_PINS), .LOG2_CYCLES(RAM_LOG2_CYCLES), .RAM_ADDR_BITS(RAM_ADDR_BITS), .DELAY(RAM_EXTRA_DELAY)) extram (
        .clk(clk), .reset(!rst_n), .enable(1'b1),
        .addr_in(uo_out[7 -: ADDR_PINS]), .data_out(data)
    );
endmodule
