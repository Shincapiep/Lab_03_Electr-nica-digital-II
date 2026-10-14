`timescale 1ns / 1ps
// ============================================================
// tb_top.v  -  Testbench del sistema completo (top.v real)
//  - DEBOUNCE_CYCLES = 8 y bus TM1637 acelerado para simular rapido
//  - Pulsaciones con rebote simulado
//  - Verifica registros, combinaciones, ALU, resultado guardado,
//    conservacion del resultado, LEDs, RGB y digitos del display
// ============================================================
module tb_top;

    localparam integer DB = 8;

    reg        clk = 0;
    reg  [3:0] sw = 0;
    reg        btn0 = 0, btn1 = 0, btn2 = 0, btn3 = 0;
    wire [3:0] led;
    wire       led_r, led_g, led_b;
    wire       tm_clk, tm_dio;

    pullup (tm_dio);

    top #(
        .DEBOUNCE_CYCLES(DB), .TM_BIT_HZ(6_250_000), .TM_REFRESH_TICKS(50)
    ) dut (
        .clk(clk), .sw(sw),
        .btn0(btn0), .btn1(btn1), .btn2(btn2), .btn3(btn3),
        .led(led), .led_r(led_r), .led_g(led_g), .led_b(led_b),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

    tm1637_monitor mon (.clk(clk), .tm_clk(tm_clk), .tm_dio(tm_dio));

    always #4 clk = ~clk;   // 125 MHz

    integer errores = 0;
    reg [1:0] wsel = 0;     // copia del registro de escritura

    // ------------------------------------------------------------
    // Pulsacion con rebote (3 rebotes mas cortos que DB)
    // ------------------------------------------------------------
    task press;
        input integer n;
        integer k;
        begin
            for (k = 0; k < 3; k = k + 1) begin
                set_btn(n, 1); repeat (2) @(posedge clk);
                set_btn(n, 0); repeat (2) @(posedge clk);
            end
            set_btn(n, 1); repeat (DB + 10) @(posedge clk);
            for (k = 0; k < 3; k = k + 1) begin
                set_btn(n, 0); repeat (2) @(posedge clk);
                set_btn(n, 1); repeat (2) @(posedge clk);
            end
            set_btn(n, 0); repeat (DB + 10) @(posedge clk);
        end
    endtask

    task set_btn;
        input integer n;
        input         v;
        case (n) 0: btn0 = v; 1: btn1 = v; 2: btn2 = v; 3: btn3 = v; endcase
    endtask

    task write_reg;
        input [1:0] r;
        input [3:0] v;
        begin
            while (wsel != r) begin press(0); wsel = wsel + 1; end
            sw = v; press(1); sw = 0;
        end
    endtask

    task exec_op;
        input [2:0] op;
        begin
            sw = {1'b0, op}; press(3); sw = 0;
        end
    endtask

    task check;
        input [31:0]     got, exp;
        input [8*32-1:0] nombre;
        begin
            if (got !== exp) begin
                $display("  FALLO %s: %0d, esperado %0d", nombre, got, exp);
                errores = errores + 1;
            end else
                $display("  OK    %s = %0d", nombre, got);
        end
    endtask

    task check_disp;
        input [31:0]     exp;
        input [8*32-1:0] nombre;
        integer f0;
        begin
            f0 = mon.frames;
            wait (mon.frames >= f0 + 2);
            if ({mon.dig[3], mon.dig[2], mon.dig[1], mon.dig[0]} !== exp) begin
                $display("  FALLO %s: %h, esperado %h", nombre,
                         {mon.dig[3], mon.dig[2], mon.dig[1], mon.dig[0]}, exp);
                errores = errores + 1;
            end else
                $display("  OK    %s = %h", nombre, exp);
        end
    endtask

    localparam [7:0] OFF = 8'h00, MENOS = 8'h40, S0 = 8'h3F, S1 = 8'h06, S2 = 8'h5B,
                     S3 = 8'h4F, S5 = 8'h6D;

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
        repeat (5) @(posedge clk);

        // ======================================================
        $display("\n--- T1: Escritura en el banco de registros ---");
        write_reg(0, 4'hA); check(dut.u_regbank.regs[0], 10, "R0");
        write_reg(1, 4'h5); check(dut.u_regbank.regs[1], 5,  "R1");
        write_reg(2, 4'h3); check(dut.u_regbank.regs[2], 3,  "R2");
        write_reg(3, 4'h2); check(dut.u_regbank.regs[3], 2,  "R3");
        press(0); wsel = 0;                       // volver a R0

        // ======================================================
        $display("\n--- T2: Combinaciones de operandos y LEDs ---");
        check(led, 4'b0011, "R0-R1");
        press(2); check(led, 4'b0101, "R0-R2");
        press(2); check(led, 4'b1001, "R0-R3");
        press(2); check(led, 4'b0110, "R1-R2");
        press(2); check(led, 4'b1010, "R1-R3");
        press(2); check(led, 4'b1100, "R2-R3");
        press(2); check(led, 4'b0011, "R0-R1 (vuelta)");

        // ======================================================
        $display("\n--- T3: Operaciones con R0=10, R1=5 ---");
        exec_op(3'b000); check(dut.u_exec.result_lat, 15, "ADD 10+5");
        check_disp({OFF, S1, S5, S0}, "display ADD = _150");
        exec_op(3'b001); check(dut.u_exec.result_lat, 5,  "SUB 10-5");
        exec_op(3'b010); check(dut.u_exec.result_lat, 0,  "AND 10&5");
        exec_op(3'b011); check(dut.u_exec.result_lat, 15, "OR  10|5");
        exec_op(3'b100); check(dut.u_exec.result_lat, 15, "XOR 10^5");
        check(dut.u_regbank.regs[0], 10, "R0 sin cambio");

        // ======================================================
        $display("\n--- T4: NOT / ROL / ROR acumulan en A (R0) ---");
        exec_op(3'b101); check(dut.u_exec.result_lat, 5,  "NOT 1010");
        check(dut.u_regbank.regs[0], 5, "R0 = 0101");
        exec_op(3'b110); check(dut.u_exec.result_lat, 10, "ROL 0101");
        exec_op(3'b111); check(dut.u_exec.result_lat, 5,  "ROR 1010");
        check(dut.u_regbank.regs[0], 5, "R0 = 0101");

        // ======================================================
        $display("\n--- T5: Suma > 15 y resta negativa ---");
        write_reg(0, 4'hF); write_reg(1, 4'hF);
        exec_op(3'b000); check(dut.u_exec.result_lat, 30, "ADD 15+15");
        check_disp({OFF, S3, S0, S0}, "display = _300");
        write_reg(0, 4'h3); write_reg(1, 4'h8);
        exec_op(3'b001); check(dut.u_exec.result_lat, 27, "SUB 3-8 (-5)");
        check_disp({MENOS, S0, S5, S1}, "display = -051");

        // ======================================================
        $display("\n--- T6: Conservacion del ultimo resultado ---");
        // Sin BTN3: cambiar switches, combinacion, registro de escritura
        // y el contenido de un operando
        sw = 4'b0110;                 repeat (50) @(posedge clk);
        press(2);                                 // R0-R2
        write_reg(2, 4'h9);                       // cambia el operando B
        press(0); wsel = wsel + 1;
        check(dut.u_exec.result_lat, 27, "resultado conservado");
        check(dut.u_exec.op_lat,     1,  "operacion conservada");
        check_disp({MENOS, S0, S5, S1}, "display sigue en -051");
        sw = 0;

        // Nueva ejecucion con la combinacion actual R0-R2 (3 y 9)
        exec_op(3'b000); check(dut.u_exec.result_lat, 12, "ADD 3+9 tras BTN3");
        check_disp({OFF, S1, S2, S0}, "display = _120");

        // ======================================================
        $display("\n--- T7: LED RGB del registro de escritura ---");
        while (wsel != 0) begin press(0); wsel = wsel + 1; end
        check({led_r, led_g, led_b}, 3'b100, "R0 rojo");
        press(0); check({led_r, led_g, led_b}, 3'b010, "R1 verde");
        press(0); check({led_r, led_g, led_b}, 3'b001, "R2 azul");
        press(0); check({led_r, led_g, led_b}, 3'b111, "R3 blanco");
        wsel = 3;

        // ======================================================
        $display("\n=============================================");
        if (errores == 0) $display("  SISTEMA COMPLETO: PASO (0 errores)");
        else              $display("  SISTEMA COMPLETO: FALLO - %0d errores", errores);
        $display("=============================================");
        $finish;
    end

endmodule
