// ============================================================
// display_tm1637.v  -  Modulo de visualizacion
//
// Recibe el resultado guardado (5 bits) y la operacion ejecutada,
// y los envia al TM1637 a traves de tm1637_driver.
//
// Formato en el display:
//   ADD / SUB / AND / OR / XOR : [signo][decenas][unidades][op]
//   NOT / ROL / ROR            : [b3][b2][b1][b0]  (binario)
// ============================================================
module display_tm1637 #(
    parameter integer CLK_FREQ_HZ   = 125_000_000,
    parameter integer TM_BIT_HZ     = 10_000,
    parameter integer REFRESH_TICKS = 2000       // ~0.1 s entre refrescos
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [4:0] result,
    input  wire [2:0] op_code,
    output wire       tm_clk,
    inout  wire       tm_dio
);

    tm1637_driver #(
        .CLK_FREQ_HZ   (CLK_FREQ_HZ),
        .TM_BIT_HZ     (TM_BIT_HZ),
        .REFRESH_TICKS (REFRESH_TICKS)
    ) u_tm (
        .clk     (clk),
        .rst     (rst),
        .result  (result),
        .op_code (op_code),
        .tm_clk  (tm_clk),
        .tm_dio  (tm_dio)
    );

endmodule
