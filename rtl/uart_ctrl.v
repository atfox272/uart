module uart_ctrl #(
    parameter INTERNAL_CLOCK        = 125000000,
    
    // Memory Mapping
    parameter ATX_BASE_ADDR         = 32'h2000_0000,    // Base address of the IP in AXI Bus
    // Capac
    parameter UART_TX_FIFO_DEPTH    = 2,                // SCCB TX FIFO depth (element's width = 8bit)
    parameter UART_RX_FIFO_DEPTH    = 2,                // SCCB RX FIFO depth (element's width = 8bit)
    // AXI4 Bus Configuration
    parameter ATX_DATA_W            = 8,
    parameter ATX_ADDR_W            = 32,
    parameter ATX_ID_W              = 5,
    parameter ATX_LEN_W             = 8,
    parameter ATX_SIZE_W            = 3,
    parameter ATX_RESP_W            = 2,

    parameter DATA_WIDTH            = 8,
    parameter FIFO_DEPTH            = 32,
    
    parameter BAUDRATE_MUX_INDEX_MSB= 7,
    parameter BAUDRATE_MUX_INDEX_LSB= 5,
    parameter BAUDRATE_MUX_W        = BAUDRATE_MUX_INDEX_MSB - BAUDRATE_MUX_INDEX_LSB + 1,
    
    parameter STOP_BIT_OPTION_MSB   = 4,       
    parameter STOP_BIT_OPTION_LSB   = 4,       
    parameter STOP_BIT_OPTION_W     = STOP_BIT_OPTION_MSB - STOP_BIT_OPTION_LSB + 1,
    
    parameter PARITY_OPTION_MSB     = 3,
    parameter PARITY_OPTION_LSB     = 2,
    parameter PARITY_OPTION_LSB_W   = PARITY_OPTION_MSB - PARITY_OPTION_LSB + 1,
    
    parameter DATA_OPTION_MSB       = 1,
    parameter DATA_OPTION_LSB       = 0,
    parameter DATA_OPTION_W         = DATA_OPTION_MSB - DATA_OPTION_LSB + 1
    
) (
    input                       clk,
    input                       rst_n,
    // UART interface    
    input                       RX,
    output                      TX,
    // AXI4 Interface
    // -- -- AW channel         
    input   [ATX_ID_W-1:0]      s_awid_i,
    input   [ATX_ADDR_W-1:0]    s_awaddr_i,
    input   [1:0]               s_awburst_i,
    input   [ATX_LEN_W-1:0]     s_awlen_i,
    input                       s_awvalid_i,
    output                      s_awready_o,
    // -- -- W channel          
    input   [ATX_DATA_W-1:0]    s_wdata_i,
    input                       s_wlast_i,
    input                       s_wvalid_i,
    output                      s_wready_o,
    // -- -- B channel          
    output  [ATX_ID_W-1:0]      s_bid_o,
    output  [ATX_RESP_W-1:0]    s_bresp_o,
    output                      s_bvalid_o,
    input                       s_bready_i,
    // -- -- AR channel         
    input   [ATX_ID_W-1:0]      s_arid_i,
    input   [ATX_ADDR_W-1:0]    s_araddr_i,
    input   [1:0]               s_arburst_i,
    input   [ATX_LEN_W-1:0]     s_arlen_i,
    input                       s_arvalid_i,
    output                      s_arready_o,
    // -- -- R channel          
    output  [ATX_ID_W-1:0]      s_rid_o,
    output  [ATX_DATA_W-1:0]    s_rdata_o,
    output  [ATX_RESP_W-1:0]    s_rresp_o,
    output                      s_rlast_o,
    output                      s_rvalid_o,
    input                       s_rready_i
    
);
    // Baudrate generator TX
    wire                                baudrate_clk_en_tx;
    wire                                transaction_en_tx;
    // Baudrate generator RX
    wire                                baudrate_clk_en_rx;
    wire                                transaction_en_rx;
    // FIFO interface TX 
    wire [DATA_WIDTH - 1:0]             data_in_tx;
    wire                                fifo_tx_rd;
    wire                                fifo_tx_wr;
    wire                                fifo_tx_empty;
    wire                                fifo_tx_full;
    wire                                tx_data_vld;
    wire                                tx_data_rdy;
    // FIFO interface RX
    wire [DATA_WIDTH - 1:0]             data_out_rx;
    wire [DATA_WIDTH - 1:0]             data_out_fifo;
    wire                                fifo_rx_rd;
    wire                                fifo_rx_wr;
    wire                                fifo_rx_empty;
    wire                                fifo_rx_full;
    // Configuration register 
    wire [BAUDRATE_MUX_W - 1:0]         baudrate_mux_tx;
    wire [BAUDRATE_MUX_W - 1:0]         baudrate_mux_rx;
    wire [DATA_OPTION_W - 1:0]          data_width_option_tx;
    wire [DATA_OPTION_W - 1:0]          data_width_option_rx;
    wire [STOP_BIT_OPTION_W - 1:0]      stop_bit_option_tx;
    wire [STOP_BIT_OPTION_W - 1:0]      stop_bit_option_rx;
    wire [PARITY_OPTION_LSB_W - 1:0]    parity_option_tx;
    wire [PARITY_OPTION_LSB_W - 1:0]    parity_option_rx;
    // Register Map
    uc_regmap #(
        .ATX_BASE_ADDR  (ATX_BASE_ADDR),
        .UART_TX_FIFO_DEPTH (UART_TX_FIFO_DEPTH),
        .UART_RX_FIFO_DEPTH (UART_RX_FIFO_DEPTH),
        .ATX_DATA_W     (ATX_DATA_W),
        .ATX_ADDR_W     (ATX_ADDR_W),
        .ATX_ID_W       (ATX_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W)
    ) regmap (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_awid_i       (s_awid_i),
        .s_awaddr_i     (s_awaddr_i),
        .s_awburst_i    (s_awburst_i),
        .s_awlen_i      (s_awlen_i),
        .s_awvalid_i    (s_awvalid_i),
        .s_awready_o    (s_awready_o),
        .s_wdata_i      (s_wdata_i),
        .s_wlast_i      (s_wlast_i),
        .s_wvalid_i     (s_wvalid_i),
        .s_wready_o     (s_wready_o),
        .s_bid_o        (s_bid_o),
        .s_bresp_o      (s_bresp_o),
        .s_bvalid_o     (s_bvalid_o),
        .s_bready_i     (s_bready_i),
        .s_arid_i       (s_arid_i),
        .s_araddr_i     (s_araddr_i),
        .s_arburst_i    (s_arburst_i),
        .s_arlen_i      (s_arlen_i),
        .s_arvalid_i    (s_arvalid_i),
        .s_arready_o    (s_arready_o),
        .s_rid_o        (s_rid_o),
        .s_rdata_o      (s_rdata_o),
        .s_rresp_o      (s_rresp_o),
        .s_rlast_o      (s_rlast_o),
        .s_rvalid_o     (s_rvalid_o),
        .s_rready_i     (s_rready_i),
        .baud_mux_tx    (baudrate_mux_tx),
        .baud_mux_rx    (baudrate_mux_rx),
        .data_len_tx    (data_width_option_tx),
        .data_len_rx    (data_width_option_rx),
        .stop_len_tx    (stop_bit_option_tx),
        .stop_len_rx    (stop_bit_option_rx),
        .parity_tx      (parity_option_tx),
        .parity_rx      (parity_option_rx),
        .tx_data        (data_in_tx),
        .tx_data_vld    (tx_data_vld),
        .tx_data_rdy    (tx_data_rdy),
        .rx_data        (data_out_rx),
        .rx_vld         (fifo_rx_wr),
        .rx_rdy         () // Can be overflow
    );
    // TX controller
    uc_tx #(
        .DATA_WIDTH (DATA_WIDTH)
    ) tx_ctrl (
        .clk(clk),
        .TX(TX),
        // FIFO interconnect
        .data_in_tx     (data_in_tx),
        .fifo_available (tx_data_vld),
        .fifo_rd        (tx_data_rdy),
        .baudrate_clk_en(baudrate_clk_en_tx),
        .transaction_en (transaction_en_tx),
        // Configuration
        .data_width_option(data_width_option_tx),
        .stop_bit_option(stop_bit_option_tx),
        .parity_option  (parity_option_tx),
        .rst_n          (rst_n)
    );
    // RX controller
    uc_rx #(
        .DATA_WIDTH (DATA_WIDTH)
    ) rx_ctrl (
        .clk(clk),
        .RX(RX),
        .data_out_rx(data_out_rx),
        .fifo_wr    (fifo_rx_wr),
        .baudrate_clk_en(baudrate_clk_en_rx),
        .transaction_en(transaction_en_rx),
        .valid_data_flag(),
        // Configuration
        .data_width_option(data_width_option_rx),
        .stop_bit_option(stop_bit_option_rx),
        .parity_option(parity_option_rx),
        .rst_n(rst_n)
    );
    // TX Baudrate generator
    uc_baud_gen #(
        .INTERNAL_CLOCK(INTERNAL_CLOCK),
        .GENERATE_BD_4TX(1'b1)
    ) tx_baud_gen (
        .clk(clk),
        // controller interconnect 
        .transaction_en(transaction_en_tx),
        .baudrate_clk_en(baudrate_clk_en_tx),
        // Configuration
        .baudrate_mux(baudrate_mux_tx),
        
        .rst_n(rst_n)
    );
    // RX Baudrate generator
    uc_baud_gen #(
        .INTERNAL_CLOCK(INTERNAL_CLOCK),
        .GENERATE_BD_4TX(1'b0)
    ) rx_baud_gen (
        .clk(clk),
        // controller interconnect 
        .baudrate_clk_en(baudrate_clk_en_rx),
        .transaction_en(transaction_en_rx),
        // Configuration
        .baudrate_mux(baudrate_mux_rx),
        .rst_n(rst_n)
    );     
endmodule
