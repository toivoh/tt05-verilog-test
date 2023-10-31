`default_nettype none

module tt_um_toivoh_test #( parameter LOG2_BYTES_IN = 3, parameter LOG2_BYTES_OUT = 2) (
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
	localparam BYTES_OUT = 1 << LOG2_BYTES_OUT;

	localparam BITS_OUT = 8*BYTES_OUT;

	assign uio_out = 0;
	assign uio_oe = 0;

	reg  [BYTES_IN*8-1:0]  input_data;
	wire [BYTES_OUT*8-1:0] result;
	reg  [BYTES_OUT*8-1:0] output_data;

	wire [7:0] data_in = ui_in;
	wire [LOG2_BYTES_IN-1:0]  sel_in  = uio_in[LOG2_BYTES_IN-1:0];
	wire [LOG2_BYTES_OUT-1:0] sel_out = uio_in[4+LOG2_BYTES_OUT-1:4];
	assign uo_out = output_data[7+sel_out*8 -: 8];

	wire [BYTES_IN*4-1:0] x = input_data[BYTES_IN*4-1:0];
	wire [BYTES_IN*4-1:0] y = input_data[BYTES_IN*8-1:BYTES_IN*4];

	//assign result = !(x&y); // NAND
	//assign result = x + y; // add
	//assign result = $signed(x) >>> y[4:0]; // barrel shifter
	//assign result = !(x&y[4:0]); // NAND / not for barrel shifter comparison
	//assign result = ena ? x : y; // mux
		//assign result = rst_n ? (ena ? x : y) : (ena ? {x[0], x[BYTES_IN*4-1:1]} : {y[0], y[BYTES_IN*4-1:1]}); // mux4

	// Ripple carry adder
	wire [BITS_OUT:0] c;
	assign c[0] = 0;

	wire [2:0] temp[BITS_OUT];
	genvar i;
	generate
		for (i=0; i < BITS_OUT; i++) begin
			//assign {c[i+1], result[i]} = x[i] + y[i] + c[i];
			//assign c[i+1] = x[i]&y[i] | c[i]&(x[i] | y[i]);
			//assign result[i] = c[i]&x[i]&y[i] | (c[i] | x[i] | y[i])&~c[i+1];

			assign temp[i] = {x[i], 1'b1} + {y[i], c[i]};
			assign {c[i+1], result[i]} = temp[i][2:1];
		end
	endgenerate

	always @(posedge clk) begin : main
		integer i;
		for (i = 0; i < BYTES_IN; i = i + 1) begin
			if (sel_in == i) input_data[i*8+7 -: 8] <= data_in;
		end
		output_data <= result;
	end
endmodule
