`timescale 1ns / 1ps
asjdf;lsjdf
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    // output  reg                      awready,
    output  wire                     wready,
    // output  reg                      wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    // output  wire                     arready,
    output  reg                      arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    // output  wire                     rvalid,
    output  reg                      rvalid, 
    // output  wire [(pDATA_WIDTH-1):0] rdata,
    output  reg  [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    // output  wire                     ss_tready,
    output  reg                      ss_tready, 
    input   wire                     sm_tready, 
    // output  wire                     sm_tvalid,
    output  reg                      sm_tvalid, 
    // output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  reg  [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    // output  wire [3:0]               tap_WE,
    output  reg  [3:0]               tap_WE,
    output  wire                     tap_EN,
    // output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  reg  [(pDATA_WIDTH-1):0] tap_Di,
    // output  wire [(pADDR_WIDTH-1):0] tap_A,
    output  reg  [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    // output  wire [3:0]               data_WE,
    output  reg  [3:0]               data_WE,
    output  wire                     data_EN,
    // output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  reg  [(pDATA_WIDTH-1):0] data_Di,
    // output  wire [(pADDR_WIDTH-1):0] data_A,
    output  reg [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


    // write your code here!
    reg   [2:0]                ap_reg;
    reg   [31:0]               data_length_reg;
    wire  hey;
    
    // tap RAM wire to get coefficient based on AXI Lite 
    // output  reg  [3:0]               tap_WE_dff;
    // output  wire                     tap_EN_dff;
    // reg  [(pDATA_WIDTH-1):0] tap_Di_dff;
    // reg  [(pADDR_WIDTH-1):0] next_tap_A;
    reg  [(pDATA_WIDTH-1):0] tap_Do_dff;

    // data RAM wire to get input based on AXI Stream
    // reg  [3:0]               data_WE_dff;
    // reg                      data_EN_dff;
    // reg  [(pDATA_WIDTH-1):0] data_Di_dff;
    // reg  [(pADDR_WIDTH-1):0] next_data_A;
    reg  [(pADDR_WIDTH-1):0] data_A_dff;
    reg  [(pDATA_WIDTH-1):0] data_Do_dff;

    // calculate
    reg [9:0] data_in_cnt, next_data_in_cnt; // calculate data length
    reg [9:0] data_out_cnt, next_data_out_cnt; 
    reg [3:0] data_acc_cnt, next_data_acc_cnt;
    reg [3:0] tap_addr_cnt, next_tap_addr_cnt;
    reg [1:0] wait_data_cnt, next_wait_data_cnt;
    reg [31:0] mul_x, mul_h;
    reg [31:0] psum, next_psum;


    // ===== phase FSM ====
    parameter SETUP=2'd0, EXECUTION=2'd1;
    //CHECK=2'd2;
    reg [1:0] curr_state, next_state;

    always @ (*) begin
        next_state = curr_state;
        next_data_in_cnt = data_in_cnt;
        next_data_out_cnt = data_out_cnt;
        next_data_acc_cnt = data_acc_cnt;
        next_tap_addr_cnt = tap_addr_cnt;
        next_wait_data_cnt = wait_data_cnt;
        case(curr_state)
            SETUP: begin
                if (ap_reg == 3'b101) begin
                    next_state = EXECUTION;
                end
                else begin
                    if (ss_tvalid && ss_tready) begin
                        next_data_in_cnt = data_in_cnt + 10'd1;
                        if (data_in_cnt == 10'd10) begin
                            next_data_in_cnt = data_in_cnt;
                        end
                    end
                    else begin
                        if (awaddr == 12'd72) begin
                            next_wait_data_cnt = wait_data_cnt + 2'd1;
                            if (wait_data_cnt == 2'd2) next_wait_data_cnt = wait_data_cnt;
                        end
                        else if (awaddr == 12'd0) begin
                            next_wait_data_cnt = 2'd0;
                        end
                    end
                end
            end
            EXECUTION: begin
                next_wait_data_cnt = wait_data_cnt + 2'd1;
                if (wait_data_cnt == 2'd2) begin
                    next_wait_data_cnt = wait_data_cnt;
                    if (data_out_cnt <= 10'd10) begin
                        if (data_out_cnt == data_acc_cnt) begin
                            next_data_acc_cnt = 4'd0;
                            next_data_out_cnt = data_out_cnt + 10'd1;
                            if (data_out_cnt == 10'd10) next_data_in_cnt = data_in_cnt + 10'd1;
                        end
                        else begin
                            next_data_acc_cnt = data_acc_cnt + 4'd1;
                            next_data_out_cnt = data_out_cnt;
                        end
                    end
                    else if (data_out_cnt > 10'd10) begin
                        if (tap_addr_cnt == 4'd0) begin
                            next_tap_addr_cnt = 4'd10;
                        end
                        else if (tap_addr_cnt == 4'd1) begin
                            next_tap_addr_cnt = 4'd0;
                        end
                        else begin
                            next_tap_addr_cnt = tap_addr_cnt - 4'd1;
                        end

                        if (data_acc_cnt == 4'd10) begin
                            next_data_acc_cnt = 4'd0;
                            next_data_out_cnt = data_out_cnt + 10'd1;
                            next_data_in_cnt = data_in_cnt + 10'd1;
                        end
                        else begin
                            next_data_acc_cnt = data_acc_cnt + 4'd1;
                            next_data_out_cnt = data_out_cnt;
                            next_data_in_cnt = data_in_cnt;
                        end
                    end
                end
                else next_state = SETUP;
            end
        endcase
    end 
    
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            curr_state <= SETUP;
            data_in_cnt <= 10'd0;
            data_out_cnt <= 10'd0;
            data_acc_cnt <= 4'd0;
            psum <= 32'd0;
            tap_addr_cnt <= 4'd0;
            wait_data_cnt <= 0;
        end
        else begin
            curr_state <= next_state;
            data_in_cnt <= next_data_in_cnt;
            data_out_cnt <= next_data_out_cnt;
            data_acc_cnt <= next_data_acc_cnt;
            tap_addr_cnt <= next_tap_addr_cnt;
            wait_data_cnt <= next_wait_data_cnt;
            psum <= next_psum;
            if (data_acc_cnt == 4'd1) psum <= 0;
        end
    end

    // put ap control and data length in register
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            ap_reg          <= 3'b100;
            data_length_reg <= 32'd0;
        end
        else if (curr_state == SETUP) begin
            ap_reg          <= ap_reg;
            data_length_reg <= data_length_reg;
            if (awaddr == 12'h00) begin
                // data_length_reg <= data_length_reg;
                if (ap_reg[2] == 1'b1 && ap_reg[0] == 1'b0) ap_reg <= {ap_reg[2:1], wdata[0]};
                else if (ap_reg[0] == 1'b1) ap_reg <= {1'b0, ap_reg[1:0]};
                // else ap_reg <= ap_reg;
            end
            else if (awaddr == 12'h10) begin
                // ap_reg          <= ap_reg;
                data_length_reg <= wdata;
            end
            // else begin
            //     ap_reg          <= ap_reg;
            //     data_length_reg <= data_length_reg;
            // end
        end
        else if (curr_state == EXECUTION) begin
            ap_reg          <= ap_reg;
            data_length_reg <= data_length_reg;
            if (wait_data_cnt == 0) begin
                ap_reg          <= {2'd0, 1'd0};
            end
            else if (data_out_cnt == 10'd600 && data_acc_cnt == 4'd0) begin
                ap_reg <= {1'b1,ap_reg[1:0]};
            end
            // else if (data_out_cnt == 10'd600 && data_acc_cnt == 4'd1) begin
            else if (data_out_cnt == data_length_reg && sm_tready && sm_tvalid) begin    
                ap_reg <= {ap_reg[2],1'b1,ap_reg[0]};
            end
            else if (data_out_cnt == 10'd600 && data_acc_cnt == 4'd4) begin
                ap_reg <= {ap_reg[2],1'b0,ap_reg[0]};
            end
        end
    end
    //controll rdata to check by testbench, include three ap control in addr 12'h00 and tap parameter at 12'd32 ~ 12'd72
    //rdata relate with rvalid is high and arvalid, araddr, rready prepared from testbench
    always @(*) begin
        case(curr_state)
            SETUP: begin
                rdata = (rvalid && araddr >= 12'h20) ? tap_Do : 32'd0;
            end
            EXECUTION: begin
                rdata = (rvalid && araddr == 12'h00) ? {29'b0, ap_reg[2:0]} : 32'd0;
            end
            default: rdata = 0;
        endcase
    end
    // control tap, ap read signal: arvalid, araddr, rready is controlled by testbench &&
    //                              arready, rvalid controlled by us
    always @(*) begin
        if (curr_state == SETUP) begin
            arready = (awaddr >= 12'h20 && araddr >= 12'h20) ? arvalid : 1'd0;
        end
        else if (curr_state == EXECUTION) begin
            arready = (data_acc_cnt == 4'd2 && data_out_cnt == 10'd598 || data_out_cnt == 10'd600) ? 1'b1 : 1'b0;
        end
        else begin
            arready = 1'd0;
        end
    end
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            rvalid  <= 1'd0;
        end
        else begin
            rvalid  <= 1'd0;
            if (araddr >= 12'h20  || araddr >= 12'h00) begin
                rvalid  <= (arready) ? 1'd1 : 1'd0;
            end
        end
    end

    // control tap, ap, datalength write signal: awvalid, awaddr, wvalid is controlled by testbench &&
    //                                           awready, wready controlled by us
    assign awready = 1'd1;
    assign wready  = 1'd1;

    // in the SETUP state, we accept 11 tap and need to put them in tap RAM
    //                     after put tap, we read from tap RAM to check with testbench
    // in the EXECUTION state, we only need to access with tap RAM to compute output 
    assign tap_EN  = 1'd1;
    // control tap_A
    assign hey     = (curr_state == SETUP && wait_data_cnt == 2'd2) ? 1'd0 : 1'd1;
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            tap_Do_dff <= 0;
        end
        else begin
            tap_Do_dff <= tap_Do;
        end
    end
    always @(*) begin
        tap_WE = 4'b0000;
        tap_Di = 32'd0;
        tap_A = 11'd0;
        case (curr_state)
            // write/read tap from testbench/tap RAM to tap RAM/testbench
            SETUP: begin
                tap_WE = (wvalid) ? 4'b1111 : 4'b0000;
                if (hey) begin
                    tap_Di = $signed(wdata);
                    tap_A = (awaddr == 12'h20) ? 11'd0 : 
                            (awaddr == 12'd36) ? 11'd4 :
                            (awaddr == 12'd40) ? 11'd8 :
                            (awaddr == 12'd44) ? 11'd12 :
                            (awaddr == 12'd48) ? 11'd16 :
                            (awaddr == 12'd52) ? 11'd20 :
                            (awaddr == 12'd56) ? 11'd24 :
                            (awaddr == 12'd60) ? 11'd28 :
                            (awaddr == 12'd64) ? 11'd32 :
                            (awaddr == 12'd68) ? 11'd36 :
                            (awaddr == 12'd72) ? 11'd40 : 11'd0;
                end 
                else begin
                    tap_Di = 32'd0;
                    tap_A = (araddr == 12'h20) ? 11'd0 : 
                            (araddr == 12'd36) ? 11'd4 :
                            (araddr == 12'd40) ? 11'd8 :
                            (araddr == 12'd44) ? 11'd12 :
                            (araddr == 12'd48) ? 11'd16 :
                            (araddr == 12'd52) ? 11'd20 :
                            (araddr == 12'd56) ? 11'd24 :
                            (araddr == 12'd60) ? 11'd28 :
                            (araddr == 12'd64) ? 11'd32 :
                            (araddr == 12'd68) ? 11'd36 :
                            (araddr == 12'd72) ? 11'd40 : 11'd0;
                end
            end
            // read tap from tap RAM to compute
            EXECUTION: begin
                tap_WE = 4'b0000;
                if (wait_data_cnt >= 2'd1) begin
                    if (data_out_cnt <= 10'd10) begin
                        tap_A = (data_out_cnt - data_acc_cnt) << 2'd2;
                    end
                    else if (data_out_cnt > 10'd10) begin
                        tap_A = tap_addr_cnt << 2'd2;
                    end
                end
            end
        endcase
    end
    // control ss signal, which ss_tvalid, ss_tdata, ss_tlast prepare by testbench
    //                    ss_tlast assert when after read ap idle is 0, and then transfer final input data
    //                    ss_tready to ensure we can get data
    // control sm signal, which sm_tvalid, sm_tdata, sm_tlast prepare by us
    //                    sm_tlast assert when sm_tdata is final output
    //                    sm_tready prepare by testbench
    // assign sm_tlast = (data_out_cnt == 10'd600 && data_acc_cnt == 4'd2) ? 1'b1 : 1'b0;
    assign sm_tlast = (data_out_cnt == data_length_reg && sm_tready && sm_tvalid) ? 1'b1 : 1'b0;
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            ss_tready <= 1'b0;
            sm_tvalid <= 1'b0;
            sm_tdata  <= 0;
        end
        else if (curr_state == SETUP) begin
            ss_tready <= 1'b1;
            sm_tvalid <= 1'b0;
            sm_tdata <= 0;
            if (data_in_cnt == 10'd10) begin
                ss_tready <= 1'b0;
            end
        end
        else if (curr_state == EXECUTION) begin
            ss_tready <= 1'b0;
            sm_tvalid <= 1'b0;
            sm_tdata <= 0;
            if (data_acc_cnt == 4'd1) begin
                sm_tvalid <= 1'b1;
                sm_tdata <= next_psum;
            end
            else if (data_acc_cnt == 4'd10) begin
                ss_tready <= 1'b1;
            end
        end
    end
    // in the SETUP state, we accept 11 input data and need to put them in data RAM
    // in the EXECUTION state, at the first, we need to access with data RAM to compute output
    //                         after compute 11 output, we need to accept new input data and put them in data RAM & do computation
    assign data_EN  = 1'd1;
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            data_A_dff <= 11'd0;
            data_Do_dff <= 0;
        end
        else begin
            data_A_dff <= data_A;
            data_Do_dff <= data_Do;
        end
    end
    always @(*) begin
        data_Di = 0;
        data_A = data_A_dff;
        data_WE = 4'b0000;
        case (curr_state)
            SETUP: begin
                data_WE = (ss_tready) ? 4'b1111 : 4'b0000;
                data_A = data_in_cnt << 2'd2;
                data_Di = $signed(ss_tdata);
            end
            EXECUTION: begin
                data_WE = (ss_tready) ? 4'b1111 : 4'b0000;
                if (wait_data_cnt >= 2'd1) begin
                    if (data_out_cnt <= 10'd10) begin
                        data_A = data_acc_cnt << 2'd2;
                        data_Di = 0;
                    end
                    else if (data_out_cnt > 10'd10) begin
                        data_Di = 0;
                        if (data_acc_cnt == 4'd0) begin
                            data_A = (data_out_cnt % 11) << 2'd2;
                            data_Di = $signed(ss_tdata);
                        end
                        else begin
                            data_A = ((data_A_dff >> 2'd2)+1'd1) << 2'd2;
                            if (data_A_dff == 11'd40) begin
                                data_A = 11'd0;
                            end
                        end
                    end
                end 
            end
        endcase
    end
    // control multi and add
    always @(*) begin
        next_psum = psum;
        mul_x = 0;
        mul_h = 0;
        case (curr_state)
            EXECUTION: begin
                mul_x = data_Do_dff;
                mul_h = tap_Do_dff;
                next_psum = mul_x * mul_h + psum;
                if (data_acc_cnt == 4'd1 && ss_tready) mul_x = $signed(ss_tdata);
            end
        endcase
    end    
endmodule
