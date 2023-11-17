#ifndef __FIR_H__
#define __FIR_H__

#define N 11
#define LENGTH 600 

int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int length = LENGTH ;

int inputbuffer[N];
int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
int outputsignal[N];

int amplitude = 75 ;
int x[1] ;

int y ;

#endif