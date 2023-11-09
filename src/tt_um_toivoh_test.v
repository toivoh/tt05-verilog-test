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
	wire [7:0] data_out;
	assign uo_out = data_out;

	assign data_out = ram[addr];
	always @(posedge clk) begin
		ram[addr] <= data_in;
	end

	/*
	wire [5:0] naddr = ~addr;
	wire [2:0] addrl = addr[2:0];
	wire [2:0] addrh = addr[5:3];
	wire [2:0] naddrl = naddr[2:0];
	wire [2:0] naddrh = naddr[5:3];

	wire [2:0] addr0 = naddrl & naddrh;
	wire [2:0] addr1 = naddrl &  addrh;
	wire [2:0] addr2 =  addrl & naddrh;
	wire [2:0] addr3 =  addrl &  addrh;

	wire [3:0] addr01 = {addr3[0], addr2[0], addr1[0], addr0[0]};
	wire [3:0] addr23 = {addr3[1], addr2[1], addr1[1], addr0[1]};
	wire [3:0] addr45 = {addr3[2], addr2[2], addr1[2], addr0[2]};

	wire [15:0] addr0123 = {4{addr01}} & {{4{addr23[3]}}, {4{addr23[2]}}, {4{addr23[1]}}, {4{addr23[0]}}};

	genvar i;
	generate
		for (i = 0; i < NUM_BYTES; i++) begin
			wire [5:0] index = i;
			wire active = addr0123[index[3:0]] & addr45[index[5:4]];
			always @(posedge clk) begin
				if (active) ram[i] <= data_in;
			end
			assign data_out = active ? ram[i] : 'Z;
		end
	endgenerate
	*/

endmodule
