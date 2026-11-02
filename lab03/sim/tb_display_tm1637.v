`timescale 1ns / 1ps

// ============================================================
// tb_display_tm1637.v - Prueba individual del display
// ============================================================
module tb_display_tm1637;

    reg        clk = 0;
    reg        rst = 0;
    reg  [4:0] result = 0;
    reg  [2:0] op = 0;
    wire       tm_clk, tm_dio;

    // Pull-up en la línea de datos DIO
    pullup(tm_dio);

    // Reloj de 125 MHz (período de 8 ns)
    always #4 clk = ~clk;

    // Instancia del módulo a probar (DUT) con tiempos acelerados
    display_tm1637 #(
        .TM_BIT_HZ(6_250_000),
        .REFRESH_TICKS(50)
    ) dut (
        .clk(clk),
        .rst(rst),
        .result(result),
        .op_code(op),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );

    // Monitor del bus para decodificar tramas
    tm1637_monitor monitor (
        .clk(clk),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );

    initial begin
        // Archivo de ondas para GTKWave
        $dumpfile("tb_display_tm1637.vcd");
        $dumpvars(0, tb_display_tm1637);

        // Reset inicial
        rst = 1;
        #100;
        rst = 0;
        #100;

        // Prueba 1: Suma 15 (Suma / Decimal)
        result = 5'd15; op = 3'b000;
        #30000;

        // Prueba 2: Resta -5 (Sub / Decimal con signo)
        result = 5'd27; op = 3'b001;
        #30000;

        // Prueba 3: ROL en binario (0101)
        result = 5'd5; op = 3'b110;
        #30000;

        $display("--- Simulación del display completada ---");
        $finish;
    end

endmodule