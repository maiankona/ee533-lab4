`timescale 1ns/1ps

module ids 
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,
      
      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

      // --- Misc
      input                               reset,
      input                               clk
   );

   // --- Signals ---
   wire [DATA_WIDTH-1:0]         in_fifo_data;
   wire [CTRL_WIDTH-1:0]         in_fifo_ctrl;
   wire                          in_fifo_nearly_full;
   wire                          in_fifo_empty;
   reg                           in_fifo_rd_en;
   reg                           out_wr_int;

   // 32-bit Register Definitions
   reg [31:0]                    pattern_high;
   reg [31:0]                    pattern_low;
   reg [31:0]                    ids_cmd;
   reg [31:0]                    matches;

   reg [1:0]                     state, state_next;
   reg [31:0]                    matches_next;
   reg                           in_pkt_body, in_pkt_body_next;
   reg                           end_of_pkt, end_of_pkt_next;
   reg                           begin_pkt, begin_pkt_next;
   reg [2:0]                     header_counter, header_counter_next;

   localparam START = 2'b00;
   localparam HEADER = 2'b01;
   localparam PAYLOAD = 2'b10;

   // --- Manual Register Logic (Replaces generic_regs) ---
   wire reg_vld = reg_req_in && reg_src_in[UDP_REG_SRC_WIDTH-1];
   wire reg_src_sel = (reg_addr_in[`UDP_REG_ADDR_WIDTH-1:4] == `IDS_BLOCK_ADDR);

   reg [31:0] reg_data_out_int;
   reg        reg_ack_out_int;

   always @(*) begin
      reg_data_out_int = 32'h0;
      reg_ack_out_int  = 1'b0;
      if (reg_vld && reg_src_sel) begin
         reg_ack_out_int = 1'b1;
         case (reg_addr_in[3:0])
            4'h0 : reg_data_out_int = pattern_high;
            4'h4 : reg_data_out_int = pattern_low;
            4'h8 : reg_data_out_int = ids_cmd;
            4'hc : reg_data_out_int = matches;
            default : reg_data_out_int = 32'hdeadbeef;
         endcase
      end
   end

   // Write Logic for Software Registers
   always @(posedge clk) begin
      if (reset) begin
         pattern_high <= 32'h0;
         pattern_low  <= 32'h0;
         ids_cmd      <= 32'h0;
      end else if (reg_vld && reg_src_sel && !reg_rd_wr_L_in) begin
         case (reg_addr_in[3:0])
            4'h0 : pattern_high <= reg_data_in;
            4'h4 : pattern_low  <= reg_data_in;
            4'h8 : ids_cmd      <= reg_data_in;
         endcase
      end
   end

   // --- Assignments & Modules ---
   assign in_rdy       = !in_fifo_nearly_full;
   assign matcher_en   = in_pkt_body;
   assign matcher_ce   = (!in_fifo_empty && out_rdy);
   assign matcher_reset = (reset || ids_cmd[0] || end_of_pkt);

   fallthrough_small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2)) 
   input_fifo (.din({in_ctrl, in_data}), .wr_en(in_wr), .rd_en(in_fifo_rd_en),
               .dout({in_fifo_ctrl, in_fifo_data}), .full(), .nearly_full(in_fifo_nearly_full),
               .empty(in_fifo_empty), .reset(reset), .clk(clk));

   detect7B matcher (.ce(matcher_ce), .match_en(matcher_en), .clk(clk),
                     .pipe1({in_fifo_ctrl, in_fifo_data}), .hwregA({pattern_high, pattern_low}),
                     .match(matcher_match), .mrst(matcher_reset));

   dropfifo drop_fifo (.clk(clk), .drop_pkt(matcher_match && end_of_pkt), .fiforead(out_rdy),
                       .fifowrite(out_wr_int), .firstword(begin_pkt), .in_fifo({in_fifo_ctrl,in_fifo_data}),
                       .lastword(end_of_pkt), .rst(reset), .out_fifo({out_ctrl,out_data}), .valid_data(out_wr));

   // --- State Machine Logic ---
   always @(*) begin
      state_next = state;
      matches_next = matches;
      header_counter_next = header_counter;
      in_fifo_rd_en = 0;
      out_wr_int = 0;
      end_of_pkt_next = end_of_pkt;
      in_pkt_body_next = in_pkt_body;
      begin_pkt_next = begin_pkt;
      
      if (!in_fifo_empty && out_rdy) begin
         out_wr_int = 1;
         in_fifo_rd_en = 1;
         case(state)
            START: begin
               if (in_fifo_ctrl != 0) begin
                  state_next = HEADER;
                  begin_pkt_next = 1;
                  end_of_pkt_next = 0;
               end
            end
            HEADER: begin
               begin_pkt_next = 0;
               if (in_fifo_ctrl == 0) begin
                  header_counter_next = header_counter + 1'b1;
                  if (header_counter_next == 3) state_next = PAYLOAD;
               end
            end
            PAYLOAD: begin
               if (in_fifo_ctrl != 0) begin
                  state_next = START;
                  header_counter_next = 0;
                  if (matcher_match) matches_next = matches + 1;
                  end_of_pkt_next = 1;
                  in_pkt_body_next = 0;
               end else begin
                  in_pkt_body_next = 1;
               end
            end
         endcase
      end
   end
   
   always @(posedge clk) begin
      if(reset) begin
         matches <= 0;
         header_counter <= 0;
         state <= START;
         begin_pkt <= 0;
         end_of_pkt <= 0;
         in_pkt_body <= 0;
      end else begin
         if (ids_cmd[0]) matches <= 0;
         else matches <= matches_next;
         header_counter <= header_counter_next;
         state <= state_next;
         begin_pkt <= begin_pkt_next;
         end_of_pkt <= end_of_pkt_next;
         in_pkt_body <= in_pkt_body_next;
      end
   end

   // --- Register Bus Passthrough ---
   assign reg_req_out = reg_req_in;
   assign reg_ack_out = reg_ack_out_int || reg_ack_in;
   assign reg_rd_wr_L_out = reg_rd_wr_L_in;
   assign reg_addr_out = reg_addr_in;
   assign reg_data_out = reg_ack_out_int ? reg_data_out_int : reg_data_in;
   assign reg_src_out  = reg_src_in;

endmodule