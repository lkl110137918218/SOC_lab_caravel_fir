#ifndef __FIR_H__
#define __FIR_H__
#include <defs.h>
#define N 64

// int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[N];
// int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
int outputsignal[N];

#define reg_user_ap_signal (*(volatile uint32_t *)0x30000000)
#define reg_user_data_length (*(volatile uint32_t *)0x30000010)


#define reg_user_tap_0 (*(volatile uint32_t *)0x30000040)
#define reg_user_tap_1 (*(volatile uint32_t *)0x30000044)
#define reg_user_tap_2 (*(volatile uint32_t *)0x30000048)
#define reg_user_tap_3 (*(volatile uint32_t *)0x3000004c)
#define reg_user_tap_4 (*(volatile uint32_t *)0x30000050)
#define reg_user_tap_5 (*(volatile uint32_t *)0x30000054)
#define reg_user_tap_6 (*(volatile uint32_t *)0x30000058)
#define reg_user_tap_7 (*(volatile uint32_t *)0x3000005c)
#define reg_user_tap_8 (*(volatile uint32_t *)0x30000060)
#define reg_user_tap_9 (*(volatile uint32_t *)0x30000064)
#define reg_user_tap_10 (*(volatile uint32_t *)0x30000068)

#define reg_user_X_input (*(volatile uint32_t *)0x30000080)

#define reg_user_Y_output (*(volatile uint32_t *)0x30000084)

#endif
