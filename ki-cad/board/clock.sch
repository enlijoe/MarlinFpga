EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 9 33
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Oscillator:TXC-7C X1
U 1 1 5EA0317B
P 1400 1850
F 0 "X1" H 1550 2150 50  0000 L CNN
F 1 "TXC-7C" H 1500 1550 50  0000 L CNN
F 2 "Oscillator:Oscillator_SMD_TXC_7C-4Pin_5.0x3.2mm" H 2100 1500 50  0001 C CNN
F 3 "http://www.txccorp.com/download/products/osc/7C_o.pdf" H 1300 1850 50  0001 C CNN
	1    1400 1850
	1    0    0    -1  
$EndComp
Wire Wire Line
	1100 1850 950  1850
Wire Wire Line
	950  1850 950  1450
Wire Wire Line
	950  1450 1400 1450
Wire Wire Line
	1400 1450 1400 1550
$Comp
L power:GND #PWR081
U 1 1 5EA0436F
P 1400 2250
F 0 "#PWR081" H 1400 2000 50  0001 C CNN
F 1 "GND" H 1405 2077 50  0000 C CNN
F 2 "" H 1400 2250 50  0001 C CNN
F 3 "" H 1400 2250 50  0001 C CNN
	1    1400 2250
	1    0    0    -1  
$EndComp
Wire Wire Line
	1400 2150 1400 2250
Text HLabel 2100 1850 2    50   Input ~ 0
clk
Wire Wire Line
	1700 1850 2100 1850
$Comp
L Device:C C51
U 1 1 5EA05076
P 2000 1250
F 0 "C51" H 2115 1296 50  0000 L CNN
F 1 "C" H 2115 1205 50  0000 L CNN
F 2 "" H 2038 1100 50  0001 C CNN
F 3 "~" H 2000 1250 50  0001 C CNN
	1    2000 1250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR082
U 1 1 5EA05E71
P 2000 1500
F 0 "#PWR082" H 2000 1250 50  0001 C CNN
F 1 "GND" H 2005 1327 50  0000 C CNN
F 2 "" H 2000 1500 50  0001 C CNN
F 3 "" H 2000 1500 50  0001 C CNN
	1    2000 1500
	1    0    0    -1  
$EndComp
Wire Wire Line
	2000 1100 2000 1050
Wire Wire Line
	2000 1050 1400 1050
Wire Wire Line
	1400 1050 1400 1450
Connection ~ 1400 1450
Wire Wire Line
	2000 1400 2000 1500
$Comp
L power:+3V3 #PWR080
U 1 1 5EA06850
P 1400 950
F 0 "#PWR080" H 1400 800 50  0001 C CNN
F 1 "+3V3" H 1415 1123 50  0000 C CNN
F 2 "" H 1400 950 50  0001 C CNN
F 3 "" H 1400 950 50  0001 C CNN
	1    1400 950 
	1    0    0    -1  
$EndComp
Wire Wire Line
	1400 950  1400 1050
Connection ~ 1400 1050
$EndSCHEMATC
