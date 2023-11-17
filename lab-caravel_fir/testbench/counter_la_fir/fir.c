#include "fir.h"

void __attribute__((section(".mprjram"))) initfir()
{
	// initial your fir
	data_len = 64;
	// reg_mprj_datal = 0x00A50000;
	// faster
	tap0 = 0;
	tap1 = -10;
	tap2 = -9;
	tap3 = 23;
	tap4 = 56;
	tap5 = 63;
	tap6 = 56;
	tap7 = 23;
	tap8 = -9;
	tap9 = -10;
	tapA = 0;

	return;
}

int *__attribute__((section(".mprjram"))) fir()
{
	initfir();
	int ans;
	AP = 1;

	// start timer
	reg_mprj_datal = (0xA5 << 16);

	// write down your fir
	for (int i = 0; i < 64; i++)
	{
		while ((AP >> 4) & 1 != 1)
		{
		} // wait until Xn [4] is ready
		Xn = i;
		while ((AP >> 5) & 1 != 1)
		{
		} // wait until Yn [5] is ready
		outputsignal[i] = Yn;
	}

	// output to mprj[31:24], and stop timer
	reg_mprj_datal = ((outputsignal[63] & 0xFF) << 24) | (0x5A << 16);

	return outputsignal;
}

// #include "fir.h"

// void __attribute__((section(".mprjram"))) initfir()
// {

// 	// initial your fir

// 	reg_user_tap_0 = 0;
// 	reg_mprj_datal = 0x00A50000;
// 	reg_user_tap_1 = -10;
// 	reg_user_tap_2 = -9;
// 	reg_user_tap_3 = 23;
// 	reg_user_tap_4 = 56;
// 	reg_user_tap_5 = 63;
// 	reg_user_tap_6 = 56;
// 	reg_user_tap_7 = 23;
// 	reg_user_tap_8 = -9;
// 	reg_user_tap_9 = -10;
// 	reg_user_tap_10 = 0;

// 	reg_user_data_length = 64;
// 	// reg_mprj_datal = 0x00A50000;
// }

// int *__attribute__((section(".mprjram"))) fir()
// {
// 	initfir();
// 	// reg_mprj_datal = 0x00A50000;

// 	reg_user_ap_signal = 0x00000001;

// 	// RISC-V outputs a StartMark ‘hA5 on mprj [23:16] to notify Testbench to start latency timer (in testbench)
// 	reg_mprj_datal = 0x00A50000;

// 	// write down your fir
// 	for (int i = 0; i < 64; i++)
// 	{
// 		while ((reg_user_ap_signal >> 4) & 1 != 1)
// 		{
// 		} // wait until X[n] [4] is ready to accept input
// 		reg_user_X_input = i;
// 		while ((reg_user_ap_signal >> 5) & 1 != 1)
// 		{
// 		} // wait until Y[n] [5] is ready to read
// 		outputsignal[i] = reg_user_Y_output;
// 	}

// 	// When finish, write final Y[7:0] to mprj [31:24], EndMark (‘h5A mprj [23:16]), record the latency timer
// 	reg_mprj_datal = ((outputsignal[63] & 0xFF) << 24) | (0x5A << 16);

// 	return outputsignal;
// }
