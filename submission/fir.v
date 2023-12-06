`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  reg                      arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  reg                      rvalid, 
    output  reg  [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  reg                      ss_tready, 
    input   wire                     sm_tready, 
    output  reg                      sm_tvalid,  
    output  reg  [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  reg  [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  reg  [(pDATA_WIDTH-1):0] tap_Di,
    output  reg  [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg  [3:0]               data_WE,
    output  wire                     data_EN,
    output  reg  [(pDATA_WIDTH-1):0] data_Di,
    output  reg [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


    // write your code here!
    reg   [2:0]                ap_reg;
    reg   [31:0]               data_length_reg;
    reg                        Xn_ready, Yn_ready;
    wire  hey;
    
    // tap RAM wire to get coefficient based on AXI Lite 
    reg  [(pDATA_WIDTH-1):0] tap_Do_dff;

    // data RAM wire to get input based on AXI Stream
    reg  [(pADDR_WIDTH-1):0] data_A_dff;
    reg  [(pDATA_WIDTH-1):0] data_Do_dff;

    // calculate
    reg [9:0] data_out_cnt, next_data_out_cnt; 
    reg [3:0] data_acc_cnt, next_data_acc_cnt;
    reg [3:0] tap_addr_cnt, next_tap_addr_cnt;
    reg [3:0] wait_data_cnt, next_wait_data_cnt;
    reg [31:0] mul_x, mul_h;
    reg [31:0] psum, next_psum;


    // ===== phase FSM ====
    parameter SETUP=2'd0, STREAMIN_WAIT=2'd1, EXECUTION=2'd2, STREAMOUT_WAIT=2'd3;
    //CHECK=2'd2;
    reg [1:0] curr_state, next_state;

    always @ (*) begin
        next_state = curr_state;
        next_data_out_cnt = data_out_cnt;
        next_data_acc_cnt = data_acc_cnt;
        next_tap_addr_cnt = tap_addr_cnt;
        next_wait_data_cnt = wait_data_cnt;
        case(curr_state)
            SETUP: begin
                if (ap_reg == 3'b101) begin
                    next_state = STREAMIN_WAIT;
                end
                else begin
                    if (awaddr == 12'h40) begin
                        next_wait_data_cnt = wait_data_cnt + 2'd1;
                    end
                    else if (awaddr == 12'h0 && wait_data_cnt != 0) begin
                        next_wait_data_cnt = wait_data_cnt + 2'd1;
                        if (wait_data_cnt == 10) next_wait_data_cnt = 0;
                    end
                    else begin
                        next_wait_data_cnt = wait_data_cnt;
                    end
                end
            end
            STREAMIN_WAIT: begin
                next_state = (ss_tvalid && ss_tready) ? EXECUTION : STREAMIN_WAIT;
            end
            EXECUTION: begin
                next_wait_data_cnt = wait_data_cnt + 2'd1;
                if (data_out_cnt <= 10'd10) begin
                    // next_state = (wait_data_cnt == data_out_cnt + 2) ? STREAMOUT_WAIT : EXECUTION;
                    if (data_out_cnt == data_acc_cnt) begin
                        next_data_acc_cnt = data_acc_cnt;
                        // next_data_acc_cnt = 4'd0;
                        next_state = EXECUTION;
                        // next_state = STREAMOUT_WAIT;
                        next_wait_data_cnt = wait_data_cnt + 2'd1;
                        // next_wait_data_cnt = 0;
                        if (wait_data_cnt == data_out_cnt + 2) begin
                            next_data_acc_cnt = 4'd0;
                            next_state = STREAMOUT_WAIT;
                            next_wait_data_cnt = 0;
                        end
                    end
                    else begin
                        next_data_acc_cnt = data_acc_cnt + 4'd1;
                        next_state = EXECUTION;
                        next_wait_data_cnt = wait_data_cnt + 2'd1;
                        // next_wait_data_cnt = wait_data_cnt;
                    end
                end
                else if (data_out_cnt > 10'd10) begin
                    // next_data_acc_cnt = (data_acc_cnt == 4'd10) ? 
                    //                     (wait_data_cnt == 4'd12) ? 4'd0 : data_acc_cnt : 
                    //                     data_acc_cnt + 4'd1;
                    next_data_acc_cnt = (wait_data_cnt == 4'd12) ? 4'd0 : 
                                        (data_acc_cnt == 4'd10) ? data_acc_cnt : 
                                        data_acc_cnt + 4'd1;
                    next_wait_data_cnt = (wait_data_cnt == 4'd12) ? 0 : wait_data_cnt + 4'd1;
                    // next_state = (data_acc_cnt == 4'd10) ? STREAMOUT_WAIT : EXECUTION;
                    next_state = (wait_data_cnt == 4'd12) ? STREAMOUT_WAIT : EXECUTION;
                    if (tap_addr_cnt == 4'd0) begin
                        next_tap_addr_cnt = 4'd10;
                        if (wait_data_cnt > 4'd10) begin
                            next_tap_addr_cnt = tap_addr_cnt;
                        end
                    end
                    else begin
                        next_tap_addr_cnt = tap_addr_cnt - 4'd1;
                    end
                end
            end
            STREAMOUT_WAIT: begin
                next_state = (sm_tready && sm_tvalid) ? 
                             (data_out_cnt == data_length_reg -1) ? SETUP : STREAMIN_WAIT : 
                             STREAMOUT_WAIT;
                next_data_out_cnt = (sm_tvalid && sm_tready) ? 
                                    (data_out_cnt == data_length_reg -1) ? 0 : data_out_cnt + 10'd1 : data_out_cnt;
            end
        endcase
    end 
    
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            curr_state <= SETUP;
            data_out_cnt <= 10'd0;
            data_acc_cnt <= 4'd0;
            psum <= 32'd0;
            tap_addr_cnt <= 4'd0;
            wait_data_cnt <= 0;
        end
        else begin
            curr_state <= next_state;
            data_out_cnt <= next_data_out_cnt;
            data_acc_cnt <= next_data_acc_cnt;
            tap_addr_cnt <= next_tap_addr_cnt;
            wait_data_cnt <= next_wait_data_cnt;
            psum <= next_psum;
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
                if (ap_reg[2] == 1'b1 && ap_reg[0] == 1'b0) ap_reg <= {ap_reg[2], 1'b0, wdata[0]};
                else if (ap_reg[0] == 1'b1) ap_reg <= {1'b0, ap_reg[1:0]};
            end
            else if (awaddr == 12'h10) begin
                // ap_reg          <= ap_reg;
                data_length_reg <= wdata;
            end
        end
        else if (curr_state == STREAMIN_WAIT) begin
            if (ss_tvalid && ss_tready && ap_reg[0] == 1) begin
                ap_reg <= {2'd0, 1'd0};
            end else begin
                ap_reg <= ap_reg;
            end
        end
        else if (curr_state == EXECUTION) begin
            ap_reg          <= ap_reg;
            data_length_reg <= data_length_reg;
        end
        else if (curr_state == STREAMOUT_WAIT) begin
            if (data_out_cnt == data_length_reg -1 && sm_tready && sm_tvalid) begin
                ap_reg <= {1'b1,1'b1,ap_reg[0]};
            end
        end
    end

    // stream in and stream out ready signal put in ap control register
    always @(*) begin
        Xn_ready = (curr_state == STREAMIN_WAIT);
        Yn_ready = (curr_state == STREAMOUT_WAIT);
    end

    //controll rdata to check by testbench, include three ap control in addr 12'h00 and tap parameter at 12'd32 ~ 12'd72
    //rdata relate with rvalid is high and arvalid, araddr, rready prepared from testbench
    always @(*) begin
        case(curr_state)
            SETUP: begin
                rdata = (rvalid && araddr >= 12'h40) ? tap_Do : 32'd0;
            end
            STREAMIN_WAIT: begin
                rdata = (rvalid && araddr == 12'h00) ? {26'b0, Yn_ready, Xn_ready, 1'b0, ap_reg[2:0]} : 32'd0;
            end
            default: rdata = 0;
        endcase
    end
    // control tap, ap read signal: arvalid, araddr, rready is controlled by testbench &&
    //                              arready, rvalid controlled by us
    always @(*) begin
        if (curr_state == SETUP) begin
            arready = (awaddr >= 12'h40 && araddr >= 12'h40) ? arvalid : 1'd0;
        end
        else begin
            arready = (arvalid);
        end
    end
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            rvalid  <= 1'd0;
        end
        else begin
            rvalid  <= 1'd0;
            if (araddr >= 12'h40  || araddr >= 12'h00) begin
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
    assign hey     = (curr_state == SETUP && wdata != 1) ? 1'd1 : 1'd0;
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
                    tap_A = (awaddr == 12'h40) ? 11'd0 : 
                            (awaddr == 12'h44) ? 11'd4 :
                            (awaddr == 12'h48) ? 11'd8 :
                            (awaddr == 12'h4c) ? 11'd12 :
                            (awaddr == 12'h50) ? 11'd16 :
                            (awaddr == 12'h54) ? 11'd20 :
                            (awaddr == 12'h58) ? 11'd24 :
                            (awaddr == 12'h5c) ? 11'd28 :
                            (awaddr == 12'h60) ? 11'd32 :
                            (awaddr == 12'h64) ? 11'd36 :
                            (awaddr == 12'h68) ? 11'd40 : 11'd0;
                end 
                else begin
                    tap_Di = 32'd0;
                    tap_A = (araddr == 12'h40) ? 11'd0 : 
                            (araddr == 12'h44) ? 11'd4 :
                            (araddr == 12'h48) ? 11'd8 :
                            (araddr == 12'h4c) ? 11'd12 :
                            (araddr == 12'h50) ? 11'd16 :
                            (araddr == 12'h54) ? 11'd20 :
                            (araddr == 12'h58) ? 11'd24 :
                            (araddr == 12'h5c) ? 11'd28 :
                            (araddr == 12'h60) ? 11'd32 :
                            (araddr == 12'h64) ? 11'd36 :
                            (araddr == 12'h68) ? 11'd40 : 11'd0;
                end
            end
            // read tap from tap RAM to compute
            EXECUTION: begin
                tap_WE = 4'b0000;
                if (wait_data_cnt >= 2'd0) begin
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
    assign sm_tlast = (data_out_cnt == data_length_reg -1 && sm_tready && sm_tvalid) ? 1'b1 : 1'b0;
    always @(*) begin
        if (curr_state == STREAMOUT_WAIT) begin
            sm_tdata = psum;
        end
        else begin
            sm_tdata = 0;
        end
    end
    always @ (posedge axis_clk) begin
        if (!axis_rst_n) begin
            ss_tready <= 1'b0;
            sm_tvalid <= 1'b0;
        end
        else if (curr_state == STREAMIN_WAIT) begin
            ss_tready <= (ss_tvalid) ? 1'b0 : 1'b1;
            sm_tvalid <= 1'b0;
        end
        else if (curr_state == STREAMOUT_WAIT) begin
            ss_tready <= 1'b0;
            sm_tvalid <= 1'b1;
        end
        else begin
            ss_tready <= 1'b0;
            sm_tvalid <= 1'b0;
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
                if (awaddr == 12'h40 || wait_data_cnt != 0) begin
                    data_WE = 4'b1111;
                    data_A = wait_data_cnt << 2'd2;
                    data_Di = 0;
                end
            end
            STREAMIN_WAIT: begin
                if (ss_tvalid && ss_tready) begin
                    data_Di = $signed(ss_tdata);
                    data_A = (data_out_cnt % 11) << 2'd2;
                    data_WE = 4'b1111;
                end
            end
            EXECUTION: begin
                // data_WE = (ss_tready) ? 4'b1111 : 4'b0000;
                data_WE = 4'b0000;
                if (wait_data_cnt >= 2'd0) begin
                    if (data_out_cnt <= 10'd10) begin
                        data_A = data_acc_cnt << 2'd2;
                        data_Di = 0;
                    end
                    else if (data_out_cnt > 10'd10) begin
                        data_Di = 0;
                        
                        if (data_acc_cnt == 4'd0) begin
                            data_A = (data_out_cnt % 11) << 2'd2;
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
            STREAMIN_WAIT: begin
                next_psum = 0;
            end
            EXECUTION: begin
                mul_x = data_Do_dff;
                mul_h = tap_Do_dff;
                next_psum = mul_x * mul_h + psum;
            end
        endcase
    end    
endmodule
