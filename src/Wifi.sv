module Widfi#(
	parameter clockRate = 100_000_000,
	parameter busClockRate = 1_000_000
) (
// Data memory mapped port s0 interface
	input 				csi_clk,
	input 				rsi_reset,
	input 				avs_s0_read, 
	input 				avs_s0_write,
	input 	[15:0]	avs_s0_address,
	output	[31:0]	avs_s0_readdata, 
	input		[31:0]	avs_s0_writedata,
	output				avs_s0_waitrequest,
	output				ins_irq_n,

// conduit interface
	inout		[3:0]		coe_conduit_serialData,
	output				coe_conduit_readNotWrite,
	output				coe_conduit_chipSelect,
	output				coe_conduit_serialClock,
	input					coe_conduit_irq
);

	localparam serialClockCount = clockRate/busClockRate;

	typedef enum {
		StateIdle, StateAddress, StateReadData, StateWriteData, StateSlaveAck, StateMasterAck
	} InternalState;

// s0 interface registers
	logic				irq;
	logic				s0_waitrequest;
	logic	[31:0]	s0_readdata;
	
// conduit interface registers
	logic [4:0]		conduit_serialData;
	logic				conduit_readNotWrite;
	logic				conduit_chipSelect;
	logic				conduit_serialClock;
	
	assign avs_s0_waitrequest = s0_waitrequest;
	assign avs_s0_readdata = avs_s0_readdata;
	assign ins_irq_n = irq;
	assign coe_conduit_serialData = conduit_readNotWrite?'z:conduit_serialData;
	assign coe_conduit_readNotWrite = conduit_readNotWrite;
	assign coe_conduit_chipSelect = conduit_chipSelect;
	assign coe_conduit_serialClock = conduit_serialClock;
	
	logic [15:0] 	clockCounter;
	InternalState	internalState;
	logic [2:0]		nibbleCounter;
	logic 			clockPhase;
	
	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			resetDevice();
		end else begin
			if(coe_conduit_irq) begin
				irq = '1;
			end
			
			if(!s0_waitrequest) begin
				if(avs_s0_read || avs_s0_write) begin
					enterSendAddress();
				end
			end else begin
				clockCounter <= clockCounter - 1;
				conduit_serialClock <= clockPhase;
				if(clockCounter == 0) begin
					clockPhase <= ~clockPhase;
					nibbleCounter = nibbleCounter - 1;
					case (internalState)
						StateAddress:		handleSendAddress();
						StateReadData: 	handleReceiveData();
						StateWriteData: 	handleWriteData();
						StateSlaveAck: 	handleSlaveAck();
						StateMasterAck:	handleMasterAck();
					endcase
				end
			end
		end
	end
	
	task enterSendAddress();
		nibbleCounter <= 3;
		s0_waitrequest <= '1;
		clockCounter <= '0;
		conduit_readNotWrite <= '0;
		conduit_chipSelect <= '1;
		clockPhase <= '0;
	endtask
	
	task enterReceiveData();
	endtask
	
	task enterWriteData();
	endtask
	
	task resetDevice();
		clockCounter <= '0;
		s0_waitrequest<= '0;
		irq <= '0;
		s0_readdata <= '0;
		conduit_serialData <= 'z;
		conduit_readNotWrite <= '1;
		conduit_chipSelect <= '0;
		conduit_serialClock <= '0;
		internalState <= StateIdle;
		nibbleCounter <= '0;
		clockPhase <= '1;
	endtask
	
	task handleSendAddress();
		case (nibbleCounter) 
			3:	conduit_serialData <= avs_s0_address[15:12];
			2: conduit_serialData <= avs_s0_address[11:8];
			1: conduit_serialData <= avs_s0_address[7:4];
			0: begin
				conduit_serialData <= avs_s0_address[3:0];
				if(avs_s0_read) begin
					enterReceiveData();
				end else begin
					enterWriteData();
				end
			end
		endcase
	endtask
	
	task handleReceiveData();
		if(nibbleCounter == 1) begin
			s0_readdata[7:4] <= coe_conduit_serialData;
		end else begin
			s0_readdata[3:0] <= coe_conduit_serialData;
			completeTransfer();
		end
	endtask
	
	task handleWriteData();
		if(nibbleCounter == 1) begin
			conduit_serialData <=  avs_s0_writedata[7:4];
		end else begin
			conduit_serialData <= avs_s0_writedata[3:0];
			completeTransfer();
		end
	endtask
	
	task completeTransfer();
		s0_waitrequest <= '0;
		conduit_readNotWrite <= '1;
		clockPhase <= '1;
		conduit_serialClock <= '1;
		conduit_chipSelect <= '0;
	endtask
	
endmodule
