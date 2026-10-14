// ============================================================
// exec_unit.v  -  Control de escritura y registro del resultado
//
//  wr_pulse   (BTN1): escribe sw[3:0] en el registro seleccionado
//  exec_pulse (BTN3): guarda el resultado de la ALU y la operacion
//                     (sw[2:0]) para el display.
//                     Si la operacion es de un solo operando
//                     (NOT, ROL, ROR) tambien escribe el resultado
//                     en el registro A (operacion acumulativa).
//
//  result_lat / op_lat solo cambian con exec_pulse: el display
//  conserva la ultima operacion ejecutada aunque cambien los
//  operandos, la combinacion o los switches.
// ============================================================
module exec_unit (
    input  wire       clk,
    input  wire       wr_pulse,
    input  wire       exec_pulse,
    input  wire [3:0] sw,
    input  wire [1:0] write_sel,
    input  wire [1:0] addr_a,
    input  wire [4:0] alu_result,
    output wire       we,
    output wire [1:0] waddr,
    output wire [3:0] wdata,
    output reg  [4:0] result_lat,
    output reg  [2:0] op_lat
);

    initial begin
        result_lat = 5'd0;
        op_lat     = 3'b000;
    end

    // NOT (101), ROL (110), ROR (111)
    wire single_op = (sw[2:0] == 3'b101) | (sw[2:1] == 2'b11);

    assign we    = wr_pulse | (exec_pulse & single_op);
    assign waddr = exec_pulse ? addr_a           : write_sel;
    assign wdata = exec_pulse ? alu_result[3:0]  : sw;

    always @(posedge clk) begin
        if (exec_pulse) begin
            result_lat <= alu_result;
            op_lat     <= sw[2:0];
        end
    end

endmodule
