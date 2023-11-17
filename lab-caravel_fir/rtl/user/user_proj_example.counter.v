// // SPDX-FileCopyrightText: 2020 Efabless Corporation
// //
// // Licensed under the Apache License, Version 2.0 (the "License");
// // you may not use this file except in compliance with the License.
// // You may obtain a copy of the License at
// //
// //      http://www.apache.org/licenses/LICENSE-2.0
// //
// // Unless required by applicable law or agreed to in writing, software
// // distributed under the License is distributed on an "AS IS" BASIS,
// // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// // See the License for the specific language governing permissions and
// // limitations under the License.
// // SPDX-License-Identifier: Apache-2.0

// `default_nettype none
// /*
//  *-------------------------------------------------------------
//  *
//  * user_proj_example
//  *
//  * This is an example of a (trivially simple) user project,
//  * showing how the user project can connect to the logic
//  * analyzer, the wishbone bus, and the I/O pads.
//  *
//  * This project generates an integer count, which is output
//  * on the user area GPIO pads (digital output only).  The
//  * wishbone connection allows the project to be controlled
//  * (start and stop) from the management SoC program.
//  *
//  * See the testbenches in directory "mprj_counter" for the
//  * example programs that drive this user project.  The three
//  * testbenches are "io_ports", "la_test1", and "la_test2".
//  *
//  *-------------------------------------------------------------
//  */

// module user_proj_example #(
//     parameter BITS = 32,
//     parameter DELAYS=10
// )(
// `ifdef USE_POWER_PINS
//     inout vccd1,	// User area 1 1.8V supply
//     inout vssd1,	// User area 1 digital ground
// `endif

//     // Wishbone Slave ports (WB MI A)
//     input wb_clk_i,
//     input wb_rst_i,
//     input wbs_stb_i,
//     input wbs_cyc_i,
//     input wbs_we_i,
//     input [3:0] wbs_sel_i,
//     input [31:0] wbs_dat_i,
//     input [31:0] wbs_adr_i,
//     output reg wbs_ack_o,
//     output reg [31:0] wbs_dat_o,

//     // Logic Analyzer Signals
//     input  [127:0] la_data_in,
//     output [127:0] la_data_out,
//     input  [127:0] la_oenb,

//     // IOs
//     input  [`MPRJ_IO_PADS-1:0] io_in,
//     output [`MPRJ_IO_PADS-1:0] io_out,
//     output [`MPRJ_IO_PADS-1:0] io_oeb,

//     // IRQ
//     output [2:0] irq
// );
//     wire clk;
//     wire rst;

//     wire [`MPRJ_IO_PADS-1:0] io_in;
//     wire [`MPRJ_IO_PADS-1:0] io_out;
//     wire [`MPRJ_IO_PADS-1:0] io_oeb;
    
//     // AXI LITE WRITE
//     wire              awready;
//     wire              wready;
//     reg               awvalid;
//     reg  [11:0]       awaddr;
//     reg               wvalid;
//     reg  [(BITS-1):0] wdata;

//     // AXI LITE READ
//     wire              arready;
//     reg               rready;
//     reg               arvalid;
//     reg  [11:0]       araddr;
//     wire              rvalid; 
//     wire [(BITS-1):0] rdata;

//     // AXI STREAM send to FIR
//     reg                ss_tvalid;  
//     reg  [(BITS-1):0]  ss_tdata; 
//     reg                ss_tlast; 
//     wire               ss_tready; 

//     // AXI STREAM receive from FIR
//     reg                sm_tready; 
//     wire               sm_tvalid; 
//     wire  [(BITS-1):0] sm_tdata; 
//     wire               sm_tlast; 

//     // bram for tap RAM
//     wire  [3:0]        tap_WE;
//     wire               tap_EN;
//     wire  [(BITS-1):0] tap_Di;
//     wire  [11:0]       tap_A;
//     wire  [(BITS-1):0] tap_Do;

//     // bram for data RAM
//     wire [3:0]        data_WE;
//     wire              data_EN;
//     wire [(BITS-1):0] data_Di;
//     wire [11:0]       data_A;
//     wire [(BITS-1):0] data_Do;



//     wire [BITS-1:0] count;
//     wire [31:0] la_write;

//     wire [3:0] bram_we;
//     wire [BITS-1:0] bram_addr;
//     wire [BITS-1:0] bram_Do; 
//     wire [BITS-1:0] bram_Di;


//     reg  [3:0] delay_cnt;

//     wire valid;
//     reg ready;
//     wire [1:0] decoded;

//     // Wishbone Slave ports (WB MI A) for BRAM
//     reg wbs_stb_bram_i;
//     reg wbs_cyc_bram_i;
//     reg wbs_we_bram_i;
//     reg [3:0] wbs_sel_bram_i;
//     reg [31:0] wbs_dat_bram_i;
//     reg [31:0] wbs_adr_bram_i;
//     wire wbs_ack_bram_o;
//     wire [31:0] wbs_dat_bram_o;

//     // Wishbone Slave ports (WB MI A) for AXI
//     reg wbs_stb_axi_i;
//     reg wbs_cyc_axi_i;
//     reg wbs_we_axi_i;
//     reg [3:0] wbs_sel_axi_i;
//     reg [31:0] wbs_dat_axi_i;
//     reg [31:0] wbs_adr_axi_i;
//     reg wbs_ack_axi_o;
//     reg [31:0] wbs_dat_axi_o;

//     // wbs_adr_i decode, which is used to select WB_AXI or exmem_FIR 
//     assign decoded = (wbs_adr_i[31:20] == 12'h380) ? 2'b01 : 
//                      (wbs_adr_i[31:20] == 12'h300) ? 2'b10 : 2'b00;
    
//     always @(*) begin
//         case(decoded)
//             2'b01: begin
//                 wbs_stb_bram_i = wbs_stb_i;
//                 wbs_cyc_bram_i = wbs_cyc_i;
//                 wbs_we_bram_i  = wbs_we_i;
//                 wbs_sel_bram_i = wbs_sel_i;
//                 wbs_dat_bram_i = wbs_dat_i;
//                 wbs_adr_bram_i = wbs_adr_i;

//                 wbs_stb_axi_i  = 1'b0;
//                 wbs_cyc_axi_i  = 1'b0;
//                 wbs_we_axi_i   = 1'b0;
//                 wbs_sel_axi_i  = 4'd0;
//                 wbs_dat_axi_i  = 32'd0;
//                 wbs_adr_axi_i  = 32'd0;

//                 wbs_ack_o      = wbs_ack_bram_o;
//                 wbs_dat_o      = wbs_dat_bram_o;
//             end
//             2'b10: begin
//                 wbs_stb_bram_i = 1'b0;
//                 wbs_cyc_bram_i = 1'b0;
//                 wbs_we_bram_i  = 1'b0;
//                 wbs_sel_bram_i = 4'd0;
//                 wbs_dat_bram_i = 32'd0;
//                 wbs_adr_bram_i = 32'd0;

//                 wbs_stb_axi_i  = wbs_stb_i;
//                 wbs_cyc_axi_i  = wbs_cyc_i;
//                 wbs_we_axi_i   = wbs_we_i;
//                 wbs_sel_axi_i  = wbs_sel_i;
//                 wbs_dat_axi_i  = wbs_dat_i;
//                 wbs_adr_axi_i  = wbs_adr_i;

//                 wbs_ack_o      = wbs_ack_axi_o;
//                 wbs_dat_o      = wbs_dat_axi_o;
//             end
//             default: begin
//                 wbs_stb_bram_i = 1'b0;
//                 wbs_cyc_bram_i = 1'b0;
//                 wbs_we_bram_i  = 1'b0;
//                 wbs_sel_bram_i = 4'd0;
//                 wbs_dat_bram_i = 32'd0;
//                 wbs_adr_bram_i = 32'd0;

//                 wbs_stb_axi_i  = 1'b0;
//                 wbs_cyc_axi_i  = 1'b0;
//                 wbs_we_axi_i   = 1'b0;
//                 wbs_sel_axi_i  = 4'd0;
//                 wbs_dat_axi_i  = 32'd0;
//                 wbs_adr_axi_i  = 32'd0;

//                 wbs_ack_o      = 1'b0;
//                 wbs_dat_o      = 32'd0;
//             end
//         endcase
//     end

//      // WB MI A for BRAM
//     assign valid = wbs_cyc_bram_i && wbs_stb_bram_i && (decoded == 2'b01); 
//     assign bram_we = wbs_sel_bram_i & {4{wbs_we_bram_i}};
//     assign bram_Di = wbs_dat_bram_i;
//     assign wbs_dat_bram_o = bram_Do;
//     assign wbs_ack_bram_o = ready;

//     // User Project FIR Base Addr: 0x3000_0000
//     // WB --> axi-lite
//     // 3000_0000: AP
//     // 3000_0010: data_legnth
//     // 3000_0020: tap parameters


//     // WB --> axi-lstream
//     // 3000_0080: Xn
//     // 3000_0084: Yn
//     reg [3:0] curr_state, next_state;
//     parameter IDLE=4'd0, 
//               AXI_LITE_RADDR = 4'd1, AXI_LITE_RDATA = 4'd2, AXI_LITE_WRITE = 4'd3, 
//               AXI_STREAM_IN = 4'd4, AXI_STREAM_OUT  = 4'd5;

//     always @(posedge wb_clk_i) begin
//         if(wb_rst_i) begin
//             curr_state <= IDLE;
//         end 
//         else begin
//             curr_state <= next_state;
//             // case (curr_state)
//             //     IDLE : begin
//             //         if(wbs_cyc_axi_i && wbs_stb_axi_i && (decoded == 2'b10))begin
//             //             if (wbs_adr_axi_i[15:0] == 16'h80)           curr_state <= AXI_STREAM_IN;
//             //             else if (wbs_adr_axi_i[15:0] == 16'h84)      curr_state <= AXI_STREAM_OUT;
//             //             else if (wbs_we_axi_i)                      curr_state <= AXI_LITE_WRITE;
//             //             else                                        curr_state <= AXI_LITE_RADDR;
//             //         end else curr_state <= IDLE;
//             //     end
//             //     AXI_LITE_RADDR : curr_state <= (arready)   ? AXI_LITE_RDATA : AXI_LITE_RADDR;
//             //     AXI_STREAM_OUT  : curr_state <= (wbs_ack_axi_o) ? IDLE : AXI_STREAM_OUT;
//             //     AXI_LITE_RDATA : curr_state <= (wbs_ack_axi_o) ? IDLE : AXI_LITE_RDATA;
//             //     AXI_LITE_WRITE : curr_state <= (wbs_ack_axi_o) ? IDLE : AXI_LITE_WRITE;
//             //     AXI_STREAM_IN   : curr_state <= (wbs_ack_axi_o) ? IDLE : AXI_STREAM_IN;

//             //     default: curr_state <= IDLE;
//             // endcase
//         end
//     end

//     always @(*) begin
//         case(curr_state)
//             IDLE: begin
//                 if(wbs_cyc_axi_i && wbs_stb_axi_i && (decoded == 2'b10)) begin
//                     if (wbs_adr_axi_i[15:0] == 16'h80) begin
//                         next_state = AXI_STREAM_IN;
//                     end else if (wbs_adr_axi_i[15:0] == 16'h84) begin
//                         next_state = AXI_STREAM_OUT;
//                     end else if (wbs_we_axi_i) begin
//                         next_state = AXI_LITE_WRITE;
//                     end else begin
//                         next_state = AXI_LITE_RADDR;
//                     end                                         
//                 end 
//             end
//             AXI_LITE_WRITE: begin
//                 next_state = (wbs_ack_axi_o) ? IDLE : AXI_LITE_WRITE;
//             end
//             AXI_LITE_RADDR: begin
//                 next_state = (wbs_ack_axi_o) ? AXI_LITE_RDATA : AXI_LITE_RADDR;
//             end
//             AXI_LITE_RDATA: begin
//                 next_state = (wbs_ack_axi_o) ? IDLE : AXI_LITE_RDATA;
//             end
//             AXI_STREAM_IN: begin
//                 next_state = (wbs_ack_axi_o) ? IDLE : AXI_STREAM_IN;
//             end
//             AXI_STREAM_OUT: begin
//                 next_state = (wbs_ack_axi_o) ? IDLE : AXI_STREAM_OUT;
//             end
//             default: begin
//                 next_state = curr_state;
//             end
//         endcase
//     end

//     always @(*) begin
//         //axi write addr
//         awvalid = (curr_state == AXI_LITE_WRITE) ? 1 : 0;
//         awaddr  = (curr_state == AXI_LITE_WRITE) ? wbs_adr_axi_i[11:0] : 0;
//         //axi write data
//         wvalid = (curr_state == AXI_LITE_WRITE) ? 1 : 0;
//         wdata  = (wvalid == 1) ? wbs_dat_axi_i : 0;

//         //axi read addr
//         arvalid = (curr_state == AXI_LITE_RADDR ) ? 1 : 0;
//         araddr  = (curr_state == AXI_LITE_RADDR ) ? wbs_adr_axi_i[11:0] : 0;

//         //axi read rdata
//         rready = (curr_state == AXI_LITE_RDATA) ? 1 : 0;

//         //axi stream in
//         ss_tvalid = (curr_state == AXI_STREAM_IN) ? 1 : 0;
//         ss_tdata  = (ss_tvalid == 1) ? wbs_dat_axi_i : 0;
//         ss_tlast = (curr_state == AXI_STREAM_IN) ? 1 : 0;

//         //axi stream out
//         sm_tready = (curr_state == AXI_STREAM_OUT ) ? sm_tvalid : 0;
//     end


//     always @(*) begin
//         wbs_ack_axi_o = 0;
//         if (curr_state == AXI_LITE_WRITE )      wbs_ack_axi_o = wvalid;
//         else if (curr_state == AXI_LITE_RADDR ) wbs_ack_axi_o = arready;
//         else if (curr_state == AXI_LITE_RDATA)  wbs_ack_axi_o = rvalid;
//         else if (curr_state == AXI_STREAM_IN)    wbs_ack_axi_o = ss_tready;
//         else if (curr_state == AXI_STREAM_OUT)   wbs_ack_axi_o = sm_tvalid;
//     end

//     always @(*) begin
//         wbs_dat_axi_o = 0;
//         // if (curr_state == AXI_LITE_WRITE && wvalid )      wbs_dat_axi_o = wbs_dat_axi_i;
//         if (curr_state == AXI_LITE_RDATA && rvalid)  wbs_dat_axi_o = rdata;
//         // else if (curr_state == AXI_STREAM_IN)              wbs_dat_axi_o = wbs_dat_axi_i;
//         else if (curr_state == AXI_STREAM_OUT)             wbs_dat_axi_o = sm_tdata;
//     end     


//     // IO
//     assign io_out = count;
//     assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

//     // IRQ
//     assign irq = 3'b000;	// Unused

//     // LA
//     assign la_data_out = {{(127-BITS){1'b0}}, count};
//     // Assuming LA probes [63:32] are for controlling the count register  
//     assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
//     // Assuming LA probes [65:64] are for controlling the count clk & reset  
//     assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
//     assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;
       
//     always @(posedge wb_clk_i) begin
//         if (wb_rst_i) begin
//             ready <= 1'b0;
//             delay_cnt <= 16'b0;
//         end else begin
//             ready <= 1'b0;
//             if ( valid && !ready ) begin
//                 if ( delay_cnt == DELAYS ) begin
//                     delay_cnt <= 16'b0;
//                     ready <= 1'b1;
//                 end else begin
//                     delay_cnt <= delay_cnt + 1;
//                 end
//             end
//         end
//     end

//     bram user_bram (
//         .CLK(wb_clk_i),
//         .WE0(bram_we),
//         .EN0(valid),
//         .Di0(bram_Di),
//         .Do0(bram_Do),
//         .A0(wbs_adr_bram_i)
//     );



//     fir fir_DUT(
//         .awready(awready),
//         .wready(wready),
//         .awvalid(awvalid),
//         .awaddr(awaddr),
//         .wvalid(wvalid),
//         .wdata(wdata),
//         .arready(arready),
//         .rready(rready),
//         .arvalid(arvalid),
//         .araddr(araddr),
//         .rvalid(rvalid), 
//         .rdata(rdata),    
//         .ss_tvalid(ss_tvalid), 
//         .ss_tdata(ss_tdata), 
//         .ss_tlast(ss_tlast), 
//         .ss_tready(ss_tready), 
//         .sm_tready(sm_tready), 
//         .sm_tvalid(sm_tvalid), 
//         .sm_tdata(sm_tdata), 
//         .sm_tlast(sm_tlast), 
        
//         // bram for tap RAM
//         .tap_WE(tap_WE),
//         .tap_EN(tap_EN),
//         .tap_Di(tap_Di),
//         .tap_A(tap_A),
//         .tap_Do(tap_Do),

//         // bram for data RAM
//         .data_WE(data_WE),
//         .data_EN(data_EN),
//         .data_Di(data_Di),
//         .data_A(data_A),
//         .data_Do(data_Do),

//         .axis_clk(wb_clk_i),
//         .axis_rst_n(~wb_rst_i)
//     );

//     // bram tap_RAM (
//     //     .CLK(wb_clk_i),
//     //     .WE0(tap_WE),
//     //     .EN0(tap_EN),
//     //     .Di0(tap_Di),
//     //     .Do0(tap_Do),
//     //     .A0(tap_A)
//     // );

//     bram11 tap_ram (
//         .clk(wb_clk_i),
//         .we(tap_WE[0]),
//         .re(tap_EN),
//         .waddr(tap_A),
//         .raddr(tap_A),
//         .wdi(tap_Di),
//         .rdo(tap_Do)
//     );

//     // bram data_RAM (
//     //     .CLK(wb_clk_i),
//     //     .WE0(data_WE),
//     //     .EN0(data_EN),
//     //     .Di0(data_Di),
//     //     .Do0(data_Do),
//     //     .A0(data_A)
//     // );

//     bram11 data_ram (
//         .clk(wb_clk_i),
//         .we(data_WE[0]),
//         .re(data_EN),
//         .waddr(data_A),
//         .raddr(data_A),
//         .wdi(data_Di),
//         .rdo(data_Do)
//     );




// endmodule



// `default_nettype wire
// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype wire
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

// `include "/home/ubuntu/course-lab_4-2/rtl/user/fir.v"

`ifndef MPRJ_IO_PADS
    `define MPRJ_IO_PADS 32
`endif 

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS = 10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output reg wbs_ack_o,
    output reg [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output reg [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output reg [`MPRJ_IO_PADS-1:0] io_out,
    output reg [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output reg [2:0] irq
);
wire clk;
wire rst;

assign clk = wb_clk_i;
assign rst = wb_rst_i; // sync active-high reset

// wire [`MPRJ_IO_PADS-1:0] io_in;
// wire [`MPRJ_IO_PADS-1:0] io_out;
// wire [`MPRJ_IO_PADS-1:0] io_oeb;

// bram for tap RAM
wire  [3:0]         tap_WE;
wire                tap_EN;
wire  [(BITS-1):0]  tap_Di;
wire  [(BITS-1):0]  tap_A;
wire  [(BITS-1):0]  tap_Do;

// bram for data RAM
wire [3:0]          data_WE;
wire                data_EN;
wire [(BITS-1):0]   data_Di;
wire [(BITS-1):0]   data_A;
wire [(BITS-1):0]   data_Do;

// axi-lite: write
wire awready;
wire wready;
reg awvalid;
reg [(BITS-1):0] awaddr;
reg wvalid;
reg [(BITS-1):0] wdata;

// axi-lite: read
wire arready;
reg rready;
reg arvalid;
reg [(BITS-1):0] araddr;
wire rvalid;
wire [(BITS-1):0] rdata;

// axi-stream: send to fir
reg ss_tvalid;
reg [(BITS-1):0] ss_tdata;
reg ss_tlast;
wire ss_tready;

// axi-stream: receive from fir
reg sm_tready;
wire sm_tvalid;
wire [(BITS-1):0] sm_tdata;
wire sm_tlast;

// User Project Memroy: 0x3800_0000
wire [BITS-1:0] bram_do;
wire [BITS-1:0] bram_di;
wire [BITS-1:0] bram_adr;
wire bram_valid;
wire [3:0] bram_we;
reg bram_ack;
reg [(BITS-1):0] bram_dat;

//for AXI-lite

reg [3:0] c_state, n_state;
reg axi_ack;
reg [(BITS-1):0] axi_dat;

localparam IDLE = 0,
           AXI_RADDR = 1,
           AXI_RDATA = 2,
           AXI_WADDR = 3,
           AXI_SIN   = 5,
           AXI_SOUT  = 6,
           AXI_WDATA = 4;



// ===========================================DESIGN=======================================
// User Project Memroy: 0x3800_0000
assign bram_valid   = wbs_stb_i == 1 && wbs_cyc_i == 1 && wbs_adr_i[31:24] == 'h38;
assign bram_we      = {4{wbs_we_i & bram_valid}};
assign bram_adr     = (wbs_adr_i - 'h38000000) >> 2;
assign bram_di      = wbs_dat_i;

reg [15:0] counter; // why is this 16 bits

always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
        counter     <= 0;
        bram_ack   <= 0;
        bram_dat   <= 0;
    end else begin
        counter     <= (counter == DELAYS) ? 0 : (bram_valid == 1 && bram_ack != 1) ? counter + 1 : counter; 
        bram_ack   <= (counter == DELAYS) ? 1 : 0;
        bram_dat   <= (counter == DELAYS) ? bram_do : 0;
    end
end


// User Project FIR Base Addr: 0x3000_0000
// WB --> axi-lite
// 3000_0000: AP
// 3000_0010: data_legnth
// 3000_0040: tap parameters


// WB --> axi-lstream
// 3000_0080: Xn
// 3000_0084: Yn

always @( posedge clk ) begin
    if(rst) c_state <= IDLE;
    else begin
        case (c_state)
            IDLE : begin
                if(wbs_cyc_i && wbs_stb_i && wbs_adr_i[31:24] == 'h30)begin
                    if(wbs_adr_i == 'h3000_0084 )     c_state <= AXI_SOUT;
                    else if(wbs_adr_i == 'h3000_0080) c_state <= AXI_SIN;
                    else if (wbs_we_i)                c_state <= AXI_WADDR;
                    else                              c_state <= AXI_RADDR;
                end else c_state <= IDLE;
            end
            AXI_RADDR : c_state <= (arready)   ? AXI_RDATA : AXI_RADDR;
            AXI_WADDR : c_state <= (awready)   ? AXI_WDATA : AXI_WADDR;
            AXI_SOUT  : c_state <= (wbs_ack_o) ? IDLE : AXI_SOUT;
            AXI_RDATA : c_state <= (wbs_ack_o) ? IDLE : AXI_RDATA;
            AXI_WDATA : c_state <= (wbs_ack_o) ? IDLE : AXI_WDATA;
            AXI_SIN   : c_state <= (wbs_ack_o) ? IDLE : AXI_SIN;

            default: c_state <= IDLE;
        endcase
    end
end

always @(*) begin
    araddr  = (c_state == AXI_RADDR ) ? wbs_adr_i - 'h30000000 : 0;
    arvalid = (c_state == AXI_RADDR ) ? 1 : 0;

    awaddr  = (c_state == AXI_WADDR ) ? wbs_adr_i - 'h30000000 : 0;
    awvalid = (c_state == AXI_WADDR ) ? 1 : 0;

    //axi-rdata
    rready = (c_state == AXI_RDATA) ? 1 : 0;

    //axi-wdata
    wvalid = (c_state == AXI_WDATA && wready) ? 1 : 0;
    wdata  = (wvalid == 1) ? wbs_dat_i : 0;

    //axi_sin
    ss_tvalid = (c_state == AXI_SIN ) ? 1 : 0;
    ss_tdata  = (c_state == AXI_SIN) ? wbs_dat_i : 0;

    //axi_sout
    sm_tready = (c_state == AXI_SOUT ) ? sm_tvalid : 0;
end


always @(*) begin
    axi_ack = 0;
    if (c_state == AXI_RDATA)       axi_ack = rvalid;
    else if (c_state == AXI_WDATA ) axi_ack = wvalid;
    else if (c_state == AXI_SIN)    axi_ack = ss_tready;
    else if (c_state == AXI_SOUT)   axi_ack = sm_tvalid;
end

always @(*) begin
    axi_dat = 0;
    if (c_state == AXI_RDATA && rvalid)       axi_dat = rdata;
    else if (c_state == AXI_WDATA && wvalid ) axi_dat = wbs_dat_i;
    else if (c_state == AXI_SIN)              axi_dat = wbs_dat_i;
    else if (c_state == AXI_SOUT)             axi_dat = sm_tdata;
end


//wb_dat_o and wb_ack_o
always @(*) begin
    wbs_dat_o = bram_dat | axi_dat;
    wbs_ack_o = bram_ack | axi_ack;
end


bram user_bram (
    .CLK(wb_clk_i),
    .WE0(bram_we),
    .EN0(bram_valid),
    .Di0(bram_di),
    .Do0(bram_do),
    .A0(bram_adr)
);

fir FIR(
    // axi-lite: write addr
    .awready(awready),
    .awvalid(awvalid),
    .awaddr (awaddr ),

    // axi-lite: write data
    .wready(wready),
    .wvalid(wvalid),
    .wdata (wdata ),

    // axi-lite: read addr
    .arready(arready),
    .arvalid(arvalid),
    .araddr (araddr ),

    // axi-lite: read data
    .rready(rready),
    .rvalid(rvalid),
    .rdata (rdata ),

    // axi-stream: in
    .ss_tvalid(ss_tvalid),
    .ss_tdata (ss_tdata ),
    .ss_tlast (ss_tlast ),
    .ss_tready(ss_tready),

    // axi-stream: out
    .sm_tready(sm_tready),
    .sm_tvalid(sm_tvalid),
    .sm_tdata (sm_tdata ),
    .sm_tlast (sm_tlast ),

    // ram for tap
    .tap_WE(tap_WE),
    .tap_EN(tap_EN),
    .tap_Di(tap_Di),
    .tap_A (tap_A),
    .tap_Do(tap_Do),

    // ram for data
    .data_WE(data_WE),
    .data_EN(data_EN),
    .data_Di(data_Di),
    .data_A (data_A),
    .data_Do(data_Do),

    .axis_clk(clk),
    .axis_rst_n(~rst)
);

bram datRAM (
    .CLK(clk),
    .WE0(data_WE),
    .EN0(data_EN),
    .Di0(data_Di),
    .Do0(data_Do),
    .A0(data_A)
);

bram tapRAM (
    .CLK(clk),
    .WE0(tap_WE),
    .EN0(tap_EN),
    .Di0(tap_Di),
    .Do0(tap_Do),
    .A0(tap_A)
);


endmodule



`default_nettype wire