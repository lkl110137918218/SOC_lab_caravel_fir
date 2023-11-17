/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// This include is relative to $CARAVEL_PATH (see Makefile)
#include <defs.h>
#include <stub.c>
// #include <stdio.h>


extern int* fir();
extern int* generate_x();
extern int  get_length();
extern int* get_tap();

// --------------------------------------------------------

/*
	MPRJ Logic Analyzer Test:
		- Observes counter value through LA probes [31:0] 
		- Sets counter initial value through LA probes [63:32]
		- Flags when counter value exceeds 500 through the management SoC gpio
		- Outputs message to the UART when the test concludes successfuly
*/

void main()
{
	int j;

	/* Set up the housekeeping SPI to be connected internally so	*/
	/* that external pin changes don't affect it.			*/

	// reg_spi_enable = 1;
	// reg_spimaster_cs = 0x00000;

	// reg_spimaster_control = 0x0801;

	// reg_spimaster_control = 0xa002;	// Enable, prescaler = 2,
                                        // connect to housekeeping SPI

	// Connect the housekeeping SPI to the SPI master
	// so that the CSB line is not left floating.  This allows
	// all of the GPIO pins to be used for user functions.

	// The upper GPIO pins are configured to be output
	// and accessble to the management SoC.
	// Used to flad the start/end of a test 
	// The lower GPIO pins are configured to be output
	// and accessible to the user project.  They show
	// the project count value, although this test is
	// designed to read the project count through the
	// logic analyzer probes.
	// I/O 6 is configured for the UART Tx line

        reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

        reg_mprj_io_15 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_14 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_13 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_12 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_11 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_10 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_9  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_8  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_7  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_6  = GPIO_MODE_MGMT_STD_OUTPUT;
		reg_mprj_io_5  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_4  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_3  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_2  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_1  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_0  = GPIO_MODE_USER_STD_OUTPUT;

        

	// Set UART clock to 64 kbaud (enable before I/O configuration)
	// reg_uart_clkdiv = 625;
	reg_uart_enable = 1;
	
	// Now, apply the configuration
	reg_mprj_xfer = 1;
	while (reg_mprj_xfer == 1);

        // Configure LA probes [31:0], [127:64] as inputs to the cpu 
	// Configure LA probes [63:32] as outputs from the cpu
	reg_la0_oenb = reg_la0_iena = 0x00000000;    // [31:0]
	reg_la1_oenb = reg_la1_iena = 0xFFFFFFFF;    // [63:32]
	reg_la2_oenb = reg_la2_iena = 0x00000000;    // [95:64]
	reg_la3_oenb = reg_la3_iena = 0x00000000;    // [127:96]

	// Flag start of the test 
	reg_mprj_datal = 0xAB400000;

	// Set Counter value to zero through LA probes [63:32]
	reg_la1_data = 0x00000000;

	// Configure LA probes from [63:32] as inputs to disable counter write
	reg_la1_oenb = reg_la1_iena = 0x00000000;    

/*
	while (1) {
		if (reg_la0_data_in > 0x1F4) {
			reg_mprj_datal = 0xAB410000;
			break;
		}
	}

*/	

int mask = 1 ;

// Check FIR is idle, if not, wait until FIR is idle
// print("Check Whether FIR is IDLE\n");
int FIR_is_idle = 0 ;
while (~FIR_is_idle)
{
	FIR_is_idle = (((mask<<0) & reg_user_ap_signal )>>0) ; // chech ap[0]==1
}

// task of program length
// print("Program length\n");
reg_user_data_length =  get_length();

// task of program tap (coeff)
// print("Program tap\n");
int* tmp_tap = get_tap();
reg_user_tap_0 = *tmp_tap ;
reg_user_tap_1 = *(tmp_tap+1) ;
reg_user_tap_2 = *(tmp_tap+2) ;
reg_user_tap_3 = *(tmp_tap+3) ;
reg_user_tap_4 = *(tmp_tap+4) ;
reg_user_tap_5 = *(tmp_tap+5) ;
reg_user_tap_6 = *(tmp_tap+6) ;
reg_user_tap_7 = *(tmp_tap+7) ;
reg_user_tap_8 = *(tmp_tap+8) ;
reg_user_tap_9 = *(tmp_tap+9) ;
reg_user_tap_10 = *(tmp_tap+10) ;


// task of START
reg_user_ap_signal = 0b1 ;

// task of sent x[n] and recieve y[n]
int send_data_ready , recieve_data_ready ;
int send_complete   , recieve_complete ;
int Y ;
for (int n =0 ; n<= 600 ; n++){
	// generate x[n]
	int* tmp_x = generate_x(n);

	// sent x[n] to fir.v until get ack , which means the task is successfully complete.
	send_complete = 0 ;
	while (~send_complete)
	{
		send_data_ready = (((mask<<4) & reg_user_ap_signal )>>4)==1 ; // chech ap[4]==1
		if (send_data_ready)
		{
			reg_mprj_datal = *tmp_x << 16; // just to see if the value is correct
			reg_user_X_input = *tmp_x ;
			send_complete = 1 ;
		}
	}

	recieve_complete = 0 ;
	while (~recieve_complete)
	{
		recieve_data_ready = (((mask<<5) & reg_user_ap_signal )>>5)==1 ; // chech ap[5]==1
		if (recieve_data_ready)
		{	
			Y = reg_user_Y_output ;
			reg_mprj_datal = Y<<16 ; // be careful about overflow
			recieve_complete = 1 ;
		}
		
	}
	
}
	


	//print("\n");
	//print("Monitor: Test 1 Passed\n\n");	// Makes simulation very long!
	// End of test 
	reg_mprj_datal = 0xAB510000;
}

