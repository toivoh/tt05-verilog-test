`default_nettype none

module tt_um_toivoh_test (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam ADDR_BITS = 6;
	localparam NUM_BYTES = 48; //2**ADDR_BITS;

	assign uio_out = 0;
	assign uio_oe = 0;

	reg [7:0] ram[NUM_BYTES];

	wire [ADDR_BITS-1:0] addr = ui_in;
	wire [7:0] data_in = uio_in;
	wire [7:0] data_out = ram[addr];
	assign uo_out = data_out;

	always @(posedge clk) begin
		ram[addr] <= data_in;
	end
endmodule
