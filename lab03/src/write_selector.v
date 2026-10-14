// ============================================================
// write_selector.v  -  Registro seleccionado para escritura
//  - next (BTN0): R0 -> R1 -> R2 -> R3 -> R0
//  - LED RGB: R0 = rojo, R1 = verde, R2 = azul, R3 = blanco
// ============================================================
module write_selector (
    input  wire       clk,
    input  wire       next,
    output reg  [1:0] sel,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);

    initial sel = 2'd0;

    always @(posedge clk)
        if (next) sel <= sel + 2'd1;

    assign led_r = (sel == 2'd0) | (sel == 2'd3);
    assign led_g = (sel == 2'd1) | (sel == 2'd3);
    assign led_b = (sel == 2'd2) | (sel == 2'd3);

endmodule
