# Laboratorio 03: ALU + Banco de Registros

- **Asignatura:** Electrónica Digital II
- **Semestre:** 2026-2

## Integrantes del equipo

- **Samuel Hincapie Perilla**
- **Eduardo Felipe Camacho Lara**
- **Gabriel Alberto Rodríguez Rincón**

---

## Contenido

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Interfaz de usuario](#2-interfaz-de-usuario)
3. [Arquitectura modular](#3-arquitectura-modular)
4. [Módulos desarrollados](#4-módulos-desarrollados)
5. [Estrategia de visualización](#5-estrategia-de-visualización)
6. [Asignación de pines](#6-asignación-de-pines)
7. [Simulación](#7-simulación)
8. [Implementación y verificación en FPGA](#8-implementación-y-verificación-en-fpga)
9. [Conclusiones](#9-conclusiones)

---

## 1. Descripción del sistema

El sistema implementa en la Zybo Z7 un pequeño datapath formado por un banco de 4 registros de 4 bits (R0–R3), una ALU de 4 bits con 8 operaciones, un selector automático de pares de operandos y un display de 7 segmentos TM1637 que muestra el resultado.

El flujo de uso es:

1. Se elige el registro de destino con BTN0 (el LED RGB indica cuál está seleccionado).
2. Se coloca un valor en los switches y se escribe en ese registro con BTN1.
3. Con BTN2 se recorren los pares de registros que servirán como operandos A y B (los LEDs LD0–LD3 indican cuáles participan).
4. Se coloca el código de operación en SW[2:0] y se presiona BTN3. La ALU ejecuta la operación generando un resultado de 5 bits (para manejar acarreo en adición y signo en sustracción) y lo captura en el registro de salida. Aunque, si la operación seleccionada es de un solo operando (NOT, ROL, ROR), el sistema ejecuta una escritura acumulativa guardando de forma automática el resultado en el registro asignado como operando A.
5. El display muestra el resultado de la última operación ejecutada y lo conserva hasta la siguiente pulsación de BTN3, aunque cambien los switches, los operandos o el par seleccionado.

---

## 2. Interfaz de usuario

### 2.1 Switches

Los switches cumplen dos funciones en momentos distintos:

| Momento | Switches | Función |
|---|---|---|
| Al presionar **BTN1** | `SW[3:0]` | Dato de 4 bits que se escribe en el registro seleccionado |
| Al presionar **BTN3** | `SW[2:0]` | Código de la operación que ejecuta la ALU |

Como el dato solo se lee al presionar BTN1 y la operación solo al presionar BTN3, compartir los switches no genera conflicto: entre una acción y otra se pueden mover libremente.

### 2.2 Botones

| Botón | Función |
|---|---|
| BTN0 | Selecciona el registro de escritura: R0 → R1 → R2 → R3 → R0 |
| BTN1 | Escribe `SW[3:0]` en el registro seleccionado |
| BTN2 | Avanza al siguiente par de operandos (A, B) |
| BTN3 | Ejecuta la operación `SW[2:0]` y actualiza el resultado del display |

**Nota:** Todas las entradas de los botones (`BTN0`–`BTN3`) pasan internamente por el módulo `debounce.v`. Este implementa un sincronizador de dos etapas, un contador de filtrado configurado a 250,000 ciclos (equivalente a 2 ms a 125 MHz) y un detector de flanco ascendente. Esto garantiza que cada pulsación mecánica entregue exactamente un único pulso limpio (`btn_pulse`) de 1 ciclo de reloj, evitando lecturas múltiples por rebote.

### 2.3 LEDs

Cada LED corresponde a un registro y se enciende si el registro participa en el par de operandos actual:

| Par (A, B) | LD3 | LD2 | LD1 | LD0 |
|---|---|---|---|---|
| (R0, R1) | 0 | 0 | 1 | 1 |
| (R0, R2) | 0 | 1 | 0 | 1 |
| (R0, R3) | 1 | 0 | 0 | 1 |
| (R1, R2) | 0 | 1 | 1 | 0 |
| (R1, R3) | 1 | 0 | 1 | 0 |
| (R2, R3) | 1 | 1 | 0 | 0 |

### 2.4 LED RGB

Indica el registro seleccionado para escritura:

| Registro | Color | R | G | B |
|---|---|---|---|---|
| R0 | Rojo | 1 | 0 | 0 |
| R1 | Verde | 0 | 1 | 0 |
| R2 | Azul | 0 | 0 | 1 |
| R3 | Blanco | 1 | 1 | 1 |

### 2.5 Display TM1637

El driver adapta la representación en los 4 dígitos físicos del display según el tipo de operación:

**Modo Decimal con Signo (`ADD`, `SUB`, `AND`, `OR`, `XOR`):**
   - **Formato:** `[DIG3: Signo] [DIG2: Decenas] [DIG1: Unidades] [DIG0: Código OP]`
   - **Resta:** Si el resultado de 5 bits indica valor negativo (bit 4 en `1`), el dígito izquierdo (`DIG3`) enciende el segmento de signo negativo (`-`) y la magnitud en complemento a 2 se convierte a decimal.
   
**Modo Binario Directo (`NOT`, `ROL`, `ROR`):**
   - **Formato:** `[DIG3: Bit 3] [DIG2: Bit 2] [DIG1: Bit 1] [DIG0: Bit 0]`
   - Los 4 dígitos muestran de forma directa la palabra binaria resultante de 4 bits.
---

## 3. Arquitectura modular


El sistema se diseñó bajo el principio de división de responsabilidades, descomponiendo la arquitectura en módulos independientes y reutilizables. El módulo superior `top.v` actúa exclusivamente como interconexión estructural: no contiene lógica combinacional ni secuencial propia, limitándose a declarar señales internas, instanciar los bloques y mapearlos a los pines de la FPGA Zybo Z7.

### 3.1 Resumen de Módulos

| Módulo | Tipo de lógica | Responsabilidad |
|---|---|---|
| `debounce.v` | Secuencial | Sincroniza cada botón, filtra el rebote y entrega un pulso de un ciclo por pulsación |
| `write_selector.v` | Secuencial + combinacional | Registro de escritura seleccionado (BTN0) y color del LED RGB |
| `comb_selector.v` | Secuencial + combinacional | Índice del par de operandos (BTN2), direcciones de lectura y LEDs |
| `reg_bank.v` | Secuencial | 4 registros de 4 bits, 1 puerto de escritura y 2 de lectura |
| `alu.v` | Combinacional | Las 8 operaciones aritméticas y lógicas |
| `exec_unit.v` | Secuencial + combinacional | Decide qué se escribe en el banco y guarda el resultado ejecutado (BTN3) |
| `display_tm1637.v` | Secuencial | Módulo de visualización; contiene `tm1637_driver.v`, que convierte el resultado y lo envía al display |
| `top.v` | Solo conexiones | Integración con los pines de la tarjeta |

### 3.2 Flujo de Datos y Control

El procesamiento de información sigue la siguiente secuencia:

1. **Acondicionamiento de entradas:** Las pulsaciones asíncronas de los botones pasan por `debounce` y se convierten en los pulsos `btn0_p` … `btn3_p`.
2. **Selección de operandos:** `comb_selector.v` entrega las direcciones `addr_a` y `addr_b`, permitiendo que `reg_bank.v` exponga de forma inmediata los datos `read_data_a` y `read_data_b` en las entradas de la ALU.
3. **Cálculo combinacional:** La `alu.v` procesa continuamente `read_data_a`, `read_data_b` y la operación seleccionada en `SW[2:0]`. Su salida permanece aislada hasta que se decida capturarla.
4. **Captura y Retención:** Al presionar `BTN3`, la `exec_unit.v` recibe el pulso `btn3_p`, almacena el resultado de 5 bits y el código de operación en sus registros de salida (`result_lat` y `op_lat`) y los envía a `display_tm1637.v`
5. **Realimentación / Escritura:** La `exec_unit.v` controla la escritura en el banco:
   - Con `btn1_p`: escribe el valor presente en `SW[3:0]` en el registro seleccionado por `write_selector.v`.
   - Con `btn3_p`: si la operación es unaria (`NOT`, `ROL`, `ROR`), escribe automáticamente el resultado de la ALU de vuelta en el registro A.

**Nota:** Todos los tiempos que dependen de contadores de reloj (ventana del antirrebote y divisor de frecuencia del bus TM1637) están parametrizados en los módulos superiores (`top.v` y `tb_top.v`). Para la síntesis en hardware se emplean los valores reales (125 MHz); mientras que en la simulación los parámetros se escalan hacia abajo, permitiendo validar el funcionamiento en GTKWave en escala de microsegundos en lugar de segundos.

---

## 4. Módulos desarrollados

### 4.1 `alu.v`: ALU combinacional

Recibe dos operandos de 4 bits (`a` y `b`) y entrega un resultado de 5 bits (`result`). El bit adicional (`result[4]`) conserva el acarreo de la suma y la extensión de signo de la resta, los cuales se perderían con una salida de 4 bits.

| `op` | Operación | Resultado | Rango | Ejemplo (A = 10, B = 5) |
|---|---|---|---|---|
| `000` | ADD | $A + B$ | 0 a 30 | 15 |
| `001` | SUB | $A - B$ (complemento a 2 en 5 bits) | −15 a 15 | 5 |
| `010` | AND | $A \land B$ bit a bit | 0 a 15 | 0 |
| `011` | OR | $A \lor B$ bit a bit | 0 a 15 | 15 |
| `100` | XOR | $A \oplus B$ bit a bit | 0 a 15 | 15 |
| `101` | NOT | $\overline{A}$ | 0 a 15 | 5 |
| `110` | ROL | Rotación de A a la izquierda (el bit 3 pasa al bit 0) | 0 a 15 | 5 |
| `111` | ROR | Rotación de A a la derecha (el bit 0 pasa al bit 3) | 0 a 15 | 5 |

NOT, ROL y ROR operan exclusivamente sobre el operando A.

En todas las operaciones lógicas y de desplazamiento, el bit más significativo `result[4]` se rellenante explícitamente con `1'b0`.

La resta se calcula extendiendo los operandos a 5 bits, por lo que el bit 4 queda como bit de signo en complemento a 2. Por ejemplo, $3 - 8 = -5$, que en complemento a 2 de 5 bits es $11011_2 = 27$; el display interpreta ese valor como −5 (sección 5).

El módulo usa `always @(*)`, no tiene reloj ni registros, y todas las ramas del `case` asignan `result`, por lo que no se infieren latches.

### 4.2 `reg_bank.v`: banco de registros

Almacena los datos temporales del sistema mediante las siguientes especificaciones:
- Contiene 4 registros de 4 bits ($R_0, R_1, R_2, R_3$), inicializados en cero (`4'h0`).
- **Escritura síncrona:** En el flanco de subida del reloj, si `write_enable = 1`, se guarda `write_data` en `regs[write_addr]`.
- **Dos puertos de lectura combinacionales:** Entregan de forma asíncrona e inmediata los datos `read_data_a = regs[read_addr_a]` y `read_data_b = regs[read_addr_b]` a las entradas de la ALU.

### 4.3 `comb_selector.v`: selector de operandos

Genera las 6 combinaciones de pares sin repetición de los 4 registros:

$$\binom{4}{2} = \frac{4!}{2!\,2!} = 6$$

Un índice interno `comb_idx` (0 a 5) avanza con cada pulso de BTN2 y vuelve a 0 después del 5. Una tabla convierte el índice en las direcciones `addr_a` y `addr_b`. La salida `active` enciende los dos LEDs de los registros participantes:

```verilog
assign active = (4'b0001 << addr_a) | (4'b0001 << addr_b);
```

En cada par, A siempre es el registro de menor índice. Por eso la resta se calcula como R(menor) − R(mayor); para obtener la resta en el otro sentido basta con intercambiar los valores escritos en los registros.

### 4.4 `debounce.v`: acondicionamiento de botones

Cada botón físico pasa por tres etapas de procesamiento:

1. **Sincronizador de 2 Flip-Flops:** Aísla la entrada asíncrona del botón respecto al reloj principal de la FPGA para evitar estados de metaestabilidad.
2. **Filtro de rebote:** Un cambio de nivel en la señal solo se valida si se mantiene estable durante `N_CYCLES` ciclos de reloj consecutivos. Si la señal rebota, el contador interno se reinicia.
3. **Detector de flanco ascendente:** Una vez confirmada la transición de `0` a `1`, la salida `btn_pulse` se activa durante **un solo ciclo de reloj**.

Con el valor por defecto configurado para la frecuencia de la Zybo Z7 (125 MHz), el tiempo de filtrado se calcula mediante:

$$t_{db} = N_{cycles} \cdot T_{clk} = 250\,000 \cdot 8\ \text{ns} = 2\ \text{ms}$$

El pulso de un ciclo es indispensable para los controles del sistema (`BTN0`, `BTN2`, `BTN3`). A 125 MHz, una pulsación manual típica de unos 200 ms equivale a: $0.2\ \text{s} / 8\ \text{ns} = 25 \times 10^{6}$ ciclos de reloj

Sin el detector de flanco, los registros o el índice de combinación avanzarían millones de posiciones por cada pulsación.

### 4.5 `write_selector.v`: registro de escritura

Consiste en un contador secuencial de 2 bits que avanza circularmente con cada pulso de **BTN0** (R0 → R1 → R2 → R3 → R0). 

Mapea directamente la dirección del registro objetivo hacia las salidas del **LED RGB** (`led_r`, `led_g`, `led_b`), permitiendo identificar visualmente cuál registro está seleccionado para escritura:

| Registro Objetivo | Color del LED RGB | R | G | B |
| :--- | :--- | :-: | :-: | :-: |
| **R0** | Rojo | 1 | 0 | 0 |
| **R1** | Verde | 0 | 1 | 0 |
| **R2** | Azul | 0 | 0 | 1 |
| **R3** | Blanco | 1 | 1 | 1 |

### 4.6 `exec_unit.v`: escritura y resultado guardado

Este módulo centraliza el control de escrituras en el banco y la retención del resultado mostrado en pantalla mediante dos funciones principales:

a) Árbitro de escritura del banco

Determina la procedencia de la señal de escritura (`we`), la dirección (`waddr`) y el dato (`wdata`) según el evento ocurrido:

| Evento | `write_enable` (`we`) | Dirección (`waddr`) | Dato de Escritura (`wdata`) |
| :--- | :-: | :--- | :--- |
| **BTN1** (Carga manual) | `1` | Registro seleccionado por BTN0 (`write_sel`) | Valor de los switches `SW[3:0]` |
| **BTN3** con `NOT`, `ROL` o `ROR` | `1` | Registro A del par actual (`addr_a`) | Resultado de la ALU (`alu_result[3:0]`) |
| **BTN3** con `ADD`, `SUB`, `AND`, `OR` o `XOR` | `0` | — | — |

Las operaciones de un solo operando se escriben de vuelta en el registro A para que sean **acumulativas**: presionar BTN3 varias veces con ROL sigue rotando el mismo registro, y NOT dos veces devuelve el valor original. Las operaciones de dos operandos no modifican los registros. Como NOT, ROL y ROR siempre producen resultados de 4 bits, el valor escrito cabe en el registro sin pérdida.

La condición para identificar operaciones unarias se implementa mediante la expresión lógica:

```verilog
wire single_op = (sw[2:0] == 3'b101) | (sw[2:1] == 2'b11);
```

b) Registro del resultado

Las señales `result_lat` y `op_lat` se actualizan únicamente cuando se detecta el pulso `exec_pulse` (BTN3). Aunque la ALU recalcula continuamente de forma combinacional, el módulo de visualización recibe únicamente estos registros retenidos, garantizando que el display conserve la última operación ejecutada aunque cambien posteriormente los switches, el par de registros o el contenido del banco.

```verilog
always @(posedge clk) begin
    if (exec_pulse) begin
        result_lat <= alu_result;
        op_lat     <= sw[2:0];
    end
end
```

### 4.7 `display_tm1637.v` y `tm1637_driver.v`: display

El módulo `display_tm1637` es un módulo de visualización que instancia al controlador `tm1637_driver`, el cual cumple dos tareas centrales:

1. **Conversión del resultado a los 4 dígitos:** Mapea el resultado retenido de 5 bits y el código de operación a los patrones de 7 segmentos de cada dígito.
2. Comunicación con el TM1637 mediante una máquina de estados que genera el protocolo de 2 hilos (CLK y DIO).

El protocolo del TM1637 es parecido a I²C, pero sin dirección de dispositivo y con los datos LSB primero. Cada refresco envía tres transacciones:

| Transacción | Bytes | Significado |
|---|---|---|
| 1 | `0x40` | Modo escritura con autoincremento de dirección |
| 2 | `0xC0`, d3, d2, d1, d0 | Dirección del primer dígito y los 4 patrones de segmentos |
| 3 | `0x8F` | Display encendido, brillo máximo |

Cada transacción inicia con la condición START (DIO pasa a bajo mientras CLK se mantiene en alto) y finaliza con la condición STOP (DIO pasa a alto mientras CLK está en alto). Los bits cambian en DIO cuando CLK está en bajo y son muestreados en el flanco de subida de CLK. Tras cada byte enviado, existe un noveno pulso de confirmación (ACK), durante el cual el driver libera la línea (`tm_dio = 1'bz`).

Con `TM_BIT_HZ` = 10 kHz, el driver avanza un estado cada:

$$t_{tick} = \frac{1}{2 \cdot TM_{bit}} = \frac{1}{2 \cdot 10\ \text{kHz}} = 50\ \mu\text{s}$$

Un bit ocupa 3 estados (150 µs) y una trama completa unos 220 estados (≈ 11 ms). Entre tramas se esperan `REFRESH_TICKS` = 2000 estados (100 ms), así que el display se refresca unas 9 veces por segundo, muy por encima de lo necesario para un valor que solo cambia con BTN3.

---

## 5. Estrategia de visualización

El display TM1637 consta de 4 dígitos físicos de 7 segmentos. La representación visual se adapta dinámicamente según el tipo de operación ejecutada para permitir una lectura intuitiva y sin ambigüedades:

| Operaciones | Representación | Dígito 3 (Izq.) | Dígito 2 | Dígito 1 | Dígito 0 (Der.) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ADD, SUB, AND, OR, XOR** | **Decimal con Signo** | Signo (`-` / Apagado) | Apagado | Decenas (0 a 3) | Unidades (0 a 9) |
| **NOT, ROL, ROR** | **Binario Directo** | Bit 3 | Bit 2 | Bit 1 | Bit 0 |

A. **Modo Decimal con Signo:**
   - Se aplica a las operaciones aritméticas (`ADD`, `SUB`) y lógicas (`AND`, `OR`, `XOR`) para mostrar la magnitud final de forma numéricamente directa.
   - **Formato numérico:** El dígito menos significativo (`DIG0`) representa las unidades y el dígito contiguo (`DIG1`) las decenas, permitiendo leer el resultado de forma natural como un entero decimal de derecha a izquierda.

B. **Modo Binario Directo:**
   - Se utiliza en `NOT`, `ROL` y `ROR` porque son transformaciones bit a bit. Representar operaciones de desplazamiento en decimal ocultaría la manipulación de los bits (por ejemplo, ver $0101 \to 1010$ es inmediato en binario, mientras que en decimal se leería ambiguamente como 5 a 10).

### 5.1 Interpretación del Resultado de 5 Bits

La ALU entrega una salida de 5 bits (`result[4:0]`), cuya interpretación varía según la operación:

| Operación | Tipo de Dato | Rango Útil | Cálculo de la Magnitud Mostrada |
| :--- | :--- | :-: | :--- |
| **ADD** | Sin signo (5 bits) | 0 a 30 | El valor directo `result[4:0]` |
| **SUB** | Con signo (Complemento a 2) | -15 a +15 | Si `result[4] == 1`: activa signo `-` y calcula magnitud como $\overline{r} + 1$ |
| **AND, OR, XOR** | Sin signo (4 bits) | 0 a 15 | Los 4 bits menos significativos `result[3:0]` |

### Ejemplo de Cálculo en Sustracción Negativa:
Para la operación $3 - 8$, la ALU entrega $11011_2$ (27). Al ser una sustracción (`SUB`), el sistema evalúa el bit de signo (`result[4] = 1`):
-  **Activación de signo:** El dígito 3 (`DIG3`) enciende el segmento negativo (`-`).
-  **Obtención de la magnitud:** $\overline{11011}_2 + 1 = 00100_2 + 1 = 00101_2 = 5_{10}$
-  **Proyección en pantalla:** El display muestra `-  5` (Signo `-`, Decenas `0`, Unidades `5`).

La conversión a decenas y unidades se hace con una tabla de búsqueda (0 a 30), sin divisiones, para que la síntesis sea sencilla.

### 5.2 Ejemplos de Visualización:

| Operación | Resultado guardado | Display |
|---|---|---|
| ADD 10 + 5 | 15 | ` 15` |
| ADD 15 + 15 | 30 | ` 30` |
| SUB 10 − 5 | 5 | ` 05` |
| SUB 3 − 8 | 27 (−5) | `-05` |
| AND 10 & 5 | 0 | ` 0` |
| NOT 1010 | 0101 | `0101` |
| ROL 0101 | 1010 | `1010` |

---

## 6. Asignación de pines

| Puerto | Pin | Componente |
|---|---|---|
| `clk` | K17 | Reloj de 125 MHz (`create_clock -period 8.00`) |
| `sw[0]` – `sw[3]` | G15, P15, W13, T16 | Switches SW0–SW3 |
| `btn0` – `btn3` | K18, P16, K19, Y16 | Botones BTN0–BTN3 |
| `led[0]` – `led[3]` | M14, M15, G14, D18 | LD0–LD3 (registros activos) |
| `led_r`, `led_g`, `led_b` | V16, F17, M17 | LED RGB LD6 (registro de escritura) |
| `tm_clk` | V12 | Pmod JE, pin 1 → CLK del TM1637 |
| `tm_dio` | W16 | Pmod JE, pin 2 → DIO del TM1637 (con `PULLUP true`) |

El módulo TM1637 se alimenta desde el mismo Pmod JE: VCC en el pin 6 (3.3 V) y GND en el pin 5.

---

## 7. Simulación

Cada módulo del sistema se probó de manera independiente mediante un *testbench* dedicado antes de realizar la simulación integrada con el archivo superior `top.v`. Los testbenches evalúan automáticamente las salidas contra modelos de referencia e imprimen en consola el resultado `PASO` o `FALLO`.

| Testbench | Módulo Bajo Prueba | Verificación Realizada |
| :--- | :--- | :--- |
| `tb_alu.v` | `alu.v` | Evalúa las 8 operaciones con las 256 combinaciones de A y B (2058 casos de prueba total). |
| `tb_reg_bank.v` | `reg_bank.v` | Escritura en los 4 registros, lectura simultánea por ambos puertos, verificación de `write_enable = 0`, sobrescritura y `reset`. |
| `tb_comb_selector.v` | `comb_selector.v` | Recorrido de los 6 pares de operandos, retorno circular a (R0, R1), máscara de LEDs `active`, retención sin pulso y `reset`. |
| `tb_display_tm1637.v` | `display_tm1637.v` | Decodificación del protocolo serie del bus TM1637 y validación de dígitos en 9 escenarios de prueba. |
| `tb_top.v` | `top.v` (Sistema completo) | Flujo completo con pulsaciones reales con rebote: carga de registros, combinaciones, operaciones ALU, retención del resultado, LEDs, RGB y display. |

### Modelo de Verificación del Bus: `tm1637_monitor.v`
Para validar la comunicación serie sin requerir el hardware físico, se desarrolló el módulo de verificación `tm1637_monitor.v`. Este bloque observa las líneas físicas `tm_clk` y `tm_dio`, detecta las condiciones de `START` y `STOP`, ensambla los bytes recibidos (orden LSB primero) y extrae los patrones transmitidos a los 4 dígitos. De esta forma, la simulación valida lo que realmente viaja por el bus físico.

### Escalado de Parámetros para Simulación
Para evitar tiempos excesivos de simulación y facilitar la inspección visual en GTKWave, se redujeron los parámetros temporales en el entorno de pruebas:

| Parámetro | Valor en Síntesis (FPGA) | Valor en Simulación (Testbench) |
|---|---|---|
| `DEBOUNCE_CYCLES` | 250 000 (2 ms) | 8 |
| `TM_BIT_HZ` | 10 kHz | 6.25 MHz |
| `TM_REFRESH_TICKS` | 2000 | 50 |

### Comandos de Compilación y Ejecución (Icarus Verilog + GTKWave)
```bash
iverilog -g2005 -o s_alu  tb_alu.v ../src/alu.v
iverilog -g2005 -o s_rb   tb_reg_bank.v ../src/reg_bank.v
iverilog -g2005 -o s_cs   tb_comb_selector.v ../src/comb_selector.v
iverilog -g2005 -o s_disp tb_display_tm1637.v tm1637_monitor.v ../src/display_tm1637.v ../src/tm1637_driver.v
iverilog -g2005 -o s_top  tb_top.v tm1637_monitor.v ../src/top.v ../src/debounce.v ../src/write_selector.v ../src/comb_selector.v ../src/reg_bank.v ../src/alu.v ../src/exec_unit.v ../src/display_tm1637.v ../src/tm1637_driver.v
vvp s_top
gtkwave tb_top.vcd
```

### 7.1 ALU

```
a=10 b= 5 op=000 -> result=01111 (15)
a=10 b= 5 op=001 -> result=00101 (5)
a=10 b= 5 op=010 -> result=00000 (0)
a=10 b= 5 op=011 -> result=01111 (15)
a=10 b= 5 op=100 -> result=01111 (15)
a=10 b= 5 op=101 -> result=00101 (5)
a=10 b= 5 op=110 -> result=00101 (5)
a=10 b= 5 op=111 -> result=00101 (5)
a= 3 b= 8 op=000 -> result=01011 (11)
a= 3 b= 8 op=001 -> result=11011 (27)
--------------------------------------------
ALU: PASO - 2058 casos
```

![Simulación de la ALU](lab03/sim/tb_alu.png)

> _[Captura de GTKWave: `a`, `b`, `op` y `result`, primeros 100 ns]_

Con A y B fijos, `result` cambia en el mismo instante que `op`, lo que confirma que la ALU es combinacional. En el caso $3 - 8$ aparece $11011_2$, el −5 en complemento a 2 de 5 bits.

### 7.2 Banco de registros

```
Escritura R0..R3 = A, 5, 3, F verificada
write_enable = 0 no modifica los registros
Sobrescritura de R2 verificada
Reset verificado
--------------------------------------------
REG_BANK: PASO
```

![Simulación del banco de registros](lab03/sim/tb_reg_bank.png)

> _[Captura de GTKWave: `clk`, `we`, `waddr`, `wdata`, `ra`, `rb`, `da`, `db`]_

Se valida la escritura síncrona en los registros en el flanco de subida de clk únicamente cuando `write_enable = 1`. La lectura por los dos puertos independientes (`read_data_a` y `read_data_b`) es inmediata y asíncrona.

### 7.3 Selector de combinaciones

```
OK idx=0: (R0, R1)  LEDs=0011
OK idx=1: (R0, R2)  LEDs=0101
OK idx=2: (R0, R3)  LEDs=1001
OK idx=3: (R1, R2)  LEDs=0110
OK idx=4: (R1, R3)  LEDs=1010
OK idx=5: (R2, R3)  LEDs=1100
OK idx=0: (R0, R1)  LEDs=0011
...
COMB_SELECTOR: PASO
```

![Simulación del selector](lab03/sim/tb_comb_selector.png)

> _[Captura de GTKWave: `next`, `idx`, `aa`, `ab`, `active`]_

Cada pulso de `next_comb` incrementa `comb_idx` en 1 y actualiza las direcciones de lectura `addr_a` y `addr_b`. Al llegar a la combinación 5 (R2, R3), el siguiente pulso reinicia el contador a 0 (R0, R1). La señal `active` enciende exactamente los 2 LEDs correspondientes.

### 7.4 Display

| Entrada | Bytes recibidos (d3 d2 d1 d0) | Display |
|---|---|---|
| ADD, 15 | `00 06 6D 3F` | ` 150` |
| ADD, 30 | `00 4F 3F 3F` | ` 300` |
| SUB, +5 | `00 3F 6D 06` | ` 051` |
| SUB, −5 | `40 3F 6D 06` | `-051` |
| SUB, −15 | `40 06 6D 06` | `-151` |
| AND, 0 | `00 3F 3F 5B` | ` 002` |
| XOR, 15 | `00 06 6D 66` | ` 154` |
| NOT, 0101 | `3F 06 3F 06` | `0101` |
| ROL, 1010 | `06 3F 06 3F` | `1010` |

**NOTA:** `0x40` representa el segmento de signo negativo (-), `0x00` indica dígito apagado, y los demás valores mapean la codificación de 7 segmentos de los dígitos 0 a 9.

<img width="955" height="76" alt="image" src="https://github.com/user-attachments/assets/ce216b56-d65b-4611-a77b-f5dced3a2ce9" />

> _[Captura de GTKWave con zoom en una trama: `tm_clk`, `tm_dio`, `state`, `cur_byte`]_

### 7.5 Sistema completo

| Prueba | Qué se hizo | Resultado |
|---|---|---|
| T1 | Escribir R0 = 10, R1 = 5, R2 = 3, R3 = 2 | Registros correctos |
| T2 | Recorrer los 6 pares con BTN2 y volver al inicio | LEDs correctos en los 7 pasos |
| T3 | ADD, SUB, AND, OR, XOR con R0 = 10, R1 = 5 | 15, 5, 0, 15, 15; R0 no cambia; display ` 150` |
| T4 | NOT, ROL, ROR sobre R0 | 5, 10, 5; R0 se actualiza (acumulativo) |
| T5 | 15 + 15 y 3 − 8 | 30 (` 300`) y 27 (`-051`) |
| T6 | Sin BTN3: mover switches, cambiar el par, escribir un registro y cambiar el registro de escritura | `result_lat` sigue en 27, `op_lat` en 1 y el display en `-051` |
| T6 | Presionar BTN3 con ADD sobre (R0, R2) = (3, 9) | 12, display ` 120` |
| T7 | Recorrer R0–R3 con BTN0 | Rojo, verde, azul, blanco |

```
=============================================
  SISTEMA COMPLETO: PASO 
=============================================
```

Todas las pulsaciones del testbench incluyen 3 rebotes al presionar y 3 al soltar, más cortos que `DEBOUNCE_CYCLES`. Que el registro de escritura y el índice de pares avancen exactamente un paso por pulsación confirma que el antirrebote funciona.

![Simulación del sistema completo](lab03/sim/tb_top_general.png)

> _[Captura de GTKWave, vista general: `btn0`–`btn3`, `sw`, `dut.u_comb.comb_idx`, `led`, `dut.u_exec.result_lat`, `dut.u_exec.op_lat`]_

![Conservación del resultado](lab03/sim/tb_top_conservacion.png)

> _[Captura de GTKWave con zoom en T6: `btn1`, `btn2`, `btn3`, `sw`, `dut.data_a`, `dut.data_b`, `dut.alu_result`, `dut.u_exec.result_lat`]_

En la prueba T6 se observa que `alu_result` cambia cada vez que cambian los operandos o los switches, mientras que `result_lat` permanece fijo hasta el pulso de BTN3.

---

## 8. Implementación y verificación en FPGA

---

## 9. Conclusiones
