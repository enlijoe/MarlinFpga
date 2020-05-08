import UartPackage::*;

module AvalonMM_Uart #(
	parameter clockRate = 100_000_000,
	parameter defaultClockDivisor = clockRate/9600
) (
	input 				csi_clk,
	input 				rsi_reset,
	input 				avs_s0_read, 
	input 				avs_s0_write,
	input 	[2:0]		avs_s0_address,
	output	[7:0]		avs_s0_readdata, 
	input		[7:0]		avs_s0_writedata,
	
	output 				ins_irq_n,
	
	input					coe_conduit_rx,
	output				coe_conduit_tx
	
);

	logic 						txIdle;
	logic 						_rxFull;
	logic 						frameError;
	logic							parityError;
	logic [8:0] 				rxData;

	// UartPort output registers
	logic [3:0][7:0]			clockDivisor;
	logic [8:0]					txBuffer;
	logic							startTx;
	logic	[2:0]					dataBits;
	UartParityBit				parityBit;
	logic							stopBits2;
	
	// avalon interface output registers
	logic [7:0]					readdata;


	// internal state registers
	logic							lastPortRxFull;
	logic							rxOverRun;
	
	Uart uart(
		.clk(csi_clk),
		.reset(rsi_reset),
		.startTx(startTx),
		.txIdle(txIdle),
		.rxFull(rxFull),
		.frameError(frameError),
		.parityError(parityError),
		.dataBits(dataBits),
		.parityBit(parityBit),
		.stopBits2(stopBits2),
		.clockDivisor(clockDivisor),
		.rxData(rxData),
		.txData(txBuffer),
		.rx(coe_conduit_rx),
		.tx(coe_conduit_tx)
	); 
	defparam uart.clockRate = clockRate;
	
	localparam statusClearMask = 8'b0001_1000;
	
	assign avs_s0_readdata = readdata;
	
	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			resetDevice();
		end else begin
			if(avs_s0_read) begin
				readRegisters();
			end
			
			if(avs_s0_write) begin
				writeRegisters();
			end
			
			if(startTx && !txIdle) begin
				startTx <= '0;
			end
			
			if(lastPortRxFull !== rxFull) begin // edge detect the rxFull
				lastPortRxFull <= rxFull;
				if(rxFull) begin
					if(_rxFull) begin
						rxOverRun <= '1;
					end
					_rxFull <= '1;
				end else begin
					
				end
			end
		end
	end
	
	function void readRegisters();
		case(avs_s0_address)
			3'b000: readdata <= clockDivisor[3];
			3'b001: readdata <= clockDivisor[2];
			3'b010: readdata <= clockDivisor[1];
			3'b011: readdata <= clockDivisor[0];
			3'b100: {_rxFull, readdata} <= {1'b0, rxData[7:0]};
			3'b101: readdata <= readStatsRegister();
			3'b110: readdata <= readControlRegisters();
			3'b111: readdata <= 8'b00;
		endcase
	endfunction
	
	function void writeRegisters();
		case(avs_s0_address)
			3'b000: clockDivisor[3] <= avs_s0_writedata;
			3'b001: clockDivisor[2] <= avs_s0_writedata;
			3'b010: clockDivisor[1] <= avs_s0_writedata;
			3'b011: clockDivisor[0] <= avs_s0_writedata;
			3'b100: {txBuffer[7:0], startTx} <= {avs_s0_writedata, 1'b1};
			3'b101: ;
			3'b110: writeControlRegisters(avs_s0_writedata);
			3'b111: ;
		endcase
	endfunction
	
	function void resetDevice();
		clockDivisor <= defaultClockDivisor;
		rxOverRun <= '0;
		lastPortRxFull <= '0;
		_rxFull <= '0;
		txBuffer <= '0;
		startTx <= '0;
		dataBits <= 3;
		parityBit <= ParityNone;
		stopBits2 <= '0;
		readdata <= '0;
	endfunction
	
	function AvalonStatus readStatsRegister(); 
		AvalonStatus retVal;
		
		retVal.rxOverRun = rxOverRun;
		retVal.txIdle = txIdle;
		retVal.rxFull = _rxFull;
		retVal.frameError = frameError;
		retVal.parityError = parityError;
		retVal.rxDataBit9 = rxData[8];
		
		return retVal;
	endfunction
	
	function void writeControlRegisters(AvalonControl data);
		txBuffer[8] <= data.txDataBit9;
		dataBits <= data.dataBits;
		parityBit <= data.parityBit;
		stopBits2 <= data.stopBits2;
	endfunction
	
	function AvalonControl readControlRegisters();
		AvalonControl retVal;
		
		retVal.txDataBit9 = txBuffer[8];
		retVal.dataBits = dataBits;
		retVal.parityBit = parityBit;
		retVal.stopBits2 = stopBits2;
		
		return retVal;
	endfunction

endmodule
