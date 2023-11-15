import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test(dut):
	dut._log.info("start")
	clock = Clock(dut.clk, 2, units="us")
	cocotb.start_soon(clock.start())

	preserved = True
	try:
		data = dut.data.value
	except AttributeError:
		preserved = False

	if preserved:
		ram = dut.extram.ram
		for i in range(256):
			ram[i] = i + ((~i & 15) << 12)

	# reset
	dut._log.info("reset")
	dut.rst_n.value = 0
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1

	# enable
	dut.ena.value = 1

	if preserved:
		await ClockCycles(dut.clk, 256)
	else:
		await ClockCycles(dut.clk, 1)
