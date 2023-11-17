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
		input wire enable,

		// Assume visible area starts at zero
		input wire signed [X_BITS-1:0] x0, x_fp, x_s, x1,
		input wire signed [Y_BITS-1:0] y0, y_fp, y_s, y1,

		output wire active, hsync, vsync,

		output reg signed [X_BITS-1:0] x,
		output reg signed [Y_BITS-1:0] y
	);

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
		end else if (enable) begin
			x <= next_x;
			if (last_x) y <= next_y;
		end
	end
endmodule

module tilemap_renderer0 #( parameter RAMIF_WIDTH=4 ) (
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
		.clk(clk), .reset(reset), .enable(1'b1),
		.x0(x0), .x_fp(x_fp), .x_s(x_s), .x1(x1),
		.y0(y0), .y_fp(y_fp), .y_s(y_s), .y1(y1),

		.active(active), .hsync(hsync), .vsync(vsync)
	);

	wire [1:0] pixel;
	wire [RAMIF_WIDTH-1:0] addr_bits, data_bits;
	tilemap_renderer0 #(.RAMIF_WIDTH(RAMIF_WIDTH)) tr(
		.clk(clk), .reset(reset), .enable(1'b1),
		.addr_bits(addr_bits), .data_bits(data_bits),
		.pixel(pixel)
	);

	wire [1:0] pixel_out = active ? pixel : '0;

	//assign uo_out = {5'b0, vsync, hsync, active};
	assign uo_out = {addr_bits, hsync, vsync, pixel_out};
	assign data_bits = uio_in[7 -: RAMIF_WIDTH];
endmodule


// Assumes RAM_EXTRA_DELAY = 7
// One tilemap, 4 bpp RAM interface, 1 cycle/pixel
module tt_um_toivoh_test_4bpp #( parameter RAM_LOG2_CYCLES=2, RAM_PINS=4 ) (
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

// Chained read-ahead of one tile map based on transaction delay
// Assumes RAM_EXTRA_DELAY = RAM_LOG2_CYCLES*(TRANS_DELAY - 1) - 1? E.g. 3 nominally
module tt_um_toivoh_test_16bpp #( parameter RAM_LOG2_CYCLES=2, RAM_PINS=4, TRANS_DELAY=2 ) (
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
	localparam TRANS_COUNTER_BITS = 3;
	localparam COUNTER_BITS = TRANS_COUNTER_BITS + RAM_LOG2_CYCLES; // 8 pixels, 4 subpixels. 4 subtransactions

	localparam PIXELS_PER_TILE = 8;
	localparam COLOR_BITS = 2;

	wire reset = !rst_n;

	assign uio_oe = 0;
	assign uio_out = 0;

	reg [15:0] addr;

	reg [COUNTER_BITS-1:0] counter;
	wire [COUNTER_BITS:0] next_counter = counter + 1;
	wire counter_wrap = next_counter[COUNTER_BITS];

	wire [RAM_LOG2_CYCLES-1:0] subtrans_counter = counter[RAM_LOG2_CYCLES-1:0];
	wire [TRANS_COUNTER_BITS-1:0] trans_counter = counter[COUNTER_BITS-1:RAM_LOG2_CYCLES];
	wire [TRANS_COUNTER_BITS-1:0] pixel_counter = trans_counter; // Assume 1 transaction per pixel

	// Timed to feed do_tile_addr
	wire do_tilemap_addr = (trans_counter == (-2*TRANS_DELAY & (2**TRANS_COUNTER_BITS - 1)));
	// Timed to feed through data bits as address bits, make pixels arrive at trans_counter = 0
	wire do_tile_addr = (trans_counter == (-1*TRANS_DELAY & (2**TRANS_COUNTER_BITS - 1)));
	wire [RAM_PINS-1:0] addr_bits = do_tilemap_addr ? addr[subtrans_counter*RAM_PINS + RAM_PINS-1 -: RAM_PINS] : do_tile_addr ? data_bits : 'X;

	wire [RAM_PINS-1:0] data_bits = ui_in[7 -: RAM_PINS];
	reg [PIXELS_PER_TILE*COLOR_BITS-1:0] pixels;
	reg [COLOR_BITS-1:0] pixel_out;

	always @(posedge clk) begin
		if (reset) begin
			counter <= 0;
			addr <= 0;
		end else begin
			counter <= next_counter[COUNTER_BITS-1:0];
			addr <= addr + counter_wrap;

			if (trans_counter == 0) pixels[subtrans_counter*RAM_PINS + RAM_PINS-1 -: RAM_PINS] <= data_bits;

			if (subtrans_counter == RAM_CYCLES-1) pixel_out <= pixels[pixel_counter*COLOR_BITS + COLOR_BITS-1 -: COLOR_BITS];
		end
	end

	assign uo_out = {addr_bits, {(8-2-RAM_PINS){1'b0}}, pixel_out};
endmodule

/*
module tilemap_renderer_np #( parameter ADDR_PINS=4, DATA_PINS = 4, RAM_LOG2_CYCLES=2, TRANS_DELAY=2, X_BITS=9, Y_BITS=8, TMAP_X_BITS=6, TMAP_Y_BITS=5, LOG2_TILESIZE=3, NUM_PLANES=2, COLOR_BITS=2 ) (
		input wire clk,
		input wire reset,

		output wire [ADDR_PINS-1:0] addr_bits,
		input wire [DATA_PINS-1:0] data_bits,

		input wire [RAM_LOG2_CYCLES-1:0] subtrans_counter, // Assume one transaction per pixel
		input wire [X_BITS-1:0] x,
		input wire [Y_BITS-1:0] y,

		input wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] tilemap_addr[NUM_PLANES],
		input wire [LOG2_TILESIZE-1:0] x_offset[NUM_PLANES],
		input wire [LOG2_TILESIZE-1:0] y_offset[NUM_PLANES],

		output [COLOR_BITS*NUM_PLANES-1:0] pixel
	);

	localparam CLOG2_NUM_PLANES = $clog2(NUM_PLANES);
	localparam PLANE_ID_BITS = CLOG2_NUM_PLANES; //$max(1, CLOG2_NUM_PLANES);
	localparam TILESIZE = 2**LOG2_TILESIZE;
	localparam RAM_CYCLES = 2**RAM_LOG2_CYCLES;

	genvar i;

	wire [LOG2_TILESIZE-1:0] trans_counter = x[LOG2_TILESIZE-1:0];

	wire [PLANE_ID_BITS-1:0] plane = x[PLANE_ID_BITS-1:0];

	// Do we need separate adders for the planes? How to extract the correct bit position otherwise?
	wire [LOG2_TILESIZE-1:0] tile_x[NUM_PLANES];
	generate
		for (i = 0; i < NUM_PLANES; i++) begin
			assign tile_x[i] = x[LOG2_TILESIZE-1:0] + x_offset[i];
		end
	endgenerate

	// TODO: How to take handle lowest x_offset bits that get masked out?
	wire [LOG2_TILESIZE-1:0] plane_counter = tile_x[plane] & ~(2**CLOG2_NUM_PLANES - 1);
	wire do_tilemap_addr   = (plane_counter == (-2*TRANS_DELAY & (2**LOG2_TILESIZE - 1)));
	wire do_tile_addr      = (plane_counter == (  -TRANS_DELAY & (2**LOG2_TILESIZE - 1)));
	wire store_tile_pixels = (plane_counter == (  -TRANS_DELAY & (2**LOG2_TILESIZE - 1)));

	wire [TMAP_X_BITS-1:0] tx = tilemap_addr[plane][TMAP_X_BITS-1:0] + x[X_BITS-1:LOG2_TILESIZE];
	wire [TMAP_Y_BITS-1:0] ty = tilemap_addr[plane][TMAP_X_BITS+TMAP_Y_BITS-1 -: TMAP_Y_BITS] + y[Y_BITS-1:LOG2_TILESIZE];
	wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] addr = {ty, tx};

	assign addr_bits = do_tilemap_addr ? addr[subtrans_counter*ADDR_PINS + ADDR_PINS-1 -: ADDR_PINS] : do_tile_addr ? data_bits : 'X;

	reg [TILESIZE*COLOR_BITS-1:0] pixels[NUM_PLANES];
	reg [COLOR_BITS*NUM_PLANES-1:0] pixel_out;

	always @(posedge clk) begin
		if (reset) begin
		end else begin
		end

		if (store_tile_pixels) pixels[plane][subtrans_counter*DATA_PINS + DATA_PINS-1 -: DATA_PINS] <= data_bits;

		if (subtrans_counter == RAM_CYCLES-1) begin
			for (int i = 0; i < NUM_PLANES; i++) begin
				pixel_out[(i+1)*COLOR_BITS-1 -: COLOR_BITS] <= pixels[i][tile_x[i]*COLOR_BITS + COLOR_BITS-1 -: COLOR_BITS];
			end
		end
	end

	assign pixel = pixel_out;
endmodule

// N planes
module tt_um_toivoh_test_np #( parameter CFG_ADDR_BITS = 6, X_BITS=11, Y_BITS=10, RAM_PINS=4, NUM_PLANES=2, RAM_LOG2_CYCLES=2, TMAP_X_BITS=6, TMAP_Y_BITS=5, LOG2_TILESIZE=3 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam ADDR_PINS = RAM_PINS;
	localparam DATA_PINS = RAM_PINS;

	wire reset = !rst_n;

	wire [ADDR_PINS-1:0] addr_bits;
	wire active, hsync, vsync;
	wire [3:0] pixel_out;

	wire [DATA_PINS-1:0] data_bits = ui_in[7 -: DATA_PINS];
	//assign uo_out = {addr_bits, {(8-RAM_PINS){1'b0}}};
	assign uo_out = {addr_bits, pixel_out[7-RAM_PINS:0]};
	assign uio_oe = 8'b11100000;
	assign uio_out = {active, hsync, vsync, 5'b0};

	// TODO: better cfg interface?
	reg  [2**CFG_ADDR_BITS-1:0] cfg;
	wire cfg_in = ui_in;
	wire [CFG_ADDR_BITS-1:0] cfg_addr_in = {ui_in[CFG_ADDR_BITS-1-4:0], uio_in[4:0]};

	always @(posedge clk) begin
		cfg[cfg_addr_in] <= cfg;
	end

	wire [X_BITS-1:0] x0, x_fp, x_s, x1;
	wire [Y_BITS-1:0] y0, y_fp, y_s, y1;
	// Hardcoded VGA 640x480, X_BITS=11, Y_BITS=10:
	assign {x0, x_fp, x_s, x1} = {-11'd48, 11'd640, 11'd656, 11'd752};
	assign {y0, y_fp, y_s, y1} = {-10'd33, 10'd480, 10'd490, 10'd492};

	reg new_pixel;
	always @(posedge clk) begin
		if (reset) new_pixel <= 0;
		else new_pixel <= !new_pixel;
	end

	wire [X_BITS-1:0] x;
	wire [Y_BITS-1:0] y;
	raster_scan #(.X_BITS(X_BITS), .Y_BITS(Y_BITS)) rs(
		.clk(clk), .reset(reset), .enable(new_pixel),
		.x0(x0), .x_fp(x_fp), .x_s(x_s), .x1(x1),
		.y0(y0), .y_fp(y_fp), .y_s(y_s), .y1(y1),

		.active(active), .hsync(hsync), .vsync(vsync)
	);

	localparam CFG_BITS_PER_PLANE = TMAP_X_BITS+TMAP_Y_BITS+LOG2_TILESIZE*2;
	wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] tilemap_addr[NUM_PLANES];
	wire [LOG2_TILESIZE-1:0] x_offset[NUM_PLANES];
	wire [LOG2_TILESIZE-1:0] y_offset[NUM_PLANES];
	genvar i;
	generate
		for (i = 0; i < NUM_PLANES; i++) begin
			wire [CFG_BITS_PER_PLANE-1:0] cfg_i = cfg[(i+1)*CFG_BITS_PER_PLANE-1 -: CFG_BITS_PER_PLANE];
			assign {tilemap_addr[i], x_offset[i], y_offset[i]} = cfg_i;
		end
	endgenerate

	tilemap_renderer_np #( .ADDR_PINS(ADDR_PINS), .DATA_PINS(DATA_PINS), .TMAP_X_BITS(TMAP_X_BITS), .TMAP_Y_BITS(TMAP_Y_BITS), .LOG2_TILESIZE(LOG2_TILESIZE) ) renderer(
		.clk(clk), .reset(reset),
		.addr_bits(addr_bits), .data_bits(data_bits),
		.subtrans_counter({x[0], new_pixel}), .x(x[9:1]), .y(y[7:0]), // don't double pixels along y direction for now
		.tilemap_addr(tilemap_addr), .x_offset(x_offset), .y_offset(y_offset),
		.pixel(pixel_out)
	);
endmodule
*/

module tilemap_renderer_2p #( parameter ADDR_PINS=4, DATA_PINS = 4, RAM_LOG2_CYCLES=2, TRANS_DELAY=2, X_BITS=9, Y_BITS=8, TMAP_X_BITS=6, TMAP_Y_BITS=5, LOG2_TILESIZE=3, COLOR_BITS=2 ) (
		input wire clk,
		input wire reset,

		output wire [ADDR_PINS-1:0] addr_bits,
		input wire [DATA_PINS-1:0] data_bits,

		input wire [RAM_LOG2_CYCLES-1:0] subtrans_counter, // Assume one transaction per pixel
		input wire [X_BITS-1:0] x,
		input wire [Y_BITS-1:0] y,

		input wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] tilemap_addr0, tilemap_addr1,
		input wire [LOG2_TILESIZE-1:0] x_offset0, x_offset1,
		input wire [LOG2_TILESIZE-1:0] y_offset0, y_offset1,

		output [2*COLOR_BITS-1:0] pixel // output both planes for now
	);

	localparam TILESIZE = 2**LOG2_TILESIZE;
	localparam RAM_CYCLES = 2**RAM_LOG2_CYCLES;


	wire plane = x[0];

	// Do we actually need separate adders for the planes? How to extract the correct bit position otherwise?
	wire [LOG2_TILESIZE-1:0] tile_x0 = x[LOG2_TILESIZE-1:0] + x_offset0;
	wire [LOG2_TILESIZE-1:0] tile_x1 = x[LOG2_TILESIZE-1:0] + x_offset1;
	wire [LOG2_TILESIZE-1:0] tile_x = plane == 0 ? tile_x0 : tile_x1;

	// TODO: How to take handle lowest x_offset bits that get masked out?
	wire [LOG2_TILESIZE-1:0] plane_counter = tile_x & ~1;
	wire do_tilemap_addr   = (plane_counter == (-2*TRANS_DELAY & (2**LOG2_TILESIZE - 1)));
	wire do_tile_addr      = (plane_counter == (  -TRANS_DELAY & (2**LOG2_TILESIZE - 1)));
	wire store_tile_pixels = (plane_counter == (  -TRANS_DELAY & (2**LOG2_TILESIZE - 1)));

	wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] tilemap_addr = plane == 0 ? tilemap_addr0 : tilemap_addr1;
	wire [TMAP_X_BITS-1:0] tx = tilemap_addr[TMAP_X_BITS-1:0] + x[X_BITS-1:LOG2_TILESIZE];
	wire [TMAP_Y_BITS-1:0] ty = tilemap_addr[TMAP_X_BITS+TMAP_Y_BITS-1 -: TMAP_Y_BITS] + y[Y_BITS-1:LOG2_TILESIZE];
	wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] addr = {ty, tx};

	assign addr_bits = do_tilemap_addr ? addr[subtrans_counter*ADDR_PINS + ADDR_PINS-1 -: ADDR_PINS] : do_tile_addr ? data_bits : 'X;

	reg [TILESIZE*COLOR_BITS-1:0] pixels0, pixels1;
	reg [2*COLOR_BITS-1:0] pixel_out;

	always @(posedge clk) begin
		if (reset) begin
		end else begin
		end

		if (store_tile_pixels) begin
			if (plane == 0) pixels0[subtrans_counter*DATA_PINS + DATA_PINS-1 -: DATA_PINS] <= data_bits;
			else            pixels1[subtrans_counter*DATA_PINS + DATA_PINS-1 -: DATA_PINS] <= data_bits;
		end

		if (subtrans_counter == RAM_CYCLES-1) begin
			pixel_out[  COLOR_BITS-1 -: COLOR_BITS] <= pixels0[tile_x0*COLOR_BITS + COLOR_BITS-1 -: COLOR_BITS];
			pixel_out[2*COLOR_BITS-1 -: COLOR_BITS] <= pixels1[tile_x1*COLOR_BITS + COLOR_BITS-1 -: COLOR_BITS];
		end
	end

	assign pixel = pixel_out;
endmodule


// 2 planes
module tt_um_toivoh_test #( parameter CFG_ADDR_BITS = 6, X_BITS=11, Y_BITS=10, RAM_PINS=4, RAM_LOG2_CYCLES=2, TMAP_X_BITS=6, TMAP_Y_BITS=5, LOG2_TILESIZE=3 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	localparam ADDR_PINS = RAM_PINS;
	localparam DATA_PINS = RAM_PINS;

	wire reset = !rst_n;

	wire [ADDR_PINS-1:0] addr_bits;
	wire active, hsync, vsync;
	wire [3:0] pixel_out;

	wire [DATA_PINS-1:0] data_bits = ui_in[7 -: DATA_PINS];
	//assign uo_out = {addr_bits, {(8-RAM_PINS){1'b0}}};
	assign uo_out = {addr_bits, pixel_out[7-RAM_PINS:0]};
	assign uio_oe = 8'b11100000;
	assign uio_out = {active, hsync, vsync, 5'b0};

	// TODO: better cfg interface?
	reg  [2**CFG_ADDR_BITS-1:0] cfg;
	wire cfg_in = ui_in;
	wire [CFG_ADDR_BITS-1:0] cfg_addr_in = {ui_in[CFG_ADDR_BITS-1-4:0], uio_in[4:0]};

	always @(posedge clk) begin
		cfg[cfg_addr_in] <= cfg;
	end

	wire [X_BITS-1:0] x0, x_fp, x_s, x1;
	wire [Y_BITS-1:0] y0, y_fp, y_s, y1;
	// Hardcoded VGA 640x480, X_BITS=11, Y_BITS=10:
	assign {x0, x_fp, x_s, x1} = {-11'd48, 11'd640, 11'd656, 11'd752};
	assign {y0, y_fp, y_s, y1} = {-10'd33, 10'd480, 10'd490, 10'd492};

	reg new_pixel;
	always @(posedge clk) begin
		if (reset) new_pixel <= 0;
		else new_pixel <= !new_pixel;
	end

	wire [X_BITS-1:0] x;
	wire [Y_BITS-1:0] y;
	raster_scan #(.X_BITS(X_BITS), .Y_BITS(Y_BITS)) rs(
		.clk(clk), .reset(reset), .enable(new_pixel),
		.x0(x0), .x_fp(x_fp), .x_s(x_s), .x1(x1),
		.y0(y0), .y_fp(y_fp), .y_s(y_s), .y1(y1),

		.active(active), .hsync(hsync), .vsync(vsync),
		.x(x), .y(y)
	);

	localparam CFG_BITS_PER_PLANE = TMAP_X_BITS+TMAP_Y_BITS+LOG2_TILESIZE*2;
	wire [TMAP_X_BITS+TMAP_Y_BITS-1:0] tilemap_addr0, tilemap_addr1;
	wire [LOG2_TILESIZE-1:0] x_offset0, x_offset1;
	wire [LOG2_TILESIZE-1:0] y_offset0, y_offset1;

	wire [CFG_BITS_PER_PLANE-1:0] cfg0 = cfg[  CFG_BITS_PER_PLANE-1 -: CFG_BITS_PER_PLANE];
	wire [CFG_BITS_PER_PLANE-1:0] cfg1 = cfg[2*CFG_BITS_PER_PLANE-1 -: CFG_BITS_PER_PLANE];
	assign {tilemap_addr0, x_offset0, y_offset0} = cfg0;
	assign {tilemap_addr1, x_offset1, y_offset1} = cfg1;

	tilemap_renderer_2p #( .ADDR_PINS(ADDR_PINS), .DATA_PINS(DATA_PINS), .TMAP_X_BITS(TMAP_X_BITS), .TMAP_Y_BITS(TMAP_Y_BITS), .LOG2_TILESIZE(LOG2_TILESIZE) ) renderer(
		.clk(clk), .reset(reset),
		.addr_bits(addr_bits), .data_bits(data_bits),
		.subtrans_counter({x[0], new_pixel}), .x(x[9:1]), .y(y[7:0]), // don't double pixels along y direction for now
		.tilemap_addr0(tilemap_addr0), .x_offset0(x_offset0), .y_offset0(y_offset0),
		.tilemap_addr1(tilemap_addr1), .x_offset1(x_offset1), .y_offset1(y_offset1),
		.pixel(pixel_out)
	);
endmodule
