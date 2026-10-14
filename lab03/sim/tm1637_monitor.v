`timescale 1ns / 1ps
// ============================================================
// tm1637_monitor.v  -  Modelo de lectura del bus TM1637 (solo simulacion)
//  - Muestrea CLK/DIO con el reloj del sistema
//  - Detecta START (DIO baja con CLK alto) y STOP (DIO sube con CLK alto)
//  - Arma los bytes LSB primero e ignora el 9.o pulso (ACK)
//  - Cuando llega la trama [0xC0, d3, d2, d1, d0] guarda los 4 digitos
//    y aumenta frames
// ============================================================
module tm1637_monitor (
    input  wire clk,
    input  wire tm_clk,
    input  wire tm_dio
);

    reg [7:0] dig [0:3];          // dig[3] = izquierda ... dig[0] = derecha
    integer   frames = 0;

    reg       pc = 1'b1, pd = 1'b1;
    reg       in_tx = 1'b0;
    integer   nbit = 0, nbyte = 0;
    reg [7:0] sh;
    reg [7:0] buf_b [0:7];

    wire d = (tm_dio === 1'b0) ? 1'b0 : 1'b1;   // z = 1 (pull-up)

    integer i;
    initial for (i = 0; i < 4; i = i + 1) dig[i] = 8'h00;

    always @(posedge clk) begin
        if (pc && tm_clk && pd && !d) begin              // START
            in_tx <= 1'b1; nbit <= 0; nbyte <= 0;
        end else if (pc && tm_clk && !pd && d) begin     // STOP
            in_tx <= 1'b0;
            if (nbyte == 5 && buf_b[0] == 8'hC0) begin
                dig[3] <= buf_b[1]; dig[2] <= buf_b[2];
                dig[1] <= buf_b[3]; dig[0] <= buf_b[4];
                frames <= frames + 1;
            end
        end else if (in_tx && !pc && tm_clk) begin       // flanco de subida de CLK
            if (nbit == 8) begin                         // pulso de ACK
                nbit <= 0;
                buf_b[nbyte] <= sh;
                nbyte <= nbyte + 1;
            end else begin
                sh   <= {d, sh[7:1]};                    // LSB primero
                nbit <= nbit + 1;
            end
        end
        pc <= tm_clk;
        pd <= d;
    end

endmodule
