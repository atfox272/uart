`timescale 1ns/1ps

`define DUT_CLK_PERIOD  2
`define RST_DLY_START   3
`define RST_DUR         9

// `define CONF_MODE_ONLY
// `define WR_ST_MODE
// `define RD_ST_MODE 
// `define CUSTOMIZE_MODE

`define END_TIME        500000
module uart_ctrl_tb;

    // Parameters
    parameter INTERNAL_CLOCK        = 1_000_000;
    parameter ATX_BASE_ADDR         = 32'h2000_0000;    // Configuration registers region - BASE
    parameter UART_TX_FIFO_DEPTH    = 8;                // UART TX FIFO depth (element's width = 8bit)
    parameter UART_RX_FIFO_DEPTH    = 8;                // UART RX FIFO depth (element's width = 8bit)
    parameter ATX_DATA_W            = 8;
    parameter ATX_ADDR_W            = 32;
    parameter ATX_ID_W              = 5;
    parameter ATX_LEN_W             = 8;
    parameter ATX_SIZE_W            = 3;
    parameter ATX_RESP_W            = 2;
    
    // Signals
    // -- Global 
    logic                                   clk;
    logic                                   rst_n;
    // -- UART Master Interface
    logic                                   RX;
    logic                                   TX;
    // -- AXI4 Interface            
    // -- -- AW channel         
    logic   [ATX_ID_W-1:0]                  s_awid_i;
    logic   [ATX_ADDR_W-1:0]                s_awaddr_i;
    logic   [1:0]                           s_awburst_i;
    logic   [ATX_LEN_W-1:0]                 s_awlen_i;
    logic                                   s_awvalid_i;
    // -- -- W channel          
    logic   [ATX_DATA_W-1:0]                s_wdata_i;
    logic                                   s_wlast_i;
    logic                                   s_wvalid_i;
    // -- -- B channel          
    logic                                   s_bready_i;
    // -- -- AR channel         
    logic   [ATX_ID_W-1:0]                  s_arid_i;
    logic   [ATX_ADDR_W-1:0]                s_araddr_i;
    logic   [1:0]                           s_arburst_i;
    logic   [ATX_LEN_W-1:0]                 s_arlen_i;
    logic                                   s_arvalid_i;
    // -- -- R channel          
    logic                                   s_rready_i;
    // logic  declaration           
    // -- -- AW channel         
    logic                                   s_awready_o;
    // -- -- W channel          
    logic                                   s_wready_o;
    // -- -- B channel          
    logic   [ATX_ID_W-1:0]                  s_bid_o;
    logic   [ATX_RESP_W-1:0]                s_bresp_o;
    logic                                   s_bvalid_o;
    // -- -- AR channel         
    logic                                   s_arready_o;
    // -- -- R channel          
    logic   [ATX_ID_W-1:0]                  s_rid_o;
    logic   [ATX_DATA_W-1:0]                s_rdata_o;
    logic   [ATX_RESP_W-1:0]                s_rresp_o;
    logic                                   s_rlast_o;
    logic                                   s_rvalid_o;
    //
    assign RX = TX;
    
    // Instantiate the DUT (Device Under Test)
    uart_ctrl #(
        .INTERNAL_CLOCK(INTERNAL_CLOCK),
        .ATX_BASE_ADDR(ATX_BASE_ADDR),
        .UART_TX_FIFO_DEPTH(UART_TX_FIFO_DEPTH),
        .UART_RX_FIFO_DEPTH(UART_RX_FIFO_DEPTH),
        .ATX_DATA_W(ATX_DATA_W),
        .ATX_ADDR_W(ATX_ADDR_W),
        .ATX_ID_W(ATX_ID_W),
        .ATX_LEN_W(ATX_LEN_W),
        .ATX_SIZE_W(ATX_SIZE_W),
        .ATX_RESP_W(ATX_RESP_W)
    ) uut (
        .*
    );

    initial begin
        clk             <= 0;
        rst_n           <= 1;

        s_awid_i        <= 0;
        s_awaddr_i      <= 0;
        s_awvalid_i     <= 0;
        s_awlen_i       <= 0;
        
        s_wdata_i       <= 0;
        s_wlast_i       <= 0;
        s_wvalid_i      <= 0;
        
        s_bready_i      <= 1'b1;
        
        s_awid_i       <= 0;
        s_awaddr_i     <= 0;
        s_awvalid_i    <= 0;
        
        s_bready_i     <= 1'b1;
        
        s_arid_i       <= 0;
        s_araddr_i     <= 0;
        s_arvalid_i    <= 0;

        s_rready_i     <= 1'b1;

        #(`RST_DLY_START)   rst_n <= 0;
        #(`RST_DUR)         rst_n <= 1;
    end
    
    initial begin
        forever #(`DUT_CLK_PERIOD/2) clk <= ~clk;
    end
    
    initial begin : SIM_END
        #`END_TIME;
        $finish;
    end

    initial begin   : SEQUENCER_DRIVER
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            begin   : AW_chn
                // 1st: Request for CONFIG.TX
                s_aw_transfer(.s_awid(5'h00), .s_awaddr(32'h2000_0000), .s_awburst(2'b00), .s_awlen(8'd00));
                // 2nd: Request for CONFIG.RX
                s_aw_transfer(.s_awid(5'h00), .s_awaddr(32'h2000_0001), .s_awburst(2'b00), .s_awlen(8'd00));
                // 3rd: Request for TX_DATA
                s_aw_transfer(.s_awid(5'h00), .s_awaddr(32'h2000_0010), .s_awburst(2'b00), .s_awlen(8'd01));
                aclk_cl;
                s_awvalid_i <= 1'b0;
            end
            begin   : W_chn
                // 1st                B9600     STOP2B  NO_PAR  DATA8B          
                s_w_transfer(.s_wdata({3'd1,    1'd1,   2'd0,   2'd3}), .s_wlast(1'b1));
                // 2nd                B9600     STOP2B  NO_PAR  DATA8B          
                s_w_transfer(.s_wdata({3'd1,    1'd1,   2'd0,   2'd3}), .s_wlast(1'b1));
                // 3rd
                s_w_transfer(.s_wdata(8'h11), .s_wlast(1'b0));
                s_w_transfer(.s_wdata(8'hEE), .s_wlast(1'b1));
                aclk_cl;
                s_wvalid_i <= 1'b0;
            end
            begin   : AR_chn
                // // Request for RX_DATA
                s_ar_transfer(.s_arid(5'h00), .s_araddr(32'h2000_0020), .s_arburst(2'b00), .s_arlen(8'd01));
                aclk_cl;
                s_arvalid_i <= 1'b0;
            end
            begin: R_chn
                // Wrong request
                // TODO: monitor the response data
            end
        join_none
    end

    /*          UART monitor            */
    /*          UART monitor            */


    /*          AXI4 monitor            */
    initial begin   : AXI4_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            // begin   : AW_chn
            //     while(1'b1) begin
            //         wait(s_awready_o & s_awvalid_i); #0.1;  // AW hanshaking
            //         $display("\n---------- AW channel ----------");
            //         $display("AWID:     0x%8h", s_awid_i);
            //         $display("AWADDR:   0x%8h", s_awaddr_i);
            //         $display("AWLEN:    0x%8h", s_awlen_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end
            // end
            // begin   : W_chn
            //     while(1'b1) begin
            //         wait(s_wready_o & s_wvalid_i); #0.1;  // W hanshaking
            //         $display("\n---------- W channel ----------");
            //         $display("WDATA:    0x%8h", s_wdata_i);
            //         $display("WLAST:    0x%8h", s_wlast_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end
            // end
            begin   : B_chn
                while(1'b1) begin
                    wait(s_bready_i & s_bvalid_o); #0.1;  // B hanshaking
                    $display("\n---------- B channel ----------");
                    $display("BID:      0x%8h", s_bid_o);
                    $display("BRESP:    0x%8h", s_bresp_o);
                    $display("-------------------------------");
                    aclk_cl;
                end
            end
            // begin   : AR_chn
            //     while(1'b1) begin
            //         wait(s_arready_o & s_arvalid_i); #0.1;  // AR hanshaking
            //         $display("\n---------- AR channel ----------");
            //         $display("ARID:     0x%8h", s_arid_i);
            //         $display("ARADDR:   0x%8h", s_araddr_i);
            //         $display("ARLEN:    0x%8h", s_arlen_i);
            //         $display("-------------------------------");
            //         aclk_cl;
            //     end

            // end
            begin   : R_chn
                while(1'b1) begin
                    wait(s_rready_i & s_rvalid_o); #0.1;  // R hanshaking
                    $display("\n---------- R channel ----------");
                    $display("RDATA:    0x%8h", s_rdata_o);
                    $display("RRESP:    0x%8h", s_rresp_o);
                    $display("RLAST:    0x%8h", s_rlast_o);
                    $display("-------------------------------");
                    aclk_cl;
                end
            end
        join_none
    end
    /*          AXI4 monitor            */

   /* DeepCode */
    task automatic s_aw_transfer(
        input [ATX_ID_W-1:0]            s_awid,
        input [ATX_ADDR_W-1:0]          s_awaddr,
        input [1:0]                     s_awburst, 
        input [ATX_LEN_W-1:0]           s_awlen
    );
        aclk_cl;
        s_awid_i            <= s_awid;
        s_awaddr_i          <= s_awaddr;
        s_awburst_i         <= s_awburst;
        s_awlen_i           <= s_awlen;
        s_awvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_awready_o == 1'b1); #0.1;
    endtask

    task automatic s_w_transfer (
        input [ATX_DATA_W-1:0]  s_wdata,
        input               s_wlast
    );
        aclk_cl;
        s_wdata_i           <= s_wdata;
        s_wvalid_i          <= 1'b1;
        s_wlast_i           <= s_wlast;
        // Handshake occur
        wait(s_wready_o == 1'b1); #0.1;
    endtask

    task automatic s_ar_transfer(
        input [ATX_ID_W-1:0]            s_arid,
        input [ATX_ADDR_W-1:0]          s_araddr,
        input [1:0]                     s_arburst, 
        input [ATX_LEN_W-1:0]           s_arlen
    );
        aclk_cl;
        s_arid_i            <= s_arid;
        s_araddr_i          <= s_araddr;
        s_arburst_i         <= s_arburst;
        s_arlen_i           <= s_arlen;
        s_arvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_arready_o == 1'b1); #0.1;
    endtask

    task automatic aclk_cl;
        @(posedge clk);
        #0.2; 
    endtask
endmodule