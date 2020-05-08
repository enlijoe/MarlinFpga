module StepperDriver #(
	parameter clockRate = 100_000_000,
	parameter serialRate = 500_000,
	parameter slaveAddress = 0
) (
// Data memory mapped port s0 interface
	input 				csi_clk,
	input 				rsi_reset,
	input 				avs_s0_read, 
	input 				avs_s0_write,
	input 	[7:0]		avs_s0_address,
	output	[31:0]	avs_s0_readdata, 
	input		[31:0]	avs_s0_writedata,
	output				avs_s0_waitrequest,
	output	[1:0]		avs_s0_response,
	
// conduit interface
	inout					coe_conduit_serial,		// needs weak pullup
	output				coe_conduit_direction,
	output				coe_conduit_enable,
	output				coe_conduit_step
);

	localparam			serialPeroid = clockRate/serialRate;
	localparam			serialTimeout = serialPeroid * 32;
	localparam			serialNumStopBits = 1;
	localparam			serialBitsPerByte = 10; // startBit +  8DataBits + stopBit (stop bits are handled as 1 bit streteched to be total length) 
	
	localparam			responseOk = 2'b00;
	localparam			responseSlaveError = 2'b10;
	localparam			responseDecodeError = 2'b11;
	
	typedef enum {UART_IDLE, UART_SYNC, UART_SLAVE_ADD, UART_REG_ADDR, UART_SND_DATA3, UART_SND_DATA2, UART_SND_DATA1, UART_SND_DATA0, UART_CRC, UART_CRC_CHK} UartState;

	// conduit registers
	logic					serialData;
	logic					serialWrite;
	logic					motorStep;
	logic					motorEnable;
	logic					motorDirection;
	
	// avs_s0 registers
	logic					waitrequest;
	logic	[31:0]		readdata;
	logic [1:0]			response;

	
	// internal registers
	logic [31:0] 		registers[3:0];
	logic [$clog2(serialTimeout):0]		clockCounter;
	logic [2:0]			bitCounter;
	logic [7:0] 		buffer;
	logic	[7:0]			crcReg;
	UartState			uartState;
	logic					crcError;
	logic					uartError;
	logic					datagramError;
	logic					haveStartBit;
	logic 				masterAddressError;
	logic					regAddrError;
	
	
	assign avs_s0_waitrequest = waitrequest;
	assign avs_s0_readdata = readdata;
	assign coe_conduit_direction = motorDirection;
	assign coe_conduit_enable = motorEnable;
	assign coe_conduit_step = motorStep;
	assign coe_conduit_serial = serialWrite?serialData:1'bz;
	assign avs_s0_response = response;
	
	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			waitrequest <= '0;
			readdata <= '0;
			serialWrite <= '0;
			motorStep <= '0;
			motorEnable <= '0;
			motorDirection <= '0;
			datagramError <= '0;
			regAddrError <= '0;
			response <= '0;
			// intiialze the internal registers
			
		end else begin
			if(avs_s0_address[7]) begin
				// registers in this module
			end else begin
				// registers on the chip
				if(~waitrequest && (avs_s0_read || avs_s0_write)) begin
					waitrequest <= '1;
					crcReg <= '0;
					enterState(UART_SND_SYNC);
				end
			end
		end
	end
	
	function void enterState(UartState newState);
		uartState <= newState;

		case(newState)
			UART_SND_SYNC:				prepSendData(8'b10100000);
			UART_SND_SLAVE_ADD: 		prepSendData(slaveAddress);
			UART_SND_REG_ADDR: 		prepSendData({avs_s0_address[6:0], avs_s0_write});
			UART_SND_DATA3:			prepSendData(avs_s0_writedata[31:24]);
			UART_SND_DATA2:			prepSendData(avs_s0_writedata[23:16]);
			UART_SND_DATA1:			prepSendData(avs_s0_writedata[15:8]);
			UART_SND_DATA0:			prepSendData(avs_s0_writedata[7:0]);
			UART_SND_CRC:				prepSendData(~crcReg);
			UART_DIR_CHG:				changUartToRead();
			UART_RCV_SYNC:				prepRecvData();
			UART_RCV_MASTER_ADDR:	if(prepRecvDataWithValidate(8'b1010_0000)) flagDatagramError();
			UART_RCV_REG_ADDR:		if(prepRecvDataWithValidate(8'hff)) flagMasterAddressError();
			UART_RCV_DATA3:			if(prepRecvDataWithValidate({avs_s0_address&8'h7f, 1'b0})) flagRegisterAddressError();
			UART_RCV_DATA2:			readdata[31:24] <= prepRecvData();
			UART_RCV_DATA1:			readdata[23:16] <= prepRecvData();
			UART_RCV_DATA0:			readdata[15:8]  <= prepRecvData();
			UART_RCV_CRC:				readdata[7:0]   <= prepRecvData();
			UART_CHK_CRC:				checkCrcValue();
			default:;					// Nothing to do
		endcase
	endfunction
	
	function void enterChangeUartToRead() 
		crcReg <= 0;
		serialWrite <= '0;
	endfunction
	
	function void handleChangeUartToRead() 
	endfunction
	
	task flagMasterAddressError() 
		masterAddressError <= '1;
		uartState <= UART_IDLE;
		waitrequest <= '0;
	endfunction
	
	function void flagDatagramError()
		datagramError = '1;
		uartState <= UART_IDLE;
		waitrequest <= '0;
	endfunction
	
	function void flagRegisterAddressError()
		regAddrError = '1;
		uartState <= UART_IDLE;
		waitrequest <= '0;
	endfunction
	
	function [7:0] prepRecvData()
		uartError <= '0;
		crcError <= '0;
		serialWrite <= '0;
		bitCounter <= serialBitsPerByte;
		clockCounter <= serialTimeout;
		haveStartBit <= 1'b0;
		retrun buffer;
	endfunction

	function prepRecvDataWithValidate(logic [7:0] expected)
		if(buffer != expected) begin
			return '0;
		end else begin
			return '1;
		end
	endfunction
	
	function void checkCrcValue();
		crcError <= crcReg != buffer;
		uartState <= UART_IDLE;
		waitrequest <= '0;
	endfunction
	
	function void prepSendData(input logic [7:0] data);
		uartError <= '0;
		crcError <= '0;
		serialData <= '1;
		serialWrite <= '1;
		buffer <= data;
		bitCounter <= serialBitsPerByte;
		clockCounter <= serialPeroid;
		crcReg <= calcCrc(crcReg, data);
	endfunction
	
	function void handleState();
		case(uartState)
			UART_SND_SYNC:				sendBuffer(UART_SND_SLAVE_ADD);
			UART_SND_SLAVE_ADD:		sendBuffer(UART_SND_REG_ADDR);
			UART_SND_REG_ADDR:		sendBuffer(avs_s0_waitrequest?UART_SND_DATA3:UART_SND_CRC);
			UART_SND_DATA3:			sendBuffer(UART_SND_DATA2);
			UART_SND_DATA2:			sendBuffer(UART_SND_DATA1);
			UART_SND_DATA1:			sendBuffer(UART_SND_DATA0);
			UART_SND_DATA0:			sendBuffer(UART_SND_CRC);
			UART_SND_CRC:				sendBuffer(crcReg);
			UART_DIR_CHG:				handleChangeUartToRead();
			UART_RCV_SYNC:				recvData(UART_RCV_MASTER_ADDR);
			UART_RCV_MASTER_ADDR:	recvData(UART_RCV_REG_ADDR);
			UART_RCV_REG_ADDR:		recvData(UART_RCV_DATA3);
			UART_RCV_DATA3:			recvData(UART_RCV_DATA2);
			UART_RCV_DATA2:			recvData(UART_RCV_DATA1);
			UART_RCV_DATA1:			recvData(UART_RCV_DATA0);
			UART_RCV_DATA0:			recvData(UART_RCV_CRC);
			UART_RCV_CRC:				recvData(UART_CHK_CRC);
			default:;	// nothing to do
		endcase
	endfunction
	
	function void recvData(UartState nextState)
		clockCounter <= clockCounter - 1;
		if(haveStartBit) begin
			if(clockCounter == 0) begin
				clockCounter <= serialPeroid;
				bitCounter <= bitCounter - 1;
				
				case(bitCounter)
					serialBitsPerByte: begin	// start bit received
						clockCounter <= serialPeroid - 1;
					end
					1: begin		// stop bit received
						// we have a issue here we are at the middle of the stop bit and need to wait until the end before we complete this state
						clockCounter <= (serialPeroid/2) * serialNumStopBits;
						bitCounter <= '0;
					end
					0: begin // done with xfer
						crcReg <= calcCrc(crcReg, buffer);
						enterState(nextState);
					end
					default: begin	// data bit received
						buffer <= {buffer[6:0], coe_conduit_serial};
					end
				endcase
			end
		end else begin
			if(coe_conduit_serial == 1'b0) begin
				haveStartBit <= '1;
				// advance to the middle of the start bit
				clockCounter <= (serialPeroid/2)-1;
			end else begin
				if(clockCounter == 0) begin
					// we timmed out waiting for the start bit
					uartError <= '1;
					enterState(UART_IDLE);
				end
			end
		end
	endfunction
	
	function void sendBuffer(UartState nextState);
		clockCounter <= clockCounter - 1;

		if(clockCounter == 0) begin
			clockCounter <= serialPeroid;
			bitCounter <= bitCounter - 1;
			case(bitCounter)
				serialBitsPerByte: begin // send start bit
					serialData <= '0;						
				1: begin // send stop bit(s)
					clockCounter <= serialPeroid * serialNumStopBits;
					serialData <= '1;
				end
				0: begin // all done with xfer
					enterState(nextState);
				end
				default: begin // handle data bit
					{buffer, serialData} <= {1'b0, buffer};				
				end
			endcase
			
		end
	endfunction
	
	function [7:0] calcCrc(input [7:0] crc, input [7:0] data);
		return {crc[6:0], crc[7] ^ crc[1] ^ crc[0] ^ data[0]};
	endfunction
	
endmodule
