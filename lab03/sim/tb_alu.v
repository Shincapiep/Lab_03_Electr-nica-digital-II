`timescale 1ns / 1ps
// ============================================================
// tb_alu.v  -  Prueba individual de la ALU
//  - Casos representativos de las 8 operaciones (para GTKWave)
//  - Prueba exhaustiva: 8 operaciones x 256 combinaciones de A y B
// ============================================================
module tb_alu;

    reg  [3:0] a = 0, b = 0;
    reg  [2:0] op = 0;
    wire [4:0] result;
    wire       zero;

    reg  [4:0] esperado;
    integer    i, j, k, errores = 0, casos = 0;

    alu dut (.a(a), .b(b), .op(op), .result(result), .zero(zero));

    // Modelo de referencia
    always @(*) begin
        case (op)
            3'b000: esperado = a + b;
            3'b001: esperado = {1'b0, a} - {1'b0, b};
            3'b010: esperado = a & b;
            3'b011: esperado = a | b;
            3'b100: esperado = a ^ b;
            3'b101: esperado = {1'b0, ~a};
            3'b110: esperado = {1'b0, a[2:0], a[3]};
            3'b111: esperado = {1'b0, a[0], a[3:1]};
        endcase
    end

    task revisar;
        begin
            casos = casos + 1;
            if (result !== esperado || zero !== (esperado == 0)) begin
                $display("ERROR op=%b a=%0d b=%0d -> %b, esperado %b", op, a, b, result, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // Casos representativos: A = 10, B = 5 y A = 3, B = 8
        a = 4'd10; b = 4'd5;
        for (k = 0; k < 8; k = k + 1) begin
            op = k; #10; revisar;
            $display("a=%2d b=%2d op=%b -> result=%b (%0d)", a, b, op, result, result);
        end
        a = 4'd3; b = 4'd8;
        for (k = 0; k < 2; k = k + 1) begin
            op = k; #10; revisar;
            $display("a=%2d b=%2d op=%b -> result=%b (%0d)", a, b, op, result, result);
        end

        // Exhaustiva
        for (k = 0; k < 8; k = k + 1)
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1) begin
                    op = k; a = i; b = j; #1; revisar;
                end

        $display("--------------------------------------------");
        if (errores == 0) $display("ALU: PASO - %0d casos", casos);
        else              $display("ALU: FALLO - %0d errores", errores);
        $finish;
    end

endmodule
