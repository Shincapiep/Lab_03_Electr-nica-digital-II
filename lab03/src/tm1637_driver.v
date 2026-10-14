// ============================================================
// tm1637_driver.v  –  Driver TM1637 con visualización decimal corregida
//
// INTERPRETACIÓN DEL RESULTADO según operación:
//   op=000 ADD     : resultado unsigned 5 bits -> rango  0..30
//   op=001 SUB     : resultado signed   5 bits -> rango -15..+15
//   op=010..100    : resultado unsigned 4 bits -> rango  0..15
//   op=101..111    : NOT/ROL/ROR, se muestran en binario (4 digitos)
//
// DISPLAY (4 dígitos físicos):
//   [DIG3]   [DIG2]   [DIG1]   [DIG0]
//   signo    decenas  unidades  op_cod
//   '-'/off   0-3      0-9       0-7
//
// Sin división ni módulo en síntesis: se usa función lookup table.
// ============================================================
module tm1637_driver (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  result,
    input  wire [2:0]  op_code,
    output wire        tm_clk,
    inout  wire        tm_dio
);

    parameter integer CLK_FREQ_HZ   = 125_000_000;
    parameter integer TM_BIT_HZ     = 10_000;
    parameter integer REFRESH_TICKS = 2000;   // ticks de espera entre refrescos (~0.1 s)

    localparam integer DIVIDER      = CLK_FREQ_HZ / (TM_BIT_HZ * 2);
    localparam integer REFRESH_CNT  = REFRESH_TICKS;

    // =========================================================
    // Tick lento (divide el reloj a TM_BIT_HZ * 2)
    // =========================================================
    reg [31:0] divcnt = 0;
    reg        tick   = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin divcnt<=0; tick<=0; end
        else if (divcnt == DIVIDER-1) begin divcnt<=0; tick<=1; end
        else begin divcnt<=divcnt+1; tick<=0; end
    end

    // =========================================================
    // Decodificación resultado → decimal con signo
    //
    // Reglas:
    //   ADD (op=000): unsigned, bit4 es parte del valor (16-30)
    //   SUB (op=001): bit4=1 → negativo (complemento 2)
    //   resto:        unsigned, solo bits [3:0]
    // =========================================================
    wire is_sub = (op_code == 3'b001);
    wire is_add = (op_code == 3'b000);

    // Magnitud a mostrar (5 bits para cubrir 0-30)
    wire        show_neg;
    wire [4:0]  mag;

    assign show_neg = is_sub & result[4];
    assign mag      = (show_neg) ? ((~result + 5'd1) & 5'h1F) :
                      (is_add)   ? result :          // unsigned 5 bits
                                   {1'b0, result[3:0]}; // unsigned 4 bits

    // Lookup table: mag → (tens, units)  sin división
    // Rango: 0-30
    function [7:0] bcd_lookup;   // [7:4]=tens  [3:0]=units
        input [4:0] v;
        begin
            case (v)
                5'd0:  bcd_lookup = 8'h00;
                5'd1:  bcd_lookup = 8'h01;
                5'd2:  bcd_lookup = 8'h02;
                5'd3:  bcd_lookup = 8'h03;
                5'd4:  bcd_lookup = 8'h04;
                5'd5:  bcd_lookup = 8'h05;
                5'd6:  bcd_lookup = 8'h06;
                5'd7:  bcd_lookup = 8'h07;
                5'd8:  bcd_lookup = 8'h08;
                5'd9:  bcd_lookup = 8'h09;
                5'd10: bcd_lookup = 8'h10;
                5'd11: bcd_lookup = 8'h11;
                5'd12: bcd_lookup = 8'h12;
                5'd13: bcd_lookup = 8'h13;
                5'd14: bcd_lookup = 8'h14;
                5'd15: bcd_lookup = 8'h15;
                5'd16: bcd_lookup = 8'h16;
                5'd17: bcd_lookup = 8'h17;
                5'd18: bcd_lookup = 8'h18;
                5'd19: bcd_lookup = 8'h19;
                5'd20: bcd_lookup = 8'h20;
                5'd21: bcd_lookup = 8'h21;
                5'd22: bcd_lookup = 8'h22;
                5'd23: bcd_lookup = 8'h23;
                5'd24: bcd_lookup = 8'h24;
                5'd25: bcd_lookup = 8'h25;
                5'd26: bcd_lookup = 8'h26;
                5'd27: bcd_lookup = 8'h27;
                5'd28: bcd_lookup = 8'h28;
                5'd29: bcd_lookup = 8'h29;
                5'd30: bcd_lookup = 8'h30;
                default: bcd_lookup = 8'h00;
            endcase
        end
    endfunction

    wire [7:0]  bcd        = bcd_lookup(mag);
    wire [3:0]  dec_tens   = bcd[7:4];
    wire [3:0]  dec_units  = bcd[3:0];

    // =========================================================
    // Tabla de segmentos 7-seg (cátodo común)
    // =========================================================
    function [7:0] seg_digit;
        input [3:0] d;
        begin
            case (d)
                4'd0: seg_digit = 8'h3F;
                4'd1: seg_digit = 8'h06;
                4'd2: seg_digit = 8'h5B;
                4'd3: seg_digit = 8'h4F;
                4'd4: seg_digit = 8'h66;
                4'd5: seg_digit = 8'h6D;
                4'd6: seg_digit = 8'h7D;
                4'd7: seg_digit = 8'h07;
                4'd8: seg_digit = 8'h7F;
                4'd9: seg_digit = 8'h6F;
                default: seg_digit = 8'h00;
            endcase
        end
    endfunction

    localparam [7:0] SEG_MINUS = 8'h40;
    localparam [7:0] SEG_OFF   = 8'h00;

    // =========================================================
    // Modo binario: NOT(101), SHL(110), SHR(111)
    // Los 4 digitos muestran bit3 bit2 bit1 bit0 del resultado
    // =========================================================
    wire is_bin = (op_code == 3'b101) |
                  (op_code == 3'b110) |
                  (op_code == 3'b111);

    // =========================================================
    // Bytes de segmentos
    //   Decimal: [signo/-/off] [decenas] [unidades] [op_cod]
    //   Binario: [bit3]        [bit2]    [bit1]     [bit0]
    // =========================================================
    wire [7:0] seg3 = is_bin ? seg_digit({3'b0, result[3]})
                             : (show_neg ? SEG_MINUS : SEG_OFF);
    wire [7:0] seg2 = is_bin ? seg_digit({3'b0, result[2]})
                             : seg_digit(dec_tens);
    wire [7:0] seg1 = is_bin ? seg_digit({3'b0, result[1]})
                             : seg_digit(dec_units);
    wire [7:0] seg0 = is_bin ? seg_digit({3'b0, result[0]})
                             : seg_digit({1'b0, op_code});

    // =========================================================
    // Salidas físicas
    // =========================================================
    reg clk_reg = 1'b1;
    assign tm_clk = clk_reg;

    reg dio_out = 1'b1;
    reg dio_oe  = 1'b1;
    assign tm_dio = dio_oe ? dio_out : 1'bz;

    // =========================================================
    // Transacciones:
    //   TX0 = [0x40]                          modo escritura auto-inc
    //   TX1 = [0xC0, seg3, seg2, seg1, seg0]  4 dígitos
    //   TX2 = [0x8F]                          display ON brillo max
    // =========================================================
    function [2:0] tx_len;
        input [1:0] s;
        case (s) 2'd0: tx_len=3'd1; 2'd1: tx_len=3'd5;
                 2'd2: tx_len=3'd1; default: tx_len=3'd1; endcase
    endfunction

    function [7:0] tx_byte;
        input [1:0] s;
        input [2:0] i;
        case (s)
            2'd0: tx_byte = 8'h40;
            2'd1: case (i)
                      3'd0: tx_byte = 8'hC0;
                      3'd1: tx_byte = seg3;
                      3'd2: tx_byte = seg2;
                      3'd3: tx_byte = seg1;
                      3'd4: tx_byte = seg0;
                      default: tx_byte = 8'h00;
                  endcase
            2'd2:    tx_byte = 8'h8F;
            default: tx_byte = 8'h00;
        endcase
    endfunction

    // =========================================================
    // FSM
    // =========================================================
    localparam ST_INIT      = 0,  ST_WAIT     = 1,  ST_START_0  = 2,
               ST_START_1   = 3,  ST_LOAD     = 4,  ST_BIT_0    = 5,
               ST_BIT_1     = 6,  ST_BIT_2    = 7,  ST_ACK_0    = 8,
               ST_ACK_1     = 9,  ST_ACK_2    = 10, ST_STOP_0   = 11,
               ST_STOP_1    = 12, ST_NEXT_BYTE= 13, ST_NEXT_TX  = 14;

    reg [3:0]  state    = ST_INIT;
    reg [1:0]  tx_sel   = 0;
    reg [2:0]  byte_idx = 0;
    reg [7:0]  cur_byte = 0;
    reg [2:0]  bit_idx  = 0;
    reg [31:0] wait_cnt = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_reg<=1; dio_out<=1; dio_oe<=1;
            tx_sel<=0; byte_idx<=0; bit_idx<=0;
            cur_byte<=0; wait_cnt<=0; state<=ST_INIT;
        end else if (tick) begin
            case (state)
                ST_INIT:      begin clk_reg<=1; dio_out<=1; dio_oe<=1;
                                    tx_sel<=0; byte_idx<=0; state<=ST_START_0; end
                ST_START_0:   begin clk_reg<=1; dio_oe<=1; dio_out<=1; state<=ST_START_1; end
                ST_START_1:   begin clk_reg<=1; dio_oe<=1; dio_out<=0; state<=ST_LOAD; end
                ST_LOAD:      begin clk_reg<=0; cur_byte<=tx_byte(tx_sel,byte_idx);
                                    bit_idx<=0; state<=ST_BIT_0; end
                ST_BIT_0:     begin clk_reg<=0; dio_oe<=1; dio_out<=cur_byte[0]; state<=ST_BIT_1; end
                ST_BIT_1:     begin clk_reg<=1; state<=ST_BIT_2; end
                ST_BIT_2:     begin clk_reg<=0; cur_byte<={1'b0,cur_byte[7:1]};
                                    if (bit_idx==7) state<=ST_ACK_0;
                                    else begin bit_idx<=bit_idx+1; state<=ST_BIT_0; end end
                ST_ACK_0:     begin clk_reg<=0; dio_oe<=0; state<=ST_ACK_1; end
                ST_ACK_1:     begin clk_reg<=1; state<=ST_ACK_2; end
                ST_ACK_2:     begin clk_reg<=0; dio_oe<=1; dio_out<=0; state<=ST_NEXT_BYTE; end
                ST_NEXT_BYTE: if (byte_idx+1 < tx_len(tx_sel))
                                  begin byte_idx<=byte_idx+1; state<=ST_LOAD; end
                              else state<=ST_STOP_0;
                ST_STOP_0:    begin clk_reg<=1; dio_oe<=1; dio_out<=0; state<=ST_STOP_1; end
                ST_STOP_1:    begin clk_reg<=1; dio_oe<=1; dio_out<=1; state<=ST_NEXT_TX; end
                ST_NEXT_TX:   begin byte_idx<=0;
                                    if (tx_sel==2'd2) begin tx_sel<=0; wait_cnt<=0; state<=ST_WAIT; end
                                    else begin tx_sel<=tx_sel+1; state<=ST_START_0; end end
                ST_WAIT:      if (wait_cnt < REFRESH_CNT) begin wait_cnt<=wait_cnt+1; end
                              else state<=ST_START_0;
                default:      state<=ST_INIT;
            endcase
        end
    end

endmodule
