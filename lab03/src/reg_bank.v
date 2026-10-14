// ============================================================
// reg_bank.v  -  Banco de 4 registros de 4 bits (R0-R3)
//  - Escritura sincrona controlada por write_enable
//  - Dos puertos de lectura combinacional (operandos A y B)
// ============================================================
module reg_bank (
    input  wire       clk,
    input  wire       rst,
    input  wire       write_enable,
    input  wire [1:0] write_addr,
    input  wire [3:0] write_data,
    input  wire [1:0] read_addr_a,
    input  wire [1:0] read_addr_b,
    output wire [3:0] read_data_a,
    output wire [3:0] read_data_b
);

    reg [3:0] regs [0:3];

    integer k;
    initial for (k = 0; k < 4; k = k + 1) regs[k] = 4'h0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            regs[0] <= 4'h0;
            regs[1] <= 4'h0;
            regs[2] <= 4'h0;
            regs[3] <= 4'h0;
        end else if (write_enable) begin
            regs[write_addr] <= write_data;
        end
    end

    assign read_data_a = regs[read_addr_a];
    assign read_data_b = regs[read_addr_b];

endmodule
