# Execute FIR code in user BRAM

## Objectives of this lab
Understand Caravel Testbench Structure, particularly, the relationship among
1. Firmware the c code runs on RISC V
2. Testbench the verilog top module which composes
   - Instance of Caravel design which includes user project
   - Spiflash which is loaded with firmware .hex file
   - Verilog code to interact with firmware/user project through mprj pins
3. User Projects

## Content of this lab
- Integrate Lab3 FIR & exmem FIR (Lab4 1) into Caravel user project area (add WB interface)
- Execute RISC V firmware (FIR) from user project memory
- Firmware to move data in/out FIR
- Optimize the performance by software/hardware co design

## Simulation for FIR
```sh
cd ~/caravel-soc_fpga-lab/lab-exmem-fir/testbench/counter_la_fir
source run_clean
source run_sim
```
