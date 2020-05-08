`timescale 1ps / 1ps

localparam testClockRate = 10_000_000;
localparam clockPeroid = (1_000_000_000/testClockRate);
localparam serialClockRate = 1_000_000;
localparam serialClockPeroid = (1_000_000_000/serialClockRate);

module Eeprom_tb();
	logic					clk;
	logic					reset;
	wire 					serialDataWire;
	logic					serialClock;
	logic					writeProtect;
	logic					serialData;
	logic 				serialWrite;
	integer				systemTime;
	logic 				s0_read; 
	logic 				s0_write;
	logic 	[15:0]	s0_address;
	logic		[7:0]		s0_readdata;
	logic		[7:0]		s0_writedata;
	logic					s0_waitrequest;

// Control memory mapped port csr
	logic 				csr_read;
	logic 				csr_write;
	logic 	 			csr_address;
	logic 	[7:0]		csr_readdata;
	logic 	[7:0]		csr_writedata;

	Eeprom DUT (
		.csi_clk(clk),
		.rsi_reset(reset),

		.avs_s0_read(s0_read), 
		.avs_s0_write(s0_write),
		.avs_s0_address(s0_address),
		.avs_s0_readdata(s0_readdata), 
		.avs_s0_writedata(s0_writedata),
		.avs_s0_waitrequest(s0_waitrequest),

		.avs_csr_read(csr_read), 
		.avs_csr_write(csr_write),
		.avs_csr_address(csr_address),
		.avs_csr_readdata(csr_readdata), 
		.avs_csr_writedata(csr_writedata),

		.coe_conduit_serialData(serialDataWire),
		.coe_conduit_serialClock(serialClock),
		.coe_conduit_writeProtect(writeProtect)
	);

	defparam DUT.clockRate = testClockRate;
	defparam DUT.i2cClockRate = serialClockRate;

assign serialDataWire = serialWrite?serialData:1'bz;



	initial begin
		clk = '0; 
		systemTime = '0;
		reset = '0;
		s0_read = '0;
		s0_write = '0;
		s0_address = '0;
		s0_writedata = '0;
		serialData = 'z;
		serialWrite = '0;

		#(2.5*clockPeroid);
		reset = 1;
		$display("Reset complete");

		#(10.5*clockPeroid);	// first test at 20
		// assert that writeProtect is high after reset
		csr_write = 1;
		csr_address = '0;
		csr_writedata = '0;
		csr_read = '0;
		#clockPeroid;
		// assert that writeProtect is low
		csr_writedata = 8'b0000_0001;
		#clockPeroid;
		csr_write = '0;
		// assert that writeProtect is high again

		testWriteToMemoryEepromNotBusy();
		#(serialClockPeroid);
		
		testWriteToMemoryEepromBusy();
		#(serialClockPeroid);

		testReadMemoryNewAddressNoBusy();
		#(serialClockPeroid);

		$stop;

		// assert that the wait request is low
	end

	task testWriteToMemoryEepromNotBusy();
		logic [15:0] memoryAddress;
		logic [7:0] dataByte;

		memoryAddress = 16'h0100;
		dataByte = 8'h22;

		resetDevice();

		#(20*clockPeroid);
		s0_write = 1;
		s0_address = memoryAddress;
		s0_writedata = dataByte;
		s0_read = 0;

		#(clockPeroid/2);
		// assert that the wait request is high

		assertStart();

		// sync up with the start of the serial clock
		nextSerialClock();

		assertSerialByte("Slave address byte", 8'b1010_0000);
		sendAck();
		
		assertSerialByte("Memory address high", memoryAddress[15:8]);
		sendAck();

		assertSerialByte("Memory address low", memoryAddress[7:0]);
		sendAck();

		assertSerialByte("Data byte", dataByte);
		sendAckAndAssertStop();

		waitForReady();

		s0_write = 0;
	endtask

	// test write to memory with eeprom busy
	task testWriteToMemoryEepromBusy();
		logic [15:0] memoryAddress;
		logic [7:0] dataByte;

		memoryAddress = 16'h0100;
		dataByte = 8'h22;

		resetDevice();

		#(20*clockPeroid);
		s0_write = 1;
		s0_address = memoryAddress;
		s0_writedata = dataByte;
		s0_read = 0;

		#(clockPeroid/2);
		// assert that the wait request is high

		assertStart();
		
		// sync up with the start of the serial clock
		nextSerialClock();

		assertSerialByte("Slave address byte", 8'b1010_0000);
		nextSerialClock();
		nextSerialClock();
		
		assertSerialByte("Slave address byte", 8'b1010_0000);
		sendAck();
	
		assertSerialByte("Memory address high", memoryAddress[15:8]);
		sendAck();

		assertSerialByte("Memory address low", memoryAddress[7:0]);
		sendAck();

		assertSerialByte("Data byte", dataByte);
		sendAckAndAssertStop();

		waitForReady();

		s0_write = 0;

	endtask
	// test read from memory with eeprom not busy know address not correct
	task testReadMemoryNewAddressNoBusy();
		logic [15:0] memoryAddress;
		logic [7:0] dataByte;

		memoryAddress = 16'h0100;
		dataByte = 8'h22;

		resetDevice();

		#(20*clockPeroid);
		s0_read = 1;
		s0_write = 0;
		s0_address = memoryAddress;

		#(clockPeroid/2);
		// assert that the wait request is high

		assertStart();

		// sync up with the start of the serial clock
		nextSerialClock();

		assertSerialByte("Slave address byte", 8'b1010_0000);
		sendAck();

		assertSerialByte("Memory address high", memoryAddress[15:8]);
		sendAck();

		assertSerialByte("Memory address low", memoryAddress[7:0]);
		sendAck();
		#1;

		assertStart();
		nextSerialClock();
	
		assertSerialByte("Slave address byte", 8'b1010_0001);
		sendAck();

		sendDataByte(8'h55);
		assertAckAndStop(1'b1);

		waitForReady();
		s0_read = 0;

	endtask

	// test read from memory with known address correct

	// test read from memory eeprom busy

	// test memory write protected
	

always #(clockPeroid/2) clk=~clk;
always #1 systemTime = ++systemTime;

	task sendDataByte(logic [7:0] data);
		logic [7:0] buffer;
		int bitCounter;
		buffer = data;

		serialWrite = 1'b1;

		for(bitCounter = 8; bitCounter != 0; bitCounter = bitCounter - 1) begin
			{serialData, buffer} = {buffer, 1'b0};
			#(serialClockPeroid);
		end
		serialWrite = 1'b0;
	endtask

	task resetDevice();
		reset = 0;
		#(clockPeroid*10);
		reset = 1;
		#(clockPeroid*10);
	endtask;

	task waitForReady();
		while (s0_waitrequest == 1) #1;
	endtask

	task assertAckAndStop(logic state);
		#(0.25*serialClockPeroid);	// ack the slave address frame
		if(serialDataWire != state) begin
			$display("\n\n******* ERROR ****** Ack from master expected %d actual %d\n\n", state, serialDataWire);
			$stop;
		end
		#(0.5*serialClockPeroid);
		#(clockPeroid);
		assertStop();
	endtask

	task sendAck();
		#(0.25*serialClockPeroid);	// ack the slave address frame
		serialData = 1'b1;
		serialWrite = 1'b1;
		#(0.5*serialClockPeroid);
		serialWrite = 1'b0;
		#(0.25*serialClockPeroid);
		nextSerialClock();
	endtask

	task sendAckAndAssertStop();
		#(0.25*serialClockPeroid);	// ack the slave address frame
		serialData = 1'b1;
		serialWrite = 1'b1;
		#(0.5*serialClockPeroid);
		serialWrite = 1'b0;
		#(0.25*serialClockPeroid);	
		assertStop();
	endtask

	task nextSerialClock();
		while (serialClock == 1) #1;
		while (serialClock == 0) #1;
	endtask

	task assertStop();
		if(serialClock == 1) begin
			$display("\n\n******* ERROR ****** serialClock is high and should be low for befor the stop condition\n\n");
			$stop;
		end

		if(serialDataWire == 1) begin
			$display("\n\n******* ERROR ****** serialData is high and should be low for befor the stop condition\n\n");
			#(serialClockPeroid);
			$stop;
		end
		while(serialClock != 1) begin
			if(serialDataWire == 1) begin
				$display("\n\n******* ERROR ****** serialData should not go high before the serial clock does for a stop condition\n\n");
				$stop;
			end
			#1;
		end
		while(serialDataWire != 1) #1;
		
	endtask

	task assertStart();
		if(serialClock == 0) begin
			$display("\n\n******* ERROR ****** serialClock is low and should be high before the start condition\n\n");
			$stop;
		end

		if(serialDataWire == 0) begin
			$display("\n\n******* ERROR ****** serialData is low and should be high for befor the start condition\n\n");
			$stop;
		end

		while(serialDataWire != 0) begin
			if(serialClock == 0) begin
				$display("\n\n******* ERROR ****** serialClock Should not go low before the serial data for a start condition\n\n");
				$stop;
			end
			#1;
		end
		while (serialClock != 0) #1;

	endtask

	task assertSerialByte(string message, logic [7:0] data);
		logic [7:0] buffer;
		int count;
		buffer = 0;

		for(count = 8; count != 0; count = count -1) begin
			buffer = {buffer[6:0], serialDataWire};
			nextSerialClock();
		end
		if(buffer == 8'bzzzz_zzzz || buffer != data) begin
			$display("\n\n******* ERROR ****** %s (expected=%0b, actual=%0b)\nn", message, data, buffer);
			$stop;
		end
		
	endtask
endmodule
