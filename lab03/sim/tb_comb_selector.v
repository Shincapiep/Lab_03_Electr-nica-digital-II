`timescale 1ns / 1ps
// ============================================================
// tb_comb_selector.v  -  Prueba individual del selector de pares
// ============================================================
module tb_comb_selector;

    reg        clk = 0, rst = 0, next = 0;
    wire [1:0] aa, ab;
    wire [2:0] idx;
    wire [3:0] active;

    reg  [1:0] exp_a [0:5];
    reg  [1:0] exp_b [0:5];
    integer    k, errores = 0;

    comb_selector dut (
        .clk(clk), .rst(rst), .next_comb(next),
        .addr_a(aa), .addr_b(ab), .comb_idx(idx), .active(active)
    );

    always #4 clk = ~clk;

    task verificar;
        input integer n;
        begin
            #1;
            if (aa !== exp_a[n] || ab !== exp_b[n] ||
                active !== ((4'b1 << exp_a[n]) | (4'b1 << exp_b[n]))) begin
                $display("ERROR idx=%0d: (R%0d,R%0d) active=%b", idx, aa, ab, active);
                errores = errores + 1;
            end else
                $display("OK idx=%0d: (R%0d, R%0d)  LEDs=%b", idx, aa, ab, active);
        end
    endtask

    task pulso;
        begin
            @(negedge clk) next = 1;
            @(negedge clk) next = 0;
        end
    endtask

    initial begin
        $dumpfile("tb_comb_selector.vcd");
        $dumpvars(0, tb_comb_selector);
        exp_a[0]=0; exp_b[0]=1;  exp_a[1]=0; exp_b[1]=2;  exp_a[2]=0; exp_b[2]=3;
        exp_a[3]=1; exp_b[3]=2;  exp_a[4]=1; exp_b[4]=3;  exp_a[5]=2; exp_b[5]=3;

        verificar(0);
        for (k = 1; k <= 6; k = k + 1) begin   // 6 pulsos: recorre y vuelve a 0
            pulso;
            verificar(k % 6);
        end

        // Sin pulso no avanza
        repeat (10) @(negedge clk);
        verificar(0);

        // Reset
        pulso; pulso;
        @(negedge clk) rst = 1; @(negedge clk) rst = 0;
        verificar(0);

        $display("--------------------------------------------");
        if (errores == 0) $display("COMB_SELECTOR: PASO");
        else              $display("COMB_SELECTOR: FALLO - %0d errores", errores);
        $finish;
    end

endmodule
