`timescale 1ns / 1ps
// ============================================================
// tb_display_tm1637.v  -  Prueba individual del display
//  - Reloj del bus acelerado (TM_BIT_HZ alto, REFRESH_TICKS bajo)
//  - Un monitor decodifica las tramas del bus TM1637 y se comparan
//    los 4 digitos recibidos con los esperados
// ============================================================
module tb_display_tm1637;

    reg        clk = 0;
    reg  [4:0] result = 0;
    reg  [2:0] op = 0;
    wire       tm_clk, tm_dio;

    pullup (tm_dio);

    display_tm1637 #(
        .TM_BIT_HZ(6_250_000), .REFRESH_TICKS(50)
    ) dut (
        .clk(clk), .rst(1'b0), .result(result), .op_code(op),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

    tm1637_monitor mon (.clk(clk), .tm_clk(tm_clk), .tm_dio(tm_dio));

    always #4 clk = ~clk;

    // Segmentos
    localparam [7:0] OFF = 8'h00, MENOS = 8'h40,
                     S0 = 8'h3F, S1 = 8'h06, S2 = 8'h5B, S3 = 8'h4F, S4 = 8'h66,
                     S5 = 8'h6D, S6 = 8'h7D, S7 = 8'h07, S8 = 8'h7F, S9 = 8'h6F;

    integer errores = 0, f0;

    task mostrar;
        input [4:0]   r;
        input [2:0]   o;
        input [31:0]  esp;          // {d3, d2, d1, d0}
        input [8*20-1:0] nombre;
        begin
            result = r; op = o;
            f0 = mon.frames;
            wait (mon.frames >= f0 + 2);          // 2 tramas completas
            if ({mon.dig[3], mon.dig[2], mon.dig[1], mon.dig[0]} !== esp) begin
                $display("ERROR %s: %h %h %h %h, esperado %h", nombre,
                         mon.dig[3], mon.dig[2], mon.dig[1], mon.dig[0], esp);
                errores = errores + 1;
            end else
                $display("OK    %s: %h %h %h %h", nombre,
                         mon.dig[3], mon.dig[2], mon.dig[1], mon.dig[0]);
        end
    endtask

    initial begin
        $dumpfile("tb_display_tm1637.vcd");
        $dumpvars(0, tb_display_tm1637);

        mostrar(5'd15, 3'b000, {OFF,   S1, S5, S0}, "ADD  15     -> _150");
        mostrar(5'd30, 3'b000, {OFF,   S3, S0, S0}, "ADD  30     -> _300");
        mostrar(5'd5,  3'b001, {OFF,   S0, S5, S1}, "SUB  +5     -> _051");
        mostrar(5'd27, 3'b001, {MENOS, S0, S5, S1}, "SUB  -5     -> -051");
        mostrar(5'd17, 3'b001, {MENOS, S1, S5, S1}, "SUB  -15    -> -151");
        mostrar(5'd0,  3'b010, {OFF,   S0, S0, S2}, "AND  0      -> _002");
        mostrar(5'd15, 3'b100, {OFF,   S1, S5, S4}, "XOR  15     -> _154");
        mostrar(5'd5,  3'b101, {S0,    S1, S0, S1}, "NOT  0101   -> 0101");
        mostrar(5'd10, 3'b110, {S1,    S0, S1, S0}, "ROL  1010   -> 1010");

        $display("--------------------------------------------");
        if (errores == 0) $display("DISPLAY: PASO");
        else              $display("DISPLAY: FALLO - %0d errores", errores);
        $finish;
    end

endmodule
