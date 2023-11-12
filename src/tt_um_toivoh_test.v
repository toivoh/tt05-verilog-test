`default_nettype none

module raster_scan #( parameter X_BITS=11, Y_BITS=10 ) (
		input wire clk,
		input wire reset,

		// Assume visible area starts at zero
		input wire signed [X_BITS-1:0] x0, x_fp, x_s, x1,
		input wire signed [Y_BITS-1:0] y0, y_fp, y_s, y1,

		output wire active, hsync, vsync
	);

	reg signed [X_BITS-1:0] x;
	reg signed [Y_BITS-1:0] y;

	wire last_x = (x == x1);
	wire signed [X_BITS-1:0] next_x = last_x ? x0 : x + 1;
	wire last_y = (y == y1);
	wire signed [Y_BITS-1:0] next_y = last_y ? y0 : y + 1;

	wire x_active = (x >= 0) && (x < x_fp);
	wire y_active = (y >= 0) && (y < y_fp);
	assign active = x_active && y_active;

	assign hsync = x >= x_s;
	assign vsync = y >= y_s;

	always @(posedge clk) begin
		if (reset) begin
			x <= 0;
			y <= 0;
		end else begin
			x <= next_x;
			if (last_x) y <= next_y;
		end
	end
endmodule


module tt_um_toivoh_test #( parameter LOG2_BYTES_IN = 4, X_BITS=11, Y_BITS=10 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam BYTES_IN = 1 << LOG2_BYTES_IN;

	wire reset = !rst_n;

	assign uio_oe = 0;

	reg  [BYTES_IN*8-1:0] cfg;
	wire [7:0] data_in = ui_in;
	wire [LOG2_BYTES_IN-1:0] sel_in = uio_in[LOG2_BYTES_IN-1:0];

	always @(posedge clk) begin
		integer i;
		for (i = 0; i < BYTES_IN; i = i + 1) begin
			if (sel_in == i) cfg[i*8+7 -: 8] <= data_in;
		end
	end

	wire [X_BITS-1:0] x0, x_fp, x_s, x1;
	wire [Y_BITS-1:0] y0, y_fp, y_s, y1;
	assign {x1, x_s, x_fp, x0} = cfg[X_BITS*4-1:0];
	assign {y1, y_s, y_fp, y0} = cfg[(X_BITS+Y_BITS)*4-1:X_BITS*4];

	wire active, hsync, vsync;
	raster_scan #(.X_BITS(X_BITS), .Y_BITS(Y_BITS)) rs(
		.clk(clk), .reset(reset),
		.x0(x0), .x_fp(x_fp), .x_s(x_s), .x1(x1),
		.y0(y0), .y_fp(y_fp), .y_s(y_s), .y1(y1),

		.active(active), .hsync(hsync), .vsync(vsync)
	);

	assign uio_out = {5'b0, vsync, hsync, active};
endmodule
