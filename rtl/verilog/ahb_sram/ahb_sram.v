// -------------------------------------------------------//
// File name    : ahb_sram.v
// Author       : Yangyf
// Email        :
// Project      :
// Created      :
//
// Description:
// 1: change ahb inf to SRAM r/w
// 2: To imprive timing, both r/w to SRAM are registered
// -------------------------------------------------------//

module ahb_sram(
    // --- ahb slave inf
    hsel        ,
    haddr       ,
    hburst      ,
    htrans      ,
    hsize       ,
    hprot       ,
    hwrite      ,
    hwdata      ,
    hready      ,
    hreadyout   ,
    hrdata      ,
    hresp       ,

    clk         ,
    rstn
);

parameter   mem_depth   = 1024  ;
parameter   mem_abit    = 10    ;
parameter   mem_dw      = 32    ;   // can't change this

input   wire            clk,rstn    ;

//--- AHB configure inf
input   wire            hsel    ;
input   wire    [(mem_abit+2-1):0]  haddr;
input   wire    [2:0]   hburst  ;   // support all burst type
input   wire    [1:0]   htrans  ;   // support htrans type
input   wire    [2:0]   hsize   ;   // support 8/16/32 bit trans
input   wire    [3:0]   hprot   ;   // ignored
input   wire            hwrite  ;
input   wire    [mem_dw-1:0]hwdata;
input   wire            hready  ;
output  wire            hreadyout;
output  reg     [31:0]  hrdata  ;
output  wire    [1:0]   hresp   ;

//---0: ahb bus inf gather ---//

parameter   [1:0]   T_IDLE = 'd0, T_BUSY = 'd1, T_NONS = 'd2, T_SEQ = 'd3;
parameter   [1:0]   R_OK = 'd0;

wire            bus_idle            ;
wire            bus_busy            ;
wire            bus_trans           ;
reg             bus_wr_dph          ;   // data phase of write trans
reg             hready_idle         ;
reg             hready_read         ;
wire            hready_rd_w         ;
wire            trans_fir           ;   // first beat of a burst
reg     [2:0]   addr_step           ;   // byte addr incr of each trans beat
reg     [2:0]   addr_wrap_bloc      ;   // the original addr bit location at wrap point
reg     [(mem_abit+2-1):0] addr_wrap;   // first addr after wrap back
wire    [(mem_abit+2-1):0] nxt_addr ;
reg     [(mem_abit+2-1):0] reg_addr ;   // registered addr
wire            bus_addr_inc        ;
wire            bus_addr_inc_w      ;   // addr incr of write
reg             wrap_flag           ;

wire            mem_rd              ;   // may read 1~2 addr more
reg             mem_wr              ;

assign  bus_idle        = hsel & hready & (htrans == T_IDLE);
assign  bus_busy        = hsel & hready & (htrans == T_BUSY);
assign  bus_trans       = hsel & hready & htrans[1];
assign  trans_fir       = hsel & hready & (htrans == T_NONS);

assign  nxt_addr        = reg_addr + addr_step;
assign  bus_addr_inc_w  = bus_trans & hwrite;
assign  bus_addr_inc    = bus_addr_inc_w | mem_rd;

assign  hresp           = R_OK;
assign  hreadyout       = ((bus_wr_dph)? 1'b1 : hready_rd_w) | hready_idle;

always @(posedge clk or negedge rstn)
    if(~rstn)
        hready_idle <= 1'b1;
    else
        hready_idle <= bus_idle | bus_busy;

always @(posedge clk or negedge rstn)
    if(~rstn)
        bus_wr_dph  <= 1'b0;
    else
        bus_wr_dph  <= (bus_trans & hwrite);

always @(*) begin
    case(hsize[1:0])
        'd0:    addr_step = 'd1;
        'd1:    addr_step = 'd2;
        'd2:    addr_step = 'd4;
        'd3:    addr_step = 'd4;    // not support
    endcase
end

always @(posedge clk or negedge rstn)
    if(~rstn) begin
        addr_wrap_bloc  <= 1'b0;
        addr_wrap       <= 'd0;
    end else if(trans_fir) begin
        case(hsize)
            'd0:    begin   // 8b trans
                if(hburst[2] == 1'b0) begin     // just cnt for bl=4
                    addr_wrap_bloc  <= 'd2;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 2], 2'h0};
                end else if(hburst[1] == 1'b0) begin // for bl=8
                    addr_wrap_bloc  <= 'd3;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 3], 3'h0};
                end else begin
                    addr_wrap_bloc  <= 'd3;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 4], 4'h0};
                end
            end

            'd1:    begin   // 16b trans
                if(hburst[2] == 1'b0) begin     // just cnt for bl=4
                    addr_wrap_bloc  <= 'd3;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 3], 3'h0};
                end else if(hburst[1] == 1'b0) begin // for bl=8
                    addr_wrap_bloc  <= 'd4;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 4], 4'h0};
                end else begin
                    addr_wrap_bloc  <= 'd5;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 5], 5'h0};
                end
            end

            default:begin   // 32b trans
                if(hburst[2] == 1'b0)begin      // just cnt for bl=4
                    addr_wrap_bloc  <= 'd4;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 4], 4'h0};
                end else if(hburst[1] == 1'b0)begin // for bl=8
                    addr_wrap_bloc  <= 'd5;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 5], 5'h0};
                end else begin
                    addr_wrap_bloc  <= 'd6;
                    addr_wrap       <= {haddr[(mem_abit+2-1) : 6], 6'h0};
                end
            end
        endcase
end

always @(posedge clk or negedge rstn)
    if(~rstn)
        wrap_flag   <= 1'b0;
    else if(trans_fir)
        wrap_flag   <= !hburst[0];

always @(posedge clk or negedge rstn)
    if(~rstn)
        reg_addr    <= 'd0;
    else if(trans_fir)
        reg_addr    <= haddr[(mem_abit+2-1):0];
    else if(bus_addr_inc) begin
        if(wrap_flag) begin
            if(nxt_addr[addr_wrap_bloc] != addr_wrap[addr_wrap_bloc])
                reg_addr    <= addr_wrap;
            else
                reg_addr    <= nxt_addr;
        end else begin
            reg_addr    <= nxt_addr;
        end
    end

//--- 1: change ahb inf to sram ctrl signals ---//

//--- 1.1: write part

wire    [mem_dw-1:0]    mem_wdata   ;
reg     [3:0]           mem_wbe     ;

assign  mem_wdata   = hwdata;

always @(posedge clk or negedge rstn)
    if(~rstn)
        mem_wr  <= 1'd0;
    else
        mem_wr  <= bus_addr_inc_w;

always @(posedge clk or negedge rstn)
    if(~rstn)
        mem_wbe <= 'd0;
    else if(bus_trans && hwrite) begin
        if(trans_fir) begin
            case(hsize)
                'd0: begin
                    case(haddr[1:0])
                        'd0:    mem_wbe <= 4'b0001;
                        'd1:    mem_wbe <= 4'b0010;
                        'd2:    mem_wbe <= 4'b0100;
                        'd3:    mem_wbe <= 4'b1000;
                    endcase
                end

                'd1: begin
                    if(haddr[1])
                        mem_wbe <= 4'b1100;
                    else
                        mem_wbe <= 4'b0011;
                end

                default:begin
                    mem_wbe <= 4'b1111;
                end
            endcase
        end else begin
            case(hsize)
                'd0:        mem_wbe <= {mem_wbe[2:0], mem_wbe[3]};
                'd1:        mem_wbe <= {mem_wbe[1:0], mem_wbe[3:2]};
                default:    mem_wbe <= mem_wbe;
            endcase
        end
    end

//---1.2: read part

reg                 mem_rd_time ;   // may read 1~2 addr more
reg                 mem_rd_d    ;   // 1T delay of mem_rd
wire [mem_dw-1:0]   mem_dout    ;

//assign ahb_read_w = psel & (!penable) & (!pwrite);
assign  mem_rd      = mem_rd_time & (!bus_busy);
assign  hread_rd_w  = hready_read & mem_rd_time;

always @(posedge clk or negedge rstn)
    if(~rstn) begin
        mem_rd_time <= 1'b0;
    end else if(trans_fir) begin
        if(!hwrite)
            mem_rd_time <= 1'b1;
        else
            mem_rd_time <= 1'b0;
    end else if(bus_idle) begin
        mem_rd_time <= 1'b0;
    end

always @(posedge clk or negedge rstn)
    if(~rstn) begin
        mem_rd_d    <= 1'b0;
    end else if(trans_fir || bus_idle) begin
        mem_rd_d    <= 1'b0;
    end else begin
        mem_rd_d    <= mem_rd;
    end

always @(posedge clk or negedge rstn)
    if(~rstn)
        hready_read <= 1'b0;
    else if(trans_fir || bus_idle)
        hready_read <= 1'b0;
    else if(mem_rd_d)
        hready_read <= 1'b1;

always @(posedge clk)   // or negedg rstn)
    if(mem_rd_d)
        hrdata  <= mem_dout;

//--- 2: mem cell instance

wire            mem_cs      ;

assign  mem_cs  = mem_rd | mem_wr;

spram_generic_wbe4 #(.ADDR_BITS(mem_abit), .ADDR_AMOUNT(mem_depth), .DATA_BITS(mem_dw)) u_mem(
    .clk        (clk        ),
    .en         (mem_cs     ),
    .we         (mem_wr     ),
    .wbe        (mem_wbe    ),
    .addr       (reg_addr[2 +: mem_abit]),
    .din        (hwdata     ),

    .dout       (mem_dout   )
);

endmodule
