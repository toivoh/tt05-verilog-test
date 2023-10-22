import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test(dut):
	dut._log.info("start")
	clock = Clock(dut.clk, 2, units="us")
	cocotb.start_soon(clock.start())

	# reset
	dut._log.info("reset")
	dut.rst_n.value = 0
	# set the compare value
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1

	# enable
	dut.ena.value = 1

	period = (512 + 56) << 3;

	with open("tb-data.txt", "w") as file:
		file.write("data = [")
		for i in range(2*period):
			file.write(str(0 + dut.dut.oct_counter.value) + " ")
			file.write(str(0 + dut.dut.saw_counter.counter.value) + " ")
			file.write(str(0 + dut.dut.saw.value) + " ")
			file.write(";")
			await ClockCycles(dut.clk, 1)
		file.write("]")
