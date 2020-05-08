module Eeprom #(
	parameter clockRate = 100_000_000,
	parameter i2cClockRate = 1_000_000
) (
// Data memory mapped port s0 interface
	input 				csi_clk,
	input 				rsi_reset,
	input 				avs_s0_read, 
	input 				avs_s0_write,
	input 	[15:0]	avs_s0_address,
	output	[7:0]		avs_s0_readdata, 
	input		[7:0]		avs_s0_writedata,
	output				avs_s0_waitrequest,

// Control memory mapped port csr interface
	input 				avs_csr_read, 
	input 				avs_csr_write,
	input 	 			avs_csr_address,
	output 	[7:0]		avs_csr_readdata, 
	input 	[7:0]		avs_csr_writedata,

// conduit interface
	inout					coe_conduit_serialData,
	output				coe_conduit_serialClock,
	output				coe_conduit_writeProtect
);

localparam cntWidth = $clog2(clockRate/(2 * i2cClockRate) + 2);
localparam clockPhaseCount = (clockRate / 2 * i2cClockRate);
localparam slaveAddressWrtieMode = 8'b1010_0000;
localparam slaveAddressReadMode = 8'b1010_0001;
localparam dataWidth = 8;

typedef enum {	I2C_START, I2C_STOP, I2C_SLAVE_R_ADDR, I2C_SLAVE_W_ADDR, I2C_NO_ACK, I2C_RESTART, I2C_SND_ACK,
									I2C_MEM_ADDR_H, I2C_MEM_ADDR_L, I2C_SND_BYTE, I2C_RCV_BYTE} I2cState;
									
									
typedef enum { ACK_CHECKING, ACK_RECIVED, ACK_NOT_RECIVED, ACK_NOT_ACK_PHASE } AckCheck;


// registers to hold output states for the connection to the I2C device
logic 						serialData;
logic							serialClock;
logic							writeProtect;
logic							I2cWriteMode; // controls the direction of the I2C serialData line

// registers to hold output states for the connection to the S0 avs bus
logic							waitrequest;
logic	[7:0]					readdata;

// registers to hold the output stats for the connection to the csr avs bus
logic	[7:0]					csrReadData;


// registers to hold internal state
logic [cntWidth-1:0]		clockCounter;
logic [3:0]					bitCounter;
logic [15:0]				addressPointer;
logic [7:0]					buffer;
I2cState						i2cState;
logic							clockPhase;
logic							ackPhase;
logic							retry;
logic							knownAddressPointer;
logic							phaseEnd;
logic 						ackReceived;
logic							ackValue;
logic							lastWriteErrorStatus;


assign coe_conduit_serialClock = serialClock;
assign coe_conduit_writeProtect = writeProtect;
assign coe_conduit_serialData = I2cWriteMode?serialData:'z;
assign avs_s0_waitrequest = waitrequest;
assign avs_s0_readdata = readdata;
assign avs_csr_readdata = csrReadData;


/* 	
	Dummy write
		i2c_start, i2c_slaveWAddr, 12c_slaveAck, i2c_MemAddrH, 12c_slaveAck, i2c_MemAddrL, 12c_slaveAck, i2c_stop
	
	read byte
		i2c_start, i2c_slaveRAddr, 12c_slaveAck, i2c_RcvByte, i2c_stop
	
	write byte
		i2c_start, i2c_slaveWAddr, 12c_slaveAck, i2c_MemAddrH, 12c_slaveAck, i2c_MemAddrL, 12c_slaveAck, 12c_SndByte, 12c_slaveAck, i2c_stop
	
	busy
		i2c_start, i2c_slaveWAddr, <12c_slaveAck missing> i2c_stop // if receive 12c_slaveAck then ready else not ready
	
*/

	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			writeProtect <= '1;
		end else begin
			if(avs_csr_read && !avs_csr_address) begin
				csrReadData <= {7'b0000_0, lastWriteErrorStatus, waitrequest, writeProtect}; 
			end else begin
				csrReadData <= '0; // was 8'b0000_0000
			end
			
			if(avs_csr_write && !avs_csr_address) begin
				writeProtect <= avs_csr_writedata[0];
			end
		end
	end
	

	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			// init the I2C interface
			serialData <= '1;
			serialClock <= '1;
			I2cWriteMode <= '0;

			// init the avs interface
			waitrequest <= '0;
			readdata <= '0; // was 8'b0000_0000
			
			clockCounter <= '0;
			bitCounter <= '0;
			addressPointer <= '0;
			knownAddressPointer <= '0;
			buffer <= '0;
			clockPhase <= '1;
			ackPhase <= '0;
			retry <= '0;
			phaseEnd <= '0;
			ackReceived <= '0;
			ackValue <= '0;
		end else begin
			if(waitrequest) begin
				// we have a transaction in progress
				handleI2cState();
			end else begin
				if(avs_s0_read || avs_s0_write) begin
					waitrequest <= '1;
					enterI2cState(I2C_START);
				end
			end
		end
	end

	task handleI2cState();
		case(i2cState) 
			I2C_START: handleI2cStart();
			I2C_SLAVE_W_ADDR: handleI2cAddress('0);	
			I2C_SLAVE_R_ADDR: handleI2cAddress('1);	
			I2C_MEM_ADDR_H: handleI2cMemoryAddress();
			I2C_MEM_ADDR_L: handleI2cMemoryAddress();
			I2C_SND_BYTE: handleI2cSendByte();
			I2C_RCV_BYTE: handleI2cReceiveByte();
			I2C_STOP: handleI2cStop();
			I2C_NO_ACK: handleI2cNoAck();
			I2C_RESTART: handleI2cRestart();
			I2C_SND_ACK: handleI2cSendAck();
		endcase
	endtask
	
	task enterI2cState(I2cState newState);
		I2cWriteMode <= newState != I2C_RCV_BYTE;
		clockCounter <= clockPhaseCount - 1;
		clockPhase <= '1;
		ackPhase <= '0;
		i2cState <= newState;
		phaseEnd <= '0;
		ackReceived <= '0;
		if(newState == I2C_RESTART) begin
			serialData <= '1;
		end
		if(newState == I2C_START) begin
			serialData <= '0;
		end
		if(newState == I2C_STOP) begin
			serialData <= '0;
		end
	endtask
	
	task handleI2cStop();
		clockCounter <= clockCounter - 1;
		serialClock <= clockPhase;
		if(clockCounter == 0) begin
			if(!serialClock) begin
				clockPhase <= '1;
				clockCounter <= 1;
				serialData <= '0;
			end else begin
				serialData <= '1;
				if(!serialData) begin
					clockCounter <= clockPhaseCount + 2;
				end else begin
					if(retry) begin
						enterI2cState(I2C_START);
					end else begin
						waitrequest <= '0;
					end
				end
			end
		end 
	endtask
	
	task handleI2cRestart();
		clockCounter <= clockCounter - 1;
		serialClock <= clockPhase;
		if(clockCounter == 0) begin
			if(serialClock == '1) begin
				clockPhase <= '0;
				serialData <= '0;
				clockCounter <= clockPhaseCount - 1;
			end else begin
				if(avs_s0_write | (avs_s0_read && addressPointer != avs_s0_address)) begin
					bitCounter <= dataWidth;
					loadAndShiftBuffer(slaveAddressWrtieMode);
					enterI2cState(I2C_SLAVE_W_ADDR);
				end else begin
					bitCounter <= dataWidth;
					loadAndShiftBuffer(slaveAddressReadMode);
					enterI2cState(I2C_SLAVE_R_ADDR);
				end
			end
		end
		
	endtask
	
	task handleI2cStart();
		clockCounter <= clockCounter - 1;
		if(clockCounter == 0) begin
			if(avs_s0_write | (avs_s0_read && addressPointer != avs_s0_address)) begin
				bitCounter <= dataWidth;
				loadAndShiftBuffer(slaveAddressWrtieMode);
				enterI2cState(I2C_SLAVE_W_ADDR);
			end else begin
				bitCounter <= dataWidth;
				loadAndShiftBuffer(slaveAddressReadMode);
				enterI2cState(I2C_SLAVE_R_ADDR);
			end
		end else begin
			serialClock <= '0;
			clockPhase <= '0;
		end
	endtask
	
	task handleI2cSendAck();
		clockCounter <= clockCounter - 1;
		serialClock <= clockPhase;
		if(clockCounter == 0) begin
			if(clockPhase == 0) begin
				clockPhase <= '1;
				clockCounter <= clockPhaseCount - 2;
			end else begin
				clockPhase <= '0;
				serialClock <= '0;
				ackPhase <= '0;
				clockCounter <= clockPhaseCount - 2;
				i2cState <= I2C_STOP;
			end
		end
	endtask
	
	task handleI2cNoAck();
		clockCounter <= clockCounter - 1;
		serialClock <= clockPhase;
		if(clockCounter == 0) begin
			clockPhase <= '0;
			serialClock <= '0;
			ackPhase <= '0;
			clockCounter <= clockPhaseCount - 2;
			i2cState <= I2C_STOP;
		end
	endtask
	
	task enterI2cNoAck();
		i2cState <= I2C_NO_ACK;
		clockCounter <= 1;
		clockPhase <= '1;
	endtask

	task handleI2cSendByte();
		processAckEnd();
		case(ackEndResult()) 
			ACK_CHECKING:;
			ACK_RECIVED: begin
				// we have our ack so move on
				retry <= '0;
				enterI2cState(I2C_STOP);
			end
			ACK_NOT_RECIVED: enterI2cNoAck();
			ACK_NOT_ACK_PHASE: handleDataXfer();
		endcase
	endtask
	
	task handleI2cMemoryAddress();
		processAckEnd();
		case(ackEndResult()) 
			ACK_CHECKING:;
			ACK_RECIVED: begin
				// we have our ack so move on
				if(i2cState == I2C_MEM_ADDR_H) begin
					bitCounter <= dataWidth;
					loadAndShiftBuffer(avs_s0_address[7:0]);
					enterI2cState(I2C_MEM_ADDR_L);
				end else begin
					knownAddressPointer <= '1;
					addressPointer <= avs_s0_address;
					if(avs_s0_write) begin
						bitCounter <= dataWidth;
						loadAndShiftBuffer(avs_s0_writedata);
						enterI2cState(I2C_SND_BYTE);
					end else if(avs_s0_read) begin
						enterI2cState(I2C_RESTART);
					end
				end
			end
			ACK_NOT_RECIVED: enterI2cNoAck();
			ACK_NOT_ACK_PHASE: handleDataXfer();
		endcase
	endtask
	
	
	
	function AckCheck ackEndResult();
		if(phaseEnd) begin
			if(!ackReceived) begin
				if(coe_conduit_serialData) begin
				end else begin
					return ACK_NOT_RECIVED;
				end
			end
			if(clockCounter == 0 && !clockPhase && clockCounter == 0) begin
				return ACK_RECIVED;
			end
			return ACK_CHECKING;
		end else begin
			return ACK_NOT_ACK_PHASE;
		end
	endfunction
	
	
	task processAckEnd();
		if(phaseEnd) begin
			if(!ackReceived) begin
				if(coe_conduit_serialData) begin
					ackReceived <= '1;
				end else begin
					retry <= '1;
					return;		// ACK_NOT_RECIVED
				end
			end
			clockCounter <= clockCounter - 1;
			serialClock <= clockPhase;
			if(clockCounter == 0) begin
				if(clockPhase) begin
					// we need to trigger the low part of the serial clock here
					clockPhase <= '0;
					clockCounter <= clockPhaseCount - 1;
				end else begin
					if(clockCounter == 0) begin
						return;	// ACK_RECIVED
					end
				end
			end
			return;	// ACK_CHECKING
		end else begin
			ackReceived <= '0;
			return;	// ACK_NOT_ACK_PHASE
		end
	endtask
	
	task handleI2cAddress(logic readMode);
		// we have our ack so move on
		processAckEnd();
		case(ackEndResult()) 
			ACK_CHECKING:;
			ACK_RECIVED: begin
				if(readMode) begin
					bitCounter <= dataWidth;
					enterI2cState(I2C_RCV_BYTE);
				end else begin
					bitCounter <= dataWidth;
					loadAndShiftBuffer(avs_s0_address[15:8]);
					enterI2cState(I2C_MEM_ADDR_H);
				end
			end
			ACK_NOT_RECIVED: enterI2cNoAck();
			ACK_NOT_ACK_PHASE: handleDataXfer();
		endcase 
	endtask
	
	task handleI2cReceiveByte();
		clockCounter <= clockCounter - 1;
		serialClock <= clockPhase;
		case ({clockCounter==0, clockPhase, bitCounter==0}) inside
			3'b100: begin
				// This the the last cycle before the clock will go high
				clockPhase <= '1;
				clockCounter <= clockPhaseCount - 1;
			end

			3'b11?: begin
				// we just finished with the high clk phase so shift in our new data bit
				bitCounter = bitCounter - 1;
				clockPhase <= '0;
				clockCounter <= clockPhaseCount - 1;
				buffer <= {buffer[6:0], coe_conduit_serialData};
			end
			
			3'b101: begin
				// this is the end of this pahse
				retry <= '0;
				I2cWriteMode <= '1;
				serialData <= '1;
				enterI2cState(I2C_SND_ACK);
			end
		endcase
	endtask
	
	
	
	task handleDataXfer();
		clockCounter <= clockCounter - 1;
		case ({clockCounter==0, clockPhase, bitCounter==0, ackPhase}) inside
			4'b0???: begin
				if(clockCounter == 2 && clockPhase && bitCounter==0 && ackPhase) begin
					phaseEnd <= '1;
				end 
				// since the clock counter has not hit zero there is nothing to do but matain/set the state on the clock
				// as long as we are not doing an ack we are writting to the I2C serialData
				serialClock <= clockPhase;
				I2cWriteMode <= ~ackPhase;
			end
			
			4'b100?: begin
				// This the the last cycle before the clock will go high so we need to load our next bit 
				// and reset the clockCounter
				loadAndShiftBuffer(buffer);
				clockPhase <= '1;
				clockCounter <= clockPhaseCount - 1;
			end
			4'b1010: begin
				ackPhase <= '1;
				I2cWriteMode <= '0;
				clockPhase <= '1;
				clockCounter <= clockPhaseCount - 1;
			end

			4'b1011: begin
				ackPhase <= '1;
				clockPhase <= '1;
			end
			
			4'b1100: begin
				// we just finished with the high clk phase and need to setup for the next bit to be sent
					clockPhase <= '0;
					clockCounter <= clockPhaseCount - 1;
					bitCounter--;
			end
			
			4'b1101: begin
				// we just finished with the high clk phase so we need to do nothing for the low part of the clock
				// but to make sure we state here the we are reading now not writing
				I2cWriteMode <= '0;
			end

			4'b1110: begin
				// should be a non reachable phase
			end
			
			4'b1111: begin
				// !!!! This is the end of this state !!!!
				// we do not do anything this will be handled by who called us
			end
		endcase
	endtask
	
	task loadAndShiftBuffer(logic [7:0] data);
		{serialData, buffer} <= {data, 1'b0};
	endtask
endmodule
