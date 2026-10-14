// ============================================================
// comb_selector.v
// Genera las 6 combinaciones de pares de registros (sin repeticion):
//   idx 0: (R0, R1)    idx 3: (R1, R2)
//   idx 1: (R0, R2)    idx 4: (R1, R3)
//   idx 2: (R0, R3)    idx 5: (R2, R3)
// next_comb: pulso de 1 ciclo para avanzar al siguiente par
// active   : un bit por registro, 1 si participa en el par actual
// ============================================================
module comb_selector (
    input  wire       clk,
    input  wire       rst,
    input  wire       next_comb,
    output reg  [1:0] addr_a,
    output reg  [1:0] addr_b,
    output reg  [2:0] comb_idx,
    output wire [3:0] active
);

    initial comb_idx = 3'd0;

    always @(posedge clk or posedge rst) begin
        if (rst)
            comb_idx <= 3'd0;
        else if (next_comb)
            comb_idx <= (comb_idx == 3'd5) ? 3'd0 : comb_idx + 3'd1;
    end

    always @(*) begin
        case (comb_idx)
            3'd0:    begin addr_a = 2'd0; addr_b = 2'd1; end
            3'd1:    begin addr_a = 2'd0; addr_b = 2'd2; end
            3'd2:    begin addr_a = 2'd0; addr_b = 2'd3; end
            3'd3:    begin addr_a = 2'd1; addr_b = 2'd2; end
            3'd4:    begin addr_a = 2'd1; addr_b = 2'd3; end
            3'd5:    begin addr_a = 2'd2; addr_b = 2'd3; end
            default: begin addr_a = 2'd0; addr_b = 2'd1; end
        endcase
    end

    assign active = (4'b0001 << addr_a) | (4'b0001 << addr_b);

endmodule
