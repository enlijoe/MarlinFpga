module Pwm #() (
// Memory mapped port s0 interface for register access
	input 				csi_clk,
	input 				rsi_reset,
	input 				avs_s0_read, 
	input 				avs_s0_write,
	input 	[1:0]		avs_s0_address,
	output	[31:0]	avs_s0_readdata, 
	input		[31:0]	avs_s0_writedata,
	
	output 				ins_irq_n,

	output				coe_conduit_output
);

	typedef struct packed {
		logic					pwmOutput;
		logic					running;
		logic					onShot;
		logic					posEdgeIrqEnable;
		logic					negEdgeIrqEnable;
		logic					posEdgeIrqFlag;
		logic					negEdgeIrqFlag;
		logic					invertOutput;
	} InternalRegisters;
	
	localparam writableRegisterMask = 8'b0111_1111;
	localparam clearOnlyRegisterMask = 8'b0000_0110;
	
	logic		[31:0]	readData;
	
	logic		[31:0]	clockCounter;
	logic		[31:0]	onTimeRegister;
	logic		[31:0]	offTimeRegister;
	InternalRegisters registers;
	
	assign avs_s0_readdata = readData;
	assign ins_irq_n = registers.posEdgeIrqEnable?registers.posEdgeIrqEnable:0 && registers.negEdgeIrqEnable?registers.negEdgeIrqFlag:0;
	assign coe_conduit_output = registers.invertOutput ^ registers.pwmOutput;
	
	always_ff @(posedge csi_clk) begin
		if(!rsi_reset) begin
			handleReset();
		end else begin
			if(registers.running) begin
				handlePwmCounters();
			end
			
			if(avs_s0_read) begin
				handleReadRegisters();
			end
			
			if(avs_s0_write) begin
				handleWriteRegisters();
			end
		end
	end
	
	function void handleReset();
//		registers.pwmOutput <= '0;
//		registers.running <= '0;
//		registers.onShot <= '0;
//		registers.posEdgeIrqEnable <= '0;
//		registers.negEdgeIrqEnable <= '0;
//		registers.posEdgeIrqFlag <= '0;
//		registers.negEdgeIrqFlag <= '0;
		registers <= '0;
		clockCounter <= '0;
		onTimeRegister <= '0;
		offTimeRegister <= '0;
	endfunction
	
	function void handlePwmCounters();
		clockCounter <= clockCounter - 1;
		if(clockCounter == 0) begin
			if(registers.pwmOutput) begin
				registers.pwmOutput <= '0;
				registers.negEdgeIrqFlag <= '1;
				if(offTimeRegister == 0) begin
					registers.running <= '0;
				end else begin
					clockCounter <= onTimeRegister;
				end
			end else begin
				if(registers.onShot) begin
					registers.running <= '0;
				end else begin
					clockCounter <= offTimeRegister;
					registers.posEdgeIrqFlag <= '1;
					registers.pwmOutput <= '1;
				end
			end
		end 
	endfunction
	
	function void handleReadRegisters();
		case(avs_s0_address)
			2'b00: readData <= clockCounter;
			2'b01: readData <= onTimeRegister;
			2'b10: readData <= offTimeRegister;
			2'b11: readData <= registers;
		endcase
		registers.posEdgeIrqFlag <= '0;
	endfunction
	
	function void handleWriteRegisters();
		case(avs_s0_address)
			2'b00: clockCounter <= avs_s0_writedata;
			2'b01: onTimeRegister <= avs_s0_writedata;
			2'b10: offTimeRegister <= avs_s0_writedata;
			2'b11: registers <=  fixForReadOnlyAndClearOnly(avs_s0_writedata);
		endcase
		
		
	endfunction
	
	function [31:0] fixForReadOnlyAndClearOnly(input [31:0] data);
		return (~writableRegisterMask&registers) | (writableRegisterMask & ((data & ~clearOnlyRegisterMask)  | (registers & data & clearOnlyRegisterMask)));
	endfunction
	
endmodule
