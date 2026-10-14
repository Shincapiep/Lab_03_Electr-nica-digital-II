// ============================================================
// top.v  -  Integracion ALU + Banco de Registros (Zybo Z7, 125 MHz)
//
// Solo instancia y conecta modulos; no contiene logica propia.
//
//   BTN0 -> write_selector : registro de escritura R0..R3 (LED RGB)
//   BTN1 -> exec_unit      : escribe SW[3:0] en el registro seleccionado
//   BTN2 -> comb_selector  : siguiente par de operandos (LED[3:0])
//   BTN3 -> exec_unit      : ejecuta SW[2:0] y guarda el resultado
//   display_tm1637         : muestra el ultimo resultado ejecutado
// ============================================================
module top #(
    parameter integer DEBOUNCE_CYCLES  = 250_000,   // 2 ms
    parameter integer TM_BIT_HZ        = 10_000,
    parameter integer TM_REFRESH_TICKS = 2000
)(
    input  wire       clk,
    input  wire [3:0] sw,
    input  wire       btn0,
    input  wire       btn1,
    input  wire       btn2,
    input  wire       btn3,
    output wire [3:0] led,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b,
    output wire       tm_clk,
    inout  wire       tm_dio
);

    wire rst = 1'b0;

    // ---------------- Senales internas ----------------
    wire       btn0_p, btn1_p, btn2_p, btn3_p;
    wire [1:0] write_sel;
    wire [1:0] addr_a, addr_b;
    wire [3:0] data_a, data_b;
    wire [4:0] alu_result;
    wire       we;
    wire [1:0] waddr;
    wire [3:0] wdata;
    wire [4:0] result_lat;
    wire [2:0] op_lat;

    // ---------------- Botones ----------------
    debounce #(.N_CYCLES(DEBOUNCE_CYCLES)) u_db0 (.clk(clk), .btn_in(btn0), .btn_pulse(btn0_p));
    debounce #(.N_CYCLES(DEBOUNCE_CYCLES)) u_db1 (.clk(clk), .btn_in(btn1), .btn_pulse(btn1_p));
    debounce #(.N_CYCLES(DEBOUNCE_CYCLES)) u_db2 (.clk(clk), .btn_in(btn2), .btn_pulse(btn2_p));
    debounce #(.N_CYCLES(DEBOUNCE_CYCLES)) u_db3 (.clk(clk), .btn_in(btn3), .btn_pulse(btn3_p));

    // ---------------- Registro de escritura + RGB ----------------
    write_selector u_wsel (
        .clk(clk), .next(btn0_p), .sel(write_sel),
        .led_r(led_r), .led_g(led_g), .led_b(led_b)
    );

    // ---------------- Combinaciones de operandos + LEDs ----------------
    comb_selector u_comb (
        .clk(clk), .rst(rst), .next_comb(btn2_p),
        .addr_a(addr_a), .addr_b(addr_b), .comb_idx(), .active(led)
    );

    // ---------------- Banco de registros ----------------
    reg_bank u_regbank (
        .clk(clk), .rst(rst),
        .write_enable(we), .write_addr(waddr), .write_data(wdata),
        .read_addr_a(addr_a), .read_addr_b(addr_b),
        .read_data_a(data_a), .read_data_b(data_b)
    );

    // ---------------- ALU ----------------
    alu u_alu (
        .a(data_a), .b(data_b), .op(sw[2:0]),
        .result(alu_result), .zero()
    );

    // ---------------- Escritura y resultado guardado ----------------
    exec_unit u_exec (
        .clk(clk), .wr_pulse(btn1_p), .exec_pulse(btn3_p),
        .sw(sw), .write_sel(write_sel), .addr_a(addr_a),
        .alu_result(alu_result),
        .we(we), .waddr(waddr), .wdata(wdata),
        .result_lat(result_lat), .op_lat(op_lat)
    );

    // ---------------- Display ----------------
    display_tm1637 #(
        .TM_BIT_HZ(TM_BIT_HZ), .REFRESH_TICKS(TM_REFRESH_TICKS)
    ) u_disp (
        .clk(clk), .rst(rst),
        .result(result_lat), .op_code(op_lat),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

endmodule
