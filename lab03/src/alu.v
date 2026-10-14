// ============================================================
// alu.v  -  ALU de 4 bits (logica puramente combinacional)
//
// Entradas de 4 bits, salida de 5 bits:
//   bit 4 = acarreo en la suma / signo (complemento a 2) en la resta
//
//   op  | Operacion | Resultado
//   000 | ADD       | A + B            (0..30)
//   001 | SUB       | A - B            (-15..15, complemento a 2 en 5 bits)
//   010 | AND       | A & B
//   011 | OR        | A | B
//   100 | XOR       | A ^ B
//   101 | NOT       | ~A               (solo usa A)
//   110 | ROL       | rotacion izq. A  (solo usa A) 0101 -> 1010
//   111 | ROR       | rotacion der. A  (solo usa A) 0101 -> 1010
// ============================================================
module alu (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] op,
    output reg  [4:0] result,
    output wire       zero
);

    always @(*) begin
        case (op)
            3'b000:  result = {1'b0, a} + {1'b0, b};
            3'b001:  result = {1'b0, a} - {1'b0, b};
            3'b010:  result = {1'b0, a & b};
            3'b011:  result = {1'b0, a | b};
            3'b100:  result = {1'b0, a ^ b};
            3'b101:  result = {1'b0, ~a};
            3'b110:  result = {1'b0, a[2:0], a[3]};   // ROL: bit3 -> bit0
            3'b111:  result = {1'b0, a[0], a[3:1]};   // ROR: bit0 -> bit3
            default: result = 5'd0;
        endcase
    end

    assign zero = (result == 5'd0);

endmodule
