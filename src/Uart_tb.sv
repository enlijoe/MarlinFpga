`timescale 1ps / 1ps

import UartPackage::*;

localparam testTimeSlicePerSec = 1_000_000_000;
localparam testClockRate = 10_000_000;
localparam serialClockRate = 1_000_000;


localparam clockPeroid = (testTimeSlicePerSec/testClockRate);
localparam serialClockPeroid = (testTimeSlicePerSec/serialClockRate);
localparam serialRateClockPeroid = (testClockRate/serialClockRate);

localparam StatusBufferOrverRunBitMask = 8'b0010_0000;
localparam StatusTxEmptyBitMask = 8'b0001_0000;
localparam StatusRxFullBitMask = 8'b0000_1000;
localparam StatusFrameErrorBitMask = 8'b0000_0100;
localparam StatusParityErrorBitMask = 8'b0000_0010;
localparam StatusRxBit9BitMask = 8'b0000_0001;



module Uart_tb();
	logic 				clk;
	logic 				reset;
	logic 				s0_read;
	logic 				s0_write;
	logic 	[2:0]		s0_address;
	logic		[7:0]		s0_readdata;
	logic		[7:0]		s0_writedata;
	logic					irq;
	logic					rx;
	logic					tx;

	integer				systemTime;
	
	AvalonMM_Uart			DUT (
		.csi_clk(clk),
		.rsi_reset(reset),
		.avs_s0_read(s0_read), 
		.avs_s0_write(s0_write),
		.avs_s0_address(s0_address),
		.avs_s0_readdata(s0_readdata), 
		.avs_s0_writedata(s0_writedata),
		.ins_irq_n(irq),				
		.coe_conduit_rx(tx),
		.coe_conduit_tx(rx)
	);

	defparam DUT.clockRate = testClockRate;

	
	initial begin
		clk = 0; 
		systemTime = 0;
		reset = 0;
		s0_read = 0;
		s0_write = 0;
		s0_address = 0;
		s0_writedata = 0;
		tx = 1'b1;
		
		#(2.5*clockPeroid);
		reset = 1;
		$display("Reset complete");
		
		// now setup the device defaults
		setSerialClockRate(serialRateClockPeroid-1);
		
		
		testSendByteToUart();

		testReceiveByteFromUart();
		
		#(2*serialClockPeroid);
		$stop;
		
	end
	
	always #(clockPeroid/2) clk=~clk;
	always #1 systemTime = ++systemTime;
	
//	initial #(100*serialClockPeroid) $stop;

	task testSendByteToUart();
		static logic [7:0] theByte = 8'b0101_0101;
		AvalonStatus status;
		
		sendByte(theByte);
		
		s0_address = 5;
		s0_read = 1;
		
		#(clockPeroid) status = s0_readdata;
		
		if(status.rxFull === 0) begin
			$display("\n\n************ Uart rxFull bit expected to be set %0b-%0b (%0b)", s0_readdata, StatusRxFullBitMask, (s0_readdata & StatusRxFullBitMask));
			$stop;
		end

		if(status.rxOverRun === 1) begin
			$display("\n\n************ Uart buffer over run bit should not be set");
			$stop;
		end
		
		if(status.frameError === 1) begin
			$display("\n\n************ Uart frame error bit should not be set");
			$stop;
		end
		
		if(status.parityError === 1) begin
			$display("\n\n************ Uart parity error bit should not be set");
			$stop;
		end
		
		if(status.rxDataBit9 === 1) begin
			$display("\n\n************ Uart received 9th bit should not be set");
			$stop;
		end
		
		s0_address = 4;
		s0_read = 1;
		
		#(2*clockPeroid);
		
		if(s0_readdata != theByte) begin
			$display("\n\n************ Expected uart received byte %h actual %h", theByte, s0_readdata);
			$stop;
		end

		s0_address = 5;
		s0_read = 1;
		
		#(clockPeroid) status = s0_readdata;

		if(status.rxFull === 1) begin
			$display("\n\n************ Uart rxFull bit expected to be cleared after reading the data");
			$stop;
		end


		#(2*clockPeroid);
		s0_read = 0;
		
	endtask
	
	task testReceiveByteFromUart();
		logic [7:0] data;

		s0_address = 4;
		s0_writedata = 8'h55;
		s0_write = 1;
		
		#(2*clockPeroid);

		if(s0_readdata & StatusTxEmptyBitMask != 1'b1) begin
			$display("**********  Error tx buffer should be full");
			$stop;
		end
		
		s0_write = 0;
		
		receiveByte(data);
		
		if(data != 8'h55) begin
			$display("**********  Error expected %h actual %h", 8'h55, data);
			$stop;
		end
		
		s0_address = 5;
		s0_read = 1;
		
		#(2*clockPeroid);

		s0_read = 0;
		
		
		if(s0_readdata & StatusTxEmptyBitMask != 1'b0) begin
			$display("**********  Error tx buffer should be empty");
			$stop;
		end
		
	endtask
	
	task receiveByte(output logic [7:0] data);
		int onBit;
		int timeOutCount;
		
		timeOutCount = 0;
		
		while(rx != 0) begin
			#1 timeOutCount++;
			if(timeOutCount > 10*serialClockPeroid) begin
				$display("\n\n**************Timed out waitting for the start bit\n\n");
				$stop;
			end
		end
		
		for(onBit = 0; onBit < 8; onBit++) begin
			#(serialClockPeroid);
			data[onBit] = rx;
		end
		#(serialClockPeroid);
		if(rx != 1'b1) begin	
			$display("\n\n**************Did not receive the stop bit\n\n");
			$stop;
		end

		#(serialClockPeroid);
	
	endtask
	
	task sendByte(logic [7:0] data);
		int onBit;
		
		tx = 1'b0;
		#(serialClockPeroid);
		
		for(onBit = 0; onBit < 8; onBit++) begin
			tx = data[onBit];
			#(serialClockPeroid);
		end
		tx = 1'b1;
		#(serialClockPeroid);
	endtask
	
	task setSerialClockRate(logic [31:0] rate);
		s0_address = 0;
		s0_writedata = rate[31:24];
		s0_write = 1;
		
		#(2*clockPeroid);

		s0_address = 1;
		s0_writedata = rate[23:16];
		s0_write = 1;
		
		#(2*clockPeroid);
		
		s0_address = 2;
		s0_writedata = rate[15:8];
		s0_write = 1;
		
		#(2*clockPeroid);
		
		s0_address = 3;
		s0_writedata = rate[7:0];
		s0_write = 1;
		
		#(2*clockPeroid);
		
		s0_write = 0;
	endtask
	
endmodule
