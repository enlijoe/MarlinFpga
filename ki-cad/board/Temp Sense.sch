EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 6 35
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
L Device:R_Pack04_Split R?
U 1 1 5EA64BFC
P 1750 2100
AR Path="/5E9BB2B9/5EA64BFC" Ref="R?"  Part="1" 
AR Path="/5E9FE782/5EA64BFC" Ref="R?"  Part="1" 
AR Path="/5E9FE7AC/5EA64BFC" Ref="R?"  Part="1" 
AR Path="/5E9FE7CA/5EA64BFC" Ref="R?"  Part="1" 
F 0 "R?" H 1820 2146 50  0000 L CNN
F 1 "R_Pack04_Split" H 1820 2055 50  0000 L CNN
F 2 "" V 1680 2100 50  0001 C CNN
F 3 "~" H 1750 2100 50  0001 C CNN
	1    1750 2100
	1    0    0    -1  
$EndComp
$Comp
L Device:CP1 C?
U 1 1 5EA65D92
P 1750 2500
AR Path="/5E9BB2B9/5EA65D92" Ref="C?"  Part="1" 
AR Path="/5E9FE782/5EA65D92" Ref="C?"  Part="1" 
AR Path="/5E9FE7AC/5EA65D92" Ref="C?"  Part="1" 
AR Path="/5E9FE7CA/5EA65D92" Ref="C?"  Part="1" 
F 0 "C?" H 1865 2546 50  0000 L CNN
F 1 "CP1" H 1865 2455 50  0000 L CNN
F 2 "" H 1750 2500 50  0001 C CNN
F 3 "~" H 1750 2500 50  0001 C CNN
	1    1750 2500
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5EA67B5C
P 1750 2750
AR Path="/5E9BB2B9/5EA67B5C" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE782/5EA67B5C" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE7AC/5EA67B5C" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE7CA/5EA67B5C" Ref="#PWR?"  Part="1" 
F 0 "#PWR?" H 1750 2500 50  0001 C CNN
F 1 "GND" H 1755 2577 50  0000 C CNN
F 2 "" H 1750 2750 50  0001 C CNN
F 3 "" H 1750 2750 50  0001 C CNN
	1    1750 2750
	1    0    0    -1  
$EndComp
$Comp
L power:+3V3 #PWR?
U 1 1 5EA6851B
P 1750 1850
AR Path="/5E9BB2B9/5EA6851B" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE782/5EA6851B" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE7AC/5EA6851B" Ref="#PWR?"  Part="1" 
AR Path="/5E9FE7CA/5EA6851B" Ref="#PWR?"  Part="1" 
F 0 "#PWR?" H 1750 1700 50  0001 C CNN
F 1 "+3V3" H 1765 2023 50  0000 C CNN
F 2 "" H 1750 1850 50  0001 C CNN
F 3 "" H 1750 1850 50  0001 C CNN
	1    1750 1850
	1    0    0    -1  
$EndComp
Text HLabel 1950 2300 2    50   Output ~ 0
Out
Wire Wire Line
	1750 2250 1750 2300
Wire Wire Line
	1750 2300 1950 2300
Wire Wire Line
	1750 2300 1750 2350
Connection ~ 1750 2300
Wire Wire Line
	1750 1950 1750 1850
Wire Wire Line
	1750 2650 1750 2700
$Comp
L Connector:Conn_01x02_Male J?
U 1 1 5EA69475
P 1200 2300
AR Path="/5E9BB2B9/5EA69475" Ref="J?"  Part="1" 
AR Path="/5E9FE782/5EA69475" Ref="J?"  Part="1" 
AR Path="/5E9FE7AC/5EA69475" Ref="J?"  Part="1" 
AR Path="/5E9FE7CA/5EA69475" Ref="J?"  Part="1" 
F 0 "J?" H 1308 2481 50  0000 C CNN
F 1 "Conn_01x02_Male" H 1308 2390 50  0000 C CNN
F 2 "" H 1200 2300 50  0001 C CNN
F 3 "~" H 1200 2300 50  0001 C CNN
	1    1200 2300
	1    0    0    -1  
$EndComp
Wire Wire Line
	1750 2300 1400 2300
Wire Wire Line
	1400 2400 1450 2400
Wire Wire Line
	1450 2400 1450 2700
Wire Wire Line
	1450 2700 1750 2700
Connection ~ 1750 2700
Wire Wire Line
	1750 2700 1750 2750
$EndSCHEMATC
