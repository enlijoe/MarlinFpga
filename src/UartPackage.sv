package UartPackage;
	typedef enum logic [1:0] {
	ParityNone, ParityEven, ParityOdd
	} UartParityBit;
	
	typedef struct packed {
		logic rxOverRun;
		logic txIdle;
		logic rxFull;
		logic frameError;
		logic parityError;
		logic rxDataBit9;
	} AvalonStatus;
	
	typedef struct packed {
		logic 			txDataBit9;
		logic 			dataBits;
		UartParityBit 	parityBit;
		logic 			stopBits2;
	} AvalonControl;
	
endpackage
