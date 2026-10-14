// ============================================================
// debounce.v  -  Sincronizador + antirrebote + detector de flanco
//  - 2 flip-flops sincronizan la entrada asincrona del boton
//  - El nuevo nivel solo se acepta si se mantiene N_CYCLES ciclos
//  - btn_pulse vale 1 durante un solo ciclo por cada pulsacion
// Por defecto N_CYCLES = 250 000 -> 2 ms a 125 MHz
// ============================================================
module debounce #(
    parameter integer N_CYCLES = 250_000
)(
    input  wire clk,
    input  wire btn_in,
    output reg  btn_pulse
);

    reg        s0 = 1'b0, s1 = 1'b0;   // sincronizador
    reg        stable = 1'b0;          // nivel filtrado
    reg [31:0] cnt = 32'd0;

    initial btn_pulse = 1'b0;

    always @(posedge clk) begin
        s0        <= btn_in;
        s1        <= s0;
        btn_pulse <= 1'b0;

        if (s1 == stable)
            cnt <= 32'd0;                       // sin cambio: reinicia
        else if (cnt == N_CYCLES - 1) begin
            cnt    <= 32'd0;
            stable <= s1;                       // cambio confirmado
            if (s1) btn_pulse <= 1'b1;          // solo al presionar
        end else
            cnt <= cnt + 32'd1;
    end

endmodule
