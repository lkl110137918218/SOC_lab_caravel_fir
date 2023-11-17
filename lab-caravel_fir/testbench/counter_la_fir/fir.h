#ifndef __FIR_H__
#define __FIR_H__

#include <defs.h>

// User Project
#define AP (*(volatile uint32_t *)0x30000000)
#define data_len (*(volatile uint32_t *)0x30000010)

// User Project FIR Tap parameters
#define tap0 (*(volatile uint32_t *)0x30000040)
#define tap1 (*(volatile uint32_t *)0x30000044)
#define tap2 (*(volatile uint32_t *)0x30000048)
#define tap3 (*(volatile uint32_t *)0x3000004c)
#define tap4 (*(volatile uint32_t *)0x30000050)
#define tap5 (*(volatile uint32_t *)0x30000054)
#define tap6 (*(volatile uint32_t *)0x30000058)
#define tap7 (*(volatile uint32_t *)0x3000005c)
#define tap8 (*(volatile uint32_t *)0x30000060)
#define tap9 (*(volatile uint32_t *)0x30000064)
#define tapA (*(volatile uint32_t *)0x30000068)

#define Xn (*(volatile uint32_t *)0x30000080)
#define Yn (*(volatile uint32_t *)0x30000084)

int outputsignal[64];
#endif
// #ifndef __FIR_H__
// #define __FIR_H__
// #include <defs.h>
// #define N 64

// // int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
// int inputbuffer[N];
// // int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
// int outputsignal[N];

// #define reg_user_ap_signal (*(volatile uint32_t *)0x30000000)
// #define reg_user_data_length (*(volatile uint32_t *)0x30000010)

// #define reg_user_tap_0 (*(volatile uint32_t *)0x30000020)
// #define reg_user_tap_1 (*(volatile uint32_t *)0x30000024)
// #define reg_user_tap_2 (*(volatile uint32_t *)0x30000028)
// #define reg_user_tap_3 (*(volatile uint32_t *)0x3000002c)
// #define reg_user_tap_4 (*(volatile uint32_t *)0x30000030)
// #define reg_user_tap_5 (*(volatile uint32_t *)0x30000034)
// #define reg_user_tap_6 (*(volatile uint32_t *)0x30000038)
// #define reg_user_tap_7 (*(volatile uint32_t *)0x3000003c)
// #define reg_user_tap_8 (*(volatile uint32_t *)0x30000040)
// #define reg_user_tap_9 (*(volatile uint32_t *)0x30000044)
// #define reg_user_tap_10 (*(volatile uint32_t *)0x30000048)

// #define reg_user_X_input (*(volatile uint32_t *)0x30000080)

// #define reg_user_Y_output (*(volatile uint32_t *)0x30000084)

// #endif
