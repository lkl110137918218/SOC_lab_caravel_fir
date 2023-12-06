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

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
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
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;
    
    // AXI LITE WRITE
    wire              awready;
    wire              wready;
    reg               awvalid;
    reg  [11:0]       awaddr;
    reg               wvalid;
    reg  [(BITS-1):0] wdata;

    // AXI LITE READ
    wire              arready;
    reg               rready;
    reg               arvalid;
    reg  [11:0]       araddr;
    wire              rvalid; 
    wire [(BITS-1):0] rdata;

    // AXI STREAM send to FIR
    reg                ss_tvalid;  
    reg  [(BITS-1):0]  ss_tdata; 
    reg                ss_tlast; 
    wire               ss_tready; 

    // AXI STREAM receive from FIR
    reg                sm_tready; 
    wire               sm_tvalid; 
    wire  [(BITS-1):0] sm_tdata; 
    wire               sm_tlast; 

    // bram for tap RAM
    wire  [3:0]        tap_WE;
    wire               tap_EN;
    wire  [(BITS-1):0] tap_Di;
    wire  [11:0]       tap_A;
    wire  [(BITS-1):0] tap_Do;

    // bram for data RAM
    wire [3:0]        data_WE;
    wire              data_EN;
    wire [(BITS-1):0] data_Di;
    wire [11:0]       data_A;
    wire [(BITS-1):0] data_Do;



    wire [BITS-1:0] count;
    wire [31:0] la_write;

    wire [3:0] bram_we;
    wire [BITS-1:0] bram_addr;
    wire [BITS-1:0] bram_Do; 
    wire [BITS-1:0] bram_Di;


    reg  [3:0] delay_cnt;

    wire valid;
    reg ready;
    wire [1:0] decoded;

    // Wishbone Slave ports (WB MI A) for BRAM
    reg wbs_stb_bram_i;
    reg wbs_cyc_bram_i;
    reg wbs_we_bram_i;
    reg [3:0] wbs_sel_bram_i;
    reg [31:0] wbs_dat_bram_i;
    reg [31:0] wbs_adr_bram_i;
    wire wbs_ack_bram_o;
    wire [31:0] wbs_dat_bram_o;

    // Wishbone Slave ports (WB MI A) for AXI
    reg wbs_stb_axi_i;
    reg wbs_cyc_axi_i;
    reg wbs_we_axi_i;
    reg [3:0] wbs_sel_axi_i;
    reg [31:0] wbs_dat_axi_i;
    reg [31:0] wbs_adr_axi_i;
    reg wbs_ack_axi_o;
    reg [31:0] wbs_dat_axi_o;

    // wbs_adr_i decode, which is used to select WB_AXI or exmem_FIR 
    // User Project Memory Starting: 3800_0000
    // User Project FIR Base Address : 3000_0000

    assign decoded = (wbs_adr_i[31:20] == 12'h380) ? 2'b01 : 
                     (wbs_adr_i[31:20] == 12'h300) ? 2'b10 : 2'b00;
    
    always @(*) begin
        case(decoded)
            2'b01: begin
                wbs_stb_bram_i = wbs_stb_i;
                wbs_cyc_bram_i = wbs_cyc_i;
                wbs_we_bram_i  = wbs_we_i;
                wbs_sel_bram_i = wbs_sel_i;
                wbs_dat_bram_i = wbs_dat_i;
                wbs_adr_bram_i = wbs_adr_i;

                wbs_stb_axi_i  = 1'b0;
                wbs_cyc_axi_i  = 1'b0;
                wbs_we_axi_i   = 1'b0;
                wbs_sel_axi_i  = 4'd0;
                wbs_dat_axi_i  = 32'd0;
                wbs_adr_axi_i  = 32'd0;

                wbs_ack_o      = wbs_ack_bram_o;
                wbs_dat_o      = wbs_dat_bram_o;
            end
            2'b10: begin
                wbs_stb_bram_i = 1'b0;
                wbs_cyc_bram_i = 1'b0;
                wbs_we_bram_i  = 1'b0;
                wbs_sel_bram_i = 4'd0;
                wbs_dat_bram_i = 32'd0;
                wbs_adr_bram_i = 32'd0;

                wbs_stb_axi_i  = wbs_stb_i;
                wbs_cyc_axi_i  = wbs_cyc_i;
                wbs_we_axi_i   = wbs_we_i;
                wbs_sel_axi_i  = wbs_sel_i;
                wbs_dat_axi_i  = wbs_dat_i;
                wbs_adr_axi_i  = wbs_adr_i;

                wbs_ack_o      = wbs_ack_axi_o;
                wbs_dat_o      = wbs_dat_axi_o;
            end
            default: begin
                wbs_stb_bram_i = 1'b0;
                wbs_cyc_bram_i = 1'b0;
                wbs_we_bram_i  = 1'b0;
                wbs_sel_bram_i = 4'd0;
                wbs_dat_bram_i = 32'd0;
                wbs_adr_bram_i = 32'd0;

                wbs_stb_axi_i  = 1'b0;
                wbs_cyc_axi_i  = 1'b0;
                wbs_we_axi_i   = 1'b0;
                wbs_sel_axi_i  = 4'd0;
                wbs_dat_axi_i  = 32'd0;
                wbs_adr_axi_i  = 32'd0;

                wbs_ack_o      = 1'b0;
                wbs_dat_o      = 32'd0;
            end
        endcase
    end

     // WB MI A for BRAM
    assign valid = wbs_cyc_bram_i && wbs_stb_bram_i && (decoded == 2'b01); 
    assign bram_we = wbs_sel_bram_i & {4{wbs_we_bram_i}};
    assign bram_Di = wbs_dat_bram_i;
    assign wbs_dat_bram_o = bram_Do;
    assign wbs_ack_bram_o = ready;

    // WB for AXI LITE
    // ap_signal in 3000_0000, data_length in 3000_0010, tap in 3000_0040

    // WB for AXI STREAM
    // X_input in 3000_0080, Y_output in 3000_0084
    
    reg [3:0] curr_state, next_state;
    parameter IDLE=4'd0, 
              AXI_LITE_RADDR = 4'd1, AXI_LITE_RDATA = 4'd2, AXI_LITE_WRITE = 4'd3, 
              AXI_STREAM_IN = 4'd4, AXI_STREAM_OUT  = 4'd5;

    always @(posedge wb_clk_i) begin
        if(wb_rst_i) begin
            curr_state <= IDLE;
        end 
        else begin
            curr_state <= next_state;
        end
    end

    always @(*) begin
        case(curr_state)
            IDLE: begin
                if(wbs_cyc_axi_i && wbs_stb_axi_i && (decoded == 2'b10)) begin
                    if (wbs_adr_axi_i[15:0] == 16'h80) begin
                        next_state = AXI_STREAM_IN;
                    end else if (wbs_adr_axi_i[15:0] == 16'h84) begin
                        next_state = AXI_STREAM_OUT;
                    end else if (wbs_we_axi_i) begin
                        // next_state = AXI_LITE_WADDR;
                        next_state = AXI_LITE_WRITE;
                    end else begin
                        next_state = AXI_LITE_RADDR;
                    end                                      
                end else begin
                    next_state = IDLE;
                end    
            end
            AXI_LITE_WRITE: begin;
                next_state = (wbs_ack_axi_o) ? IDLE : AXI_LITE_WRITE;
            end
            AXI_LITE_RADDR: begin
                next_state = (wbs_ack_axi_o) ? AXI_LITE_RDATA : AXI_LITE_RADDR;
            end
            AXI_LITE_RDATA: begin
                next_state = (wbs_ack_axi_o) ? IDLE : AXI_LITE_RDATA;
            end
            AXI_STREAM_IN: begin
                next_state = (wbs_ack_axi_o) ? IDLE : AXI_STREAM_IN;
            end
            AXI_STREAM_OUT: begin
                next_state = (wbs_ack_axi_o) ? IDLE : AXI_STREAM_OUT;
            end
            default: begin
                next_state = curr_state;
            end
        endcase
    end

    always @(*) begin
        //axi write addr
        awvalid = (curr_state == AXI_LITE_WRITE) ? 1 : 0;
        awaddr  = (awvalid == 1) ? wbs_adr_axi_i[11:0] : 0;
        
        //axi write data
        wvalid = (curr_state == AXI_LITE_WRITE) ? 1 : 0;
        wdata  = (wvalid == 1) ? wbs_dat_axi_i : 0;

        //axi read addr
        arvalid = (curr_state == AXI_LITE_RADDR) ? 1 : 0;
        araddr  = (curr_state == AXI_LITE_RADDR) ? wbs_adr_axi_i[11:0] : 0;

        //axi read rdata
        rready = (curr_state == AXI_LITE_RDATA) ? 1 : 0;

        //axi stream in
        ss_tvalid = (curr_state == AXI_STREAM_IN) ? 1 : 0;
        ss_tdata  = (curr_state == AXI_STREAM_IN) ? wbs_dat_axi_i : 0;
        // ss_tlast = (curr_state == AXI_STREAM_IN) ? 1 : 0;

        //axi stream out
        sm_tready = (curr_state == AXI_STREAM_OUT) ? sm_tvalid : 0;
    end


    always @(*) begin
        wbs_ack_axi_o = 0;
        // if (curr_state == AXI_LITE_WRITE)        wbs_ack_axi_o = (awready | wvalid)  && wready;
        if (curr_state == AXI_LITE_WRITE)        wbs_ack_axi_o = wvalid;
        else if (curr_state == AXI_LITE_RADDR)   wbs_ack_axi_o = arready;
        else if (curr_state == AXI_LITE_RDATA)   wbs_ack_axi_o = rvalid;
        else if (curr_state == AXI_STREAM_IN)    wbs_ack_axi_o = ss_tready;
        else if (curr_state == AXI_STREAM_OUT)   wbs_ack_axi_o = sm_tvalid;
    end

    always @(*) begin
        wbs_dat_axi_o = 0;
        if (curr_state == AXI_LITE_RDATA && rvalid)  wbs_dat_axi_o = rdata;
        else if (curr_state == AXI_STREAM_OUT)       wbs_dat_axi_o = sm_tdata;
    end     


    // IO
    assign io_out = count;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;
       
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            ready <= 1'b0;
            delay_cnt <= 16'b0;
        end else begin
            ready <= 1'b0;
            if ( valid && !ready ) begin
                if ( delay_cnt == DELAYS ) begin
                    delay_cnt <= 16'b0;
                    ready <= 1'b1;
                end else begin
                    delay_cnt <= delay_cnt + 1;
                end
            end
        end
    end

    bram user_bram (
        .CLK(wb_clk_i),
        .WE0(bram_we),
        .EN0(valid),
        .Di0(bram_Di),
        .Do0(bram_Do),
        .A0(wbs_adr_bram_i)
    );



    fir fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid), 
        .rdata(rdata),    
        .ss_tvalid(ss_tvalid), 
        .ss_tdata(ss_tdata), 
        .ss_tlast(ss_tlast), 
        .ss_tready(ss_tready), 
        .sm_tready(sm_tready), 
        .sm_tvalid(sm_tvalid), 
        .sm_tdata(sm_tdata), 
        .sm_tlast(sm_tlast), 
        
        // bram for tap RAM
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // bram for data RAM
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(wb_clk_i),
        .axis_rst_n(~wb_rst_i)
    );

    bram11 tap_ram (
        .clk(wb_clk_i),
        .we(tap_WE[0]),
        .re(tap_EN),
        .waddr((tap_A>>2)),
        .raddr((tap_A>>2)),
        .wdi(tap_Di),
        .rdo(tap_Do)
    );

    bram11 data_ram (
        .clk(wb_clk_i),
        .we(data_WE[0]),
        .re(data_EN),
        .waddr((data_A>>2)),
        .raddr((data_A>>2)),
        .wdi(data_Di),
        .rdo(data_Do)
    );




endmodule



`default_nettype wire

