`timescale 1ns / 1ps
// ============================================================
// tb_reg_bank.v  -  Prueba individual del banco de registros
// ============================================================
module tb_reg_bank;

    reg        clk = 0, rst = 0, we = 0;
    reg  [1:0] waddr = 0, ra = 0, rb = 0;
    reg  [3:0] wdata = 0;
    wire [3:0] da, db;

    reg  [3:0] modelo [0:3];
    integer    i, j, errores = 0;

    reg_bank dut (
        .clk(clk), .rst(rst), .write_enable(we),
        .write_addr(waddr), .write_data(wdata),
        .read_addr_a(ra), .read_addr_b(rb),
        .read_data_a(da), .read_data_b(db)
    );

    always #4 clk = ~clk;

    task escribir;
        input [1:0] addr;
        input [3:0] val;
        begin
            @(negedge clk); waddr = addr; wdata = val; we = 1;
            @(negedge clk); we = 0;
            modelo[addr] = val;
        end
    endtask

    task leer_todo;
        begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    ra = i; rb = j; #1;
                    if (da !== modelo[i] || db !== modelo[j]) begin
                        $display("ERROR lectura R%0d/R%0d: %0d/%0d, esperado %0d/%0d",
                                 i, j, da, db, modelo[i], modelo[j]);
                        errores = errores + 1;
                    end
                end
        end
    endtask

    initial begin
        $dumpfile("tb_reg_bank.vcd");
        $dumpvars(0, tb_reg_bank);
        for (i = 0; i < 4; i = i + 1) modelo[i] = 0;

        leer_todo;                                  // arranque en 0

        escribir(0, 4'hA); escribir(1, 4'h5);
        escribir(2, 4'h3); escribir(3, 4'hF);
        leer_todo;
        $display("Escritura R0..R3 = A, 5, 3, F verificada");

        // write_enable = 0: no debe escribir
        @(negedge clk); waddr = 2; wdata = 4'h9; we = 0;
        @(negedge clk);
        leer_todo;
        $display("write_enable = 0 no modifica los registros");

        // Sobrescritura
        escribir(2, 4'h7);
        leer_todo;
        $display("Sobrescritura de R2 verificada");

        // Reset
        @(negedge clk); rst = 1; @(negedge clk); rst = 0;
        for (i = 0; i < 4; i = i + 1) modelo[i] = 0;
        leer_todo;
        $display("Reset verificado");

        $display("--------------------------------------------");
        if (errores == 0) $display("REG_BANK: PASO");
        else              $display("REG_BANK: FALLO - %0d errores", errores);
        $finish;
    end

endmodule
