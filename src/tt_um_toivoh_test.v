`default_nettype none

/*
module raster_scan2 #( parameter X_BITS=10, Y_BITS=9 ) (
		input wire clk,
		input wire reset,
		input wire enable,

		input wire [X_BITS-1:0] x_vis, x_fp, x_sync, x_bp,
		input wire [Y_BITS-1:0] y_vis, y_fp, y_sync, y_bp,

		output wire active, hsync, vsync
	);

	localparam PHASE_VIS = 0;
	localparam PHASE_FP = 1;
	localparam PHASE_SYNC = 2;
	localparam PHASE_BP = 3;

	reg [1:0] x_phase, y_phase;
	reg [X_BITS-1:0] x;
	reg [Y_BITS-1:0] y;

	wire last_x_in_phase = x == 0;

	always @(posedge clk) begin
		if (reset) begin
			x_phase <= 0;
			y_phase <= 0;
			x <= 0;
			y <= 0;
		end else begin
			if enable

			end
		end
	end
endmodule
*/

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

module tilemap_renderer #( parameter RAMIF_WIDTH=4 ) (
		input wire clk,
		input wire reset,
		input wire enable,

		output [RAMIF_WIDTH-1:0] addr_bits,
		input [RAMIF_WIDTH-1:0] data_bits,

		output [1:0] pixel
	);

	localparam PHASE_IDS = 0;
	localparam PHASE_TILE0 = 1;
	localparam PHASE_TILE1 = 3;

	reg [3:0] pixel_pos; // 2-tile cycle
	reg [2:0] y; // TODO: increment
	reg [15:0] pixels; // 2 bits / pixel x 8 pixels
	reg [15:0] tile_ids;
	reg [15:0] tilemap_addr;

	wire [1:0] phase = pixel_pos[3:2];

	reg [15:0] addr; // = tilemap_addr;
	always @(*) begin
		case (phase)
			PHASE_IDS: addr = tilemap_addr;
			PHASE_TILE0: addr = {tile_ids[7:0], y};
			PHASE_TILE1: addr = {tile_ids[15:8], y};
			default: addr = 'X;
		endcase
	end

	// TODO: offset
	wire dest_tile_ids = (phase == PHASE_IDS);
	wire dest_pixels = (phase == PHASE_TILE0) | (phase == PHASE_TILE1);

	wire [3:0] dest_pos = RAMIF_WIDTH*pixel_pos;
	always @(posedge clk) begin
		if (reset) begin
			pixel_pos <= 0;
			pixels <= 0;
			tile_ids <= 0;
			tilemap_addr <= 0;
			y <= 0;
		end else if (enable) begin
			pixel_pos <= pixel_pos + 1;
			if (dest_tile_ids) tile_ids[addr_pos + RAMIF_WIDTH - 1 -: RAMIF_WIDTH] <= data_bits;
			if (dest_pixels) pixels[addr_pos + RAMIF_WIDTH - 1 -: RAMIF_WIDTH] <= data_bits;
			tilemap_addr <= tilemap_addr + (pixel_pos == 0);
		end
	end

	wire [3:0] addr_pos = RAMIF_WIDTH*pixel_pos;
	assign addr_bits = addr[addr_pos + RAMIF_WIDTH - 1 -: RAMIF_WIDTH];

	assign pixel = pixels[pixel_pos[2:0]]; // TODO: left to right or right to left?
endmodule



module tt_um_toivoh_test0 #( parameter LOG2_BYTES_IN = 4, X_BITS=11, Y_BITS=10, RAMIF_WIDTH=4 ) (
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
	assign uio_out = 0;

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
	//assign {x1, x_s, x_fp, x0} = cfg[X_BITS*4-1:0];
	//assign {y1, y_s, y_fp, y0} = cfg[(X_BITS+Y_BITS)*4-1:X_BITS*4];
	// Hardcoded VGA 640x480, X_BITS=11, Y_BITS=10:
	assign {x0, x_fp, x_s, x1} = {-11'd48, 11'd640, 11'd656, 11'd752};
	assign {y0, y_fp, y_s, y1} = {-10'd33, 10'd480, 10'd490, 10'd492};


	wire active, hsync, vsync;
	raster_scan #(.X_BITS(X_BITS), .Y_BITS(Y_BITS)) rs(
		.clk(clk), .reset(reset),
		.x0(x0), .x_fp(x_fp), .x_s(x_s), .x1(x1),
		.y0(y0), .y_fp(y_fp), .y_s(y_s), .y1(y1),

		.active(active), .hsync(hsync), .vsync(vsync)
	);

	wire [1:0] pixel;
	wire [RAMIF_WIDTH-1:0] addr_bits, data_bits;
	tilemap_renderer #(.RAMIF_WIDTH(RAMIF_WIDTH)) tr(
		.clk(clk), .reset(reset), .enable(1'b1),
		.addr_bits(addr_bits), .data_bits(data_bits),
		.pixel(pixel)
	);

	wire [1:0] pixel_out = active ? pixel : '0;

	//assign uo_out = {5'b0, vsync, hsync, active};
	assign uo_out = {addr_bits, hsync, vsync, pixel_out};
	assign data_bits = uio_in[7 -: RAMIF_WIDTH];
endmodule


module tt_um_toivoh_test #( parameter RAM_LOG2_CYCLES=2, RAM_PINS=4 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam RAM_CYCLES = 2**RAM_LOG2_CYCLES;

	wire reset = !rst_n;

	assign uio_oe = 0;
	assign uio_out = 0;

	reg [15:0] addr;
	reg [RAM_LOG2_CYCLES-1:0] counter;
	wire [RAM_LOG2_CYCLES:0] next_counter = counter + 1;
	wire counter_wrap = next_counter[RAM_LOG2_CYCLES];
	reg state;
	wire [RAM_PINS-1:0] addr_bits = state ? data_bits : addr[counter*RAM_PINS + RAM_PINS-1 -: RAM_PINS];

	wire [RAM_PINS-1:0] data_bits = ui_in[7 -: RAM_PINS];
	reg [15:0] data;

	always @(posedge clk) begin
		if (reset) begin
			counter <= 0;
			addr <= 0;
			state <= 0;
		end else begin
			counter <= next_counter[RAM_LOG2_CYCLES-1:0];
			addr <= addr + (counter_wrap && (state == 0));
			state <= state + counter_wrap;

			data[counter*RAM_PINS + RAM_PINS-1 -: RAM_PINS] <= data_bits;
		end
	end

	assign uo_out = {addr_bits, {(8-RAM_PINS){1'b0}}};
endmodule
