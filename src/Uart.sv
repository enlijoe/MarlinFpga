import UartPackage::*;

module Uart #(
	parameter clockRate = 100_000_000
) (
	input 						clk,
	input							reset,

	input							startTx,			// the txData is valid and begin the transfer
	output						txIdle,			// high when not transmitting data
	output						rxFull,			// high when finished receiving data
	output						frameError,		// high when there is a framing error receiving data
	output						parityError,	// high when there is a parity error receiving data
	input		[2:0]				dataBits,		// number of data bits-5
	input		UartParityBit	parityBit,		// type or parity to use
	input 						stopBits2,		// 0 = 1 stop bit 1 = 2 stop bits
	input 	[31:0]			clockDivisor,	// what to divide the input clock by to get the desired baud rate
	output 	[8:0]				rxData,			// when rxFull is high contains the valid data received
	input 	[8:0]				txData,			// when startTx is high contains the valid data to send 
														// must remain const until txIdle is high after 1 clock cycle
	input							rx,				// the received serial data
	output						tx					// the sent serial data
);
	typedef enum {
		XferIdle, XferStartBit, XferDataBits, XferParityBit, XferStopBit
	} XferState;

	// portInterface output stats
	logic						_rxFull;
	logic						_frameError;
	logic						_parityError;
	logic [8:0]				rxBuffer;
	logic						_tx;
	
	// internal states
	logic [31:0]			txClockCounter;
	logic [31:0]			rxClockCounter;
	logic	[3:0]				rxBitCounter;
	logic	[3:0]				txBitCounter;
	logic						lasRxValue;
	XferState				rxState;
	XferState				txState;
	
	
	assign rxData = rxBuffer;
	assign tx = _tx;
	assign txIdle = txState == XferIdle;
	assign rxFull = _rxFull;
	assign frameError = _frameError;
	assign parityError = _parityError;
	
	always_ff @(posedge clk) begin
		if(!reset) begin
			resetDevice();
		end else begin
			if(txState === XferIdle) begin
				if(startTx) begin
					startSendingBits();
				end
			end else begin
				sendBits();
			end
			
			if(rxState !== XferIdle) begin
				receiveBits();
			end else if(rx === 1'b0 && lasRxValue === 1'b1) begin
				startReceivingBits();
			end else begin
				lasRxValue <= rx;
			end
		end
	end

	
	function void startReceivingBits();
		rxState <= XferStartBit;
		rxBitCounter <= '0;
		rxBuffer <= '0;
		_parityError <= '0;
		_frameError <= '0;
		_rxFull <= '0;
		rxClockCounter <= clockDivisor>>1;
	endfunction
	
	function void receiveBits();
		rxClockCounter <= rxClockCounter - 1;
		
		if(rxClockCounter === 0) begin
			case (rxState)
				XferIdle: ; // nothing to do we are idle
				
				XferStartBit: begin
					if(rx !== 1'b0) begin
						rxState <= XferIdle;
						_frameError <= '1;
					end else begin
						rxState <= XferDataBits;
						rxClockCounter <= clockDivisor;
					end
				end
				
				XferDataBits: begin
					rxBitCounter <= rxBitCounter + 1;
					rxBuffer[rxBitCounter] <= rx;
					rxClockCounter <= clockDivisor;
					rxState <= getNextState(rxBitCounter);
				end
				
				XferParityBit: begin
					if(calcParity(rxBuffer) !== (rx ^ (parityBit === ParityEven))) begin
						rxState <= XferIdle;
						_parityError <= '1;
					end else begin
						rxClockCounter <= clockDivisor;
						rxState <= XferStopBit;
					end
				end
				
				XferStopBit: begin
					if(rx) begin
						_rxFull <= '1;
					end else begin
						_frameError <= '1;
					end
					rxState <= XferIdle;
				end
			endcase
		end
	endfunction
		
	
	function void startSendingBits();
		txState <= XferStartBit;
		txClockCounter <= 0;
		txBitCounter <= '0;
	endfunction
	
	function void sendBits();
		txClockCounter <= txClockCounter -1;
		
		if(txClockCounter === 0) begin
			case (txState)
				XferIdle: ; // nothing to do we are idle
				
				XferStartBit: begin
					_tx <= '0;
					txClockCounter <= clockDivisor;
					txState <= XferDataBits;
				end
				
				XferDataBits: begin
					txBitCounter <= txBitCounter + 1;
					_tx <= txData[txBitCounter];
					txState <= getNextState(txBitCounter);
					txClockCounter <= clockDivisor;
				end
				
				XferParityBit: begin
					_tx <= calcParity(rxBuffer) ^ (parityBit == ParityEven);
					txClockCounter <= clockDivisor;
					txState <= XferStopBit;
				end
				
				XferStopBit: begin
					_tx <= '1;
					txClockCounter <= clockDivisor;
					txState <= XferIdle;
				end
			endcase
		end
	endfunction
	
	function XferState getNextState(input [2:0] bitCounter);
		if(bitCounter === 4 + dataBits) begin
			return(parityBit == ParityNone)?XferStopBit:XferParityBit;
		end
			return XferDataBits;
	endfunction
	
	
	function bit calcParity(input [8:0] data);
		return data[8] ^ data[7] ^ data[6] ^ data[5] ^ data[4] ^ data[3] ^ data[2] ^ data[1] ^ data[0];
	endfunction

	function void resetDevice();
		rxState <= XferIdle;
		txState <= XferIdle;
		_rxFull <= '0;
		_frameError <= '0;
		_parityError <= '0;
		rxBuffer <= '0;
		_tx <= '1;
		txClockCounter <= '0;
		rxClockCounter <= '0;
		rxBitCounter <= '0;
		txBitCounter <= '0;
		lasRxValue <= '1;
	endfunction
	
endmodule
