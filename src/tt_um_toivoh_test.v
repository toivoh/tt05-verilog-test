`default_nettype none

module Counter #( parameter PERIOD_BITS = 8, parameter LOG2_STEP = 0 ) (
		input wire clk,
		input wire reset,
		input wire [PERIOD_BITS-1:0] period,
		input wire enable,
		output wire trigger
	);

	reg [PERIOD_BITS-1:0] counter;
	wire [PERIOD_BITS-1:0] delta_counter;
	assign trigger = enable & !(|counter[PERIOD_BITS-1:LOG2_STEP]); // Trigger if decreasing by 1 << LOG2_STEP would wrap around.
	assign delta_counter = (trigger ? period : 0) - (1 << LOG2_STEP);

	always @(posedge clk) begin
		if (reset) begin
			counter <= 0;
		end else if (enable) begin
			counter <= counter + delta_counter;
		end
	end
endmodule

module tt_um_toivoh_test #( parameter DIVIDER_BITS=7, parameter OCT_BITS=3, parameter PERIOD_BITS = 10, parameter WAVE_BITS = 8 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
		output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
		input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
		output wire [7:0] uio_out,  // IOs: Bidirectional Output path
		output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // will go high when the design is enabled
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	wire reset = !rst_n;

	// Configuration input
	assign uio_oe = 0; // Let the bidirectional signals be inputs
	wire [7:0] cfg_in = uio_in;
	reg [15:0] cfg;
	wire [7:0] cfg_in_en = ui_in;


	// Octave divider
	reg [DIVIDER_BITS-1:0] oct_counter;
	wire [DIVIDER_BITS-1:0] next_oct_counter = oct_counter + 1;
	wire [DIVIDER_BITS:0] oct_enables;
	assign oct_enables[0] = 1;
	assign oct_enables[DIVIDER_BITS:1] = next_oct_counter & ~oct_counter; // Could optimize oct_enables[1] to just next_oct_counter[0]


	// Sawtooth
	wire [PERIOD_BITS-1:0] saw_period = {1'b1, cfg[PERIOD_BITS-2:0]};
	wire [OCT_BITS-1:0] oct = cfg[PERIOD_BITS-2+OCT_BITS -: OCT_BITS];
	wire saw_en = oct_enables[oct];
	wire saw_trigger;
	Counter #(.PERIOD_BITS(PERIOD_BITS), .LOG2_STEP(WAVE_BITS)) saw_counter(
		.clk(clk), .reset(reset), .period(saw_period), .enable(saw_en & ena), .trigger(saw_trigger)
	);
	reg [WAVE_BITS-1:0] saw;


	always @(posedge clk) begin
		if (reset) begin
			oct_counter <= 0;
			//cfg <= 0;
			cfg <= {3'd3, 9'd56};
			saw <= 0;
		end else begin
			if (cfg_in_en[0]) cfg[ 7:0] <= cfg_in;
			if (cfg_in_en[1]) cfg[15:7] <= cfg_in;

			oct_counter <= next_oct_counter;

			saw <= saw + saw_trigger;
		end
	end

	assign uo_out = saw;
endmodule
