`timescale 1ns/1ps

module game_firmware_tb;

    logic clk_i = 1'b0;
    logic rst_ni = 1'b0;
    logic [6:0] btn_raw_i = 7'b0;
    logic uart_rx_i = 1'b1;

    wire uart_tx_o;
    wire [6:0] seg_o;
    wire [3:0] anode_o;
    wire [2:0] led_o;
    wire buzz_pwm_o;
    wire hsync_o;
    wire vsync_o;
    wire [3:0] r_o;
    wire [3:0] g_o;
    wire [3:0] b_o;
    wire [31:0] pc_o;

    integer cycles;
    integer i;
    integer errors;

    logic [7:0] uart_tx_byte0;
    logic [7:0] uart_tx_byte1;
    logic [7:0] uart_tx_byte2;
    logic [7:0] uart_tx_byte3;
    logic [7:0] uart_tx_byte4;
    logic [7:0] uart_tx_byte5;
    logic [7:0] uart_tx_byte6;
    logic [7:0] uart_tx_byte7;
    logic [7:0] uart_tx_byte8;
    logic [7:0] uart_tx_byte9;
    logic [7:0] uart_tx_byte10;

    localparam BTN_UP    = 32'h01;
    localparam BTN_DOWN  = 32'h02;
    localparam BTN_LEFT  = 32'h04;
    localparam BTN_RIGHT = 32'h08;
    localparam BTN_SEL   = 32'h10;
    localparam BTN_OK    = 32'h20;

    always #5 clk_i = ~clk_i;

    sistema_top #(
        .ROM_FILE("game.hex")
    ) dut (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .btn_raw_i  (btn_raw_i),
        .uart_rx_i  (uart_rx_i),
        .uart_tx_o  (uart_tx_o),
        .seg_o      (seg_o),
        .anode_o    (anode_o),
        .led_o      (led_o),
        .buzz_pwm_o (buzz_pwm_o),
        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),
        .r_o        (r_o),
        .g_o        (g_o),
        .b_o        (b_o),
        .pc_o       (pc_o)
    );

    // ------------------------------------------------------------
    // Inyectar un pulso MMIO de botón.
    //
    // Se mantiene hasta observar que el firmware produjo el cambio
    // esperado. Después se libera y se dejan varios ciclos en cero.
    // ------------------------------------------------------------

    logic [31:0] injected_button;

    task automatic press_button(input [31:0] value);
        integer timeout;
        begin
            // No comenzar sobre una lectura INPUT ya activa.
            while (dut.mmio_addr == 32'h0001_0120)
                @(negedge clk_i);

            // Presentar el boton antes de la siguiente lectura.
            injected_button = value;
            force dut.input_rdata = injected_button;

            timeout = 0;

            // Esperar hasta que el lw de INPUT este activo.
            while (!((dut.mmio_addr == 32'h0001_0120) &&
                     (dut.mmio_sel  == 1'b1) &&
                     (dut.mmio_we   == 1'b0)) &&
                   (timeout < 500)) begin
                @(negedge clk_i);
                timeout = timeout + 1;
            end

            if (timeout >= 500)
                $fatal(1,
                    "Timeout esperando captura INPUT: PC=%h addr=%h",
                    pc_o, dut.mmio_addr);

            // El register_file captura el resultado del lw
            // en el siguiente flanco positivo.
            @(posedge clk_i);
            #1;

            // Retirar inmediatamente el boton.
            injected_button = 32'h0;

            // Primero esperar que el CPU abandone este acceso INPUT.
            while (dut.mmio_addr == 32'h0001_0120)
                @(negedge clk_i);

            // Esperar hasta que el firmware termine de procesar
            // la accion y vuelva al polling de INPUT.
            timeout = 0;

            // Una accion puede generar trafico UART antes de volver
            // al main_loop. A 115200 baud, una respuesta DR de 9 bytes
            // requiere aproximadamente 0.8 ms.
            //
            // 150000 ciclos @ 100 MHz = 1.5 ms de margen.
            while (!((dut.mmio_addr == 32'h0001_0120) &&
                     (dut.mmio_sel  == 1'b1) &&
                     (dut.mmio_we   == 1'b0)) &&
                   (timeout < 150000)) begin
                @(negedge clk_i);
                timeout = timeout + 1;
            end

            if (timeout >= 150000)
                $fatal(1,
                    "Timeout esperando retorno a main_loop: PC=%h addr=%h",
                    pc_o, dut.mmio_addr);

            // En esta nueva lectura INPUT debe verse cero.
            if (dut.mmio_rdata !== 32'h0000_0000)
                $fatal(1,
                    "INPUT no regreso a cero: rdata=%h",
                    dut.mmio_rdata);

            release dut.input_rdata;

            // Salir de la lectura actual antes de retornar al test.
            @(negedge clk_i);
        end
    endtask

    // ------------------------------------------------------------
    // Transmitir un byte hacia el RX de la FPGA a 115200 baud.
    // UART 8N1: start=0, 8 bits LSB-first, stop=1.
    // ------------------------------------------------------------

    task automatic uart_send_byte(input [7:0] data);
        integer bit_index;
        begin
            // Reposo.
            uart_rx_i = 1'b1;
            #(8680);

            // Bit de inicio.
            uart_rx_i = 1'b0;
            #(8680);

            // 8 bits de datos, LSB primero.
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx_i = data[bit_index];
                #(8680);
            end

            // Bit de parada.
            uart_rx_i = 1'b1;
            #(8680);

            // Mantener reposo adicional.
            #(8680);
        end
    endtask

    // ------------------------------------------------------------
    // Recibir un byte transmitido por la FPGA a 115200 baud.
    // UART 8N1: start=0, 8 bits LSB-first, stop=1.
    // ------------------------------------------------------------

    task automatic uart_receive_byte(output [7:0] data);
        integer bit_index;
        begin
            // Esperar el inicio de una trama transmitida por la FPGA.
            @(negedge uart_tx_o);

            // Desde el flanco de START:
            // 1.5 periodos llevan al centro del bit de datos 0.
            #(13020);

            // Muestrear los 8 bits de datos en el centro de cada bit.
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                data[bit_index] = uart_tx_o;
                #(8680);
            end

            // En este punto estamos en el centro del bit STOP.
            if (uart_tx_o !== 1'b1) begin
                $display("ERROR UART TX: bit STOP invalido");
                errors = errors + 1;
            end

            // Avanzar hasta el final del bit STOP.
            #(4340);
        end
    endtask

    // ------------------------------------------------------------
    // Recibir y verificar mensaje de cambio de turno:
    //
    //     T,<jugador>\n
    //
    // player_ascii debe ser "1" (8'h31) o "2" (8'h32).
    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // Enviar colocacion valida de J2:
    //
    //     P,ship,row,col,H/V\n
    //
    // y comprobar:
    //
    //     PA,ship\n
    //
    // Los argumentos ship/row/col se reciben como valores 0..7.
    // ------------------------------------------------------------
    task automatic place_j2_expect_pa(
        input [7:0] ship,
        input [7:0] row,
        input [7:0] col,
        input [7:0] orient
    );
        logic [7:0] b0;
        logic [7:0] b1;
        logic [7:0] b2;
        logic [7:0] b3;
        logic [7:0] b4;
        begin
            fork
                begin
                    uart_send_byte(8'h50);       // P
                    uart_send_byte(8'h2C);       // ,
                    uart_send_byte(ship + 8'h30);
                    uart_send_byte(8'h2C);       // ,
                    uart_send_byte(row + 8'h30);
                    uart_send_byte(8'h2C);       // ,
                    uart_send_byte(col + 8'h30);
                    uart_send_byte(8'h2C);       // ,
                    uart_send_byte(orient);      // H o V
                    uart_send_byte(8'h0A);       // LF
                end

                begin
                    uart_receive_byte(b0);
                    uart_receive_byte(b1);
                    uart_receive_byte(b2);
                    uart_receive_byte(b3);
                    uart_receive_byte(b4);
                end
            join

            if (b0 !== 8'h50 ||             // P
                b1 !== 8'h41 ||             // A
                b2 !== 8'h2C ||             // ,
                b3 !== (ship + 8'h30) ||
                b4 !== 8'h0A) begin

                $display(
                    "ERROR UART PA PASS26: ship=%0d recibido=%h %h %h %h %h",
                    ship, b0, b1, b2, b3, b4
                );
                errors = errors + 1;
            end

            repeat (300) @(negedge clk_i);
        end
    endtask

    task automatic expect_turn_uart(input [7:0] player_ascii);
        logic [7:0] b0;
        logic [7:0] b1;
        logic [7:0] b2;
        logic [7:0] b3;
        begin
            uart_receive_byte(b0);
            uart_receive_byte(b1);
            uart_receive_byte(b2);
            uart_receive_byte(b3);

            if (b0 !== 8'h54 ||          // T
                b1 !== 8'h2C ||          // ,
                b2 !== player_ascii ||
                b3 !== 8'h0A) begin      // LF

                $display(
                    "ERROR UART TURN: esperado=T,%c\\n recibido=%h %h %h %h",
                    player_ascii, b0, b1, b2, b3
                );
                errors = errors + 1;
            end
        end
    endtask

    task automatic expect_ram(
        input integer word_index,
        input [31:0] expected
    );
        begin
            if (dut.u_processor.ram.words[word_index] !== expected) begin
                $display(
                    "ERROR RAM[%0d]: esperado=%h obtenido=%h",
                    word_index,
                    expected,
                    dut.u_processor.ram.words[word_index]
                );
                errors = errors + 1;
            end
        end
    endtask

    task automatic expect_vga(
        input integer index,
        input [31:0] expected
    );
        begin
            if (dut.u_vga.u_memory.mem[index] !== expected) begin
                $display(
                    "ERROR VGA[%0d]: esperado=%h obtenido=%h",
                    index,
                    expected,
                    dut.u_vga.u_memory.mem[index]
                );
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        cycles = 0;
        errors = 0;

        // ============================================================
        // 1. Inicialización
        // ============================================================

        repeat (3) @(negedge clk_i);
        rst_ni = 1'b1;

        while ((led_o !== 3'b001) && (cycles < 3000)) begin
            @(negedge clk_i);
            cycles = cycles + 1;
        end

        if (led_o !== 3'b001)
            $fatal(1, "Timeout init_game PC=%h", pc_o);

        repeat (10) @(negedge clk_i);

        expect_ram(0, 32'd0);  // GAME_STATE
        expect_ram(2, 32'd0);  // CURSOR_ROW
        expect_ram(3, 32'd0);  // CURSOR_COL
        expect_ram(4, 32'd0);  // ORIENTATION
        expect_ram(5, 32'd0);  // CURRENT_SHIP
        expect_ram(6, 32'd0);  // PLACED_J1

        // Los cuatro arreglos de juego deben iniciar vacios:
        // BOARD_J1, BOARD_J2, SHOTS_J1 y SHOTS_J2.
        for (i = 0; i < 64; i = i + 1) begin
            expect_ram(64+i,  32'd0);  // BOARD_J1  0x2100
            expect_ram(128+i, 32'd0);  // BOARD_J2  0x2200
            expect_ram(192+i, 32'd0);  // SHOTS_J1  0x2300
            expect_ram(256+i, 32'd0);  // SHOTS_J2  0x2400
        end

        for (i = 0; i < 300; i = i + 1)
            expect_vga(i, 32'd0);

        $display("PASS 1: inicializacion");

        // ============================================================
        // 2. Barco 0: longitud 4, horizontal en (0,0)
        // ============================================================

        press_button(BTN_OK);

        expect_ram(64, 32'd1); // (0,0)
        expect_ram(65, 32'd1); // (0,1)
        expect_ram(66, 32'd1); // (0,2)
        expect_ram(67, 32'd1); // (0,3)

        expect_vga(0, 32'd1);
        expect_vga(1, 32'd1);
        expect_vga(2, 32'd1);
        expect_vga(3, 32'd1);

        expect_ram(5, 32'd1); // CURRENT_SHIP
        expect_ram(6, 32'd1); // PLACED_J1

        $display("PASS 2: barco 0 horizontal");

        // ============================================================
        // 3. Intento inválido del barco 1
        //
        // Mover columna hasta 6. Longitud 3 horizontal:
        // 6 + 3 > 8.
        // ============================================================

        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);

        expect_ram(3, 32'd6);

        press_button(BTN_OK);

        // No debe avanzar de barco.
        expect_ram(5, 32'd1);
        expect_ram(6, 32'd1);

        // El buzzer debe haber recibido tono 011.
        if (dut.buzzer_rdata[2:0] !== 3'b011) begin
            $display(
                "ERROR buzzer invalido: esperado=011 obtenido=%b",
                dut.buzzer_rdata[2:0]
            );
            errors = errors + 1;
        end

        $display("PASS 3: rechazo fuera de tablero");

        // ============================================================
        // 4. Barco 1: longitud 3, vertical en (0,6)
        // ============================================================

        press_button(BTN_SEL);
        expect_ram(4, 32'd1);

        press_button(BTN_OK);

        // Índices: 6,14,22 -> RAM 64+indice.
        expect_ram(70, 32'd2);
        expect_ram(78, 32'd2);
        expect_ram(86, 32'd2);

        // VGA: fila*20 + columna.
        expect_vga(6, 32'd1);
        expect_vga(26, 32'd1);
        expect_vga(46, 32'd1);

        expect_ram(5, 32'd2);
        expect_ram(6, 32'd2);

        $display("PASS 4: barco 1 vertical");

        // ============================================================
        // 5. Intento con traslape del barco 2
        //
        // El cursor vuelve a (0,0), horizontal.
        // Allí ya existe el barco 0.
        // ============================================================

        expect_ram(2, 32'd0);
        expect_ram(3, 32'd0);
        expect_ram(4, 32'd0);

        press_button(BTN_OK);

        // Debe continuar esperando el barco 2.
        expect_ram(5, 32'd2);
        expect_ram(6, 32'd2);

        $display("PASS 5: rechazo por traslape");

        // ============================================================
        // 6. Barco 2: longitud 2 horizontal en (1,0)
        // ============================================================

        press_button(BTN_DOWN);

        expect_ram(2, 32'd1);
        expect_ram(3, 32'd0);

        press_button(BTN_OK);

        // Índices 8 y 9.
        expect_ram(72, 32'd3);
        expect_ram(73, 32'd3);

        expect_vga(20, 32'd1);
        expect_vga(21, 32'd1);

        expect_ram(5, 32'd3);
        expect_ram(6, 32'd3);

        $display("PASS 6: barco 2 horizontal");
        $display("PASS: colocacion completa J1");

        // ============================================================
        // 7. Ignorar un cuarto intento de colocacion
        //
        // La flota J1 ya esta completa. Un nuevo OK no debe
        // modificar CURRENT_SHIP, PLACED_J1, BOARD_J1 ni VGA.
        // ============================================================

        press_button(BTN_OK);

        // CURRENT_SHIP y PLACED_J1 deben permanecer en 3.
        expect_ram(5, 32'd3);
        expect_ram(6, 32'd3);

        // Barco 0: (0,0)..(0,3).
        expect_ram(64, 32'd1);
        expect_ram(65, 32'd1);
        expect_ram(66, 32'd1);
        expect_ram(67, 32'd1);

        // Barco 1: (0,6), (1,6), (2,6).
        expect_ram(70, 32'd2);
        expect_ram(78, 32'd2);
        expect_ram(86, 32'd2);

        // Barco 2: (1,0), (1,1).
        expect_ram(72, 32'd3);
        expect_ram(73, 32'd3);

        // Una celda libre debe continuar libre.
        expect_ram(74, 32'd0);

        // Comprobar tambien posiciones representativas en VGA.
        expect_vga(0,  32'd1);
        expect_vga(6,  32'd1);
        expect_vga(20, 32'd1);
        expect_vga(22, 32'd0);

        $display("PASS 7: cuarto barco ignorado");

        // ============================================================
        // 8. Recepcion basica UART
        //
        // Enviar el caracter ASCII 'P' (0x50).
        // El firmware debe:
        //   1. detectar RX_VALID,
        //   2. leer UART_RX,
        //   3. guardar 0x50 en UART_LAST_BYTE (0x2500),
        //   4. limpiar RX_VALID.
        // ============================================================

        uart_send_byte(8'h50);

        // Dar tiempo al firmware para consumir el byte.
        repeat (200) @(negedge clk_i);

        // 0x2500 corresponde a RAM[320].
        expect_ram(320, 32'h0000_0050);

        // RX_VALID debe haber sido limpiado por poll_uart.
        if (dut.u_uart.rx_pending_r !== 1'b0) begin
            $display(
                "ERROR UART RX_VALID: esperado=0 obtenido=%b",
                dut.u_uart.rx_pending_r
            );
            errors = errors + 1;
        end

        $display("PASS 8: recepcion UART byte 0x50");

        // ============================================================
        // 9. Parser UART: trama P completa
        //
        // Como la prueba 8 dejo al parser esperando la coma despues
        // de 'P', primero se envia LF para forzar el descarte de esa
        // trama incompleta. Luego se envia:
        //
        //     P,0,0,0,H\n
        //
        // Resultado esperado:
        //   PARSE_STATE = 0
        //   SHIP        = 0
        //   ROW         = 0
        //   COL         = 0
        //   ORIENT      = 0  (H)
        //   FRAME_READY = 0  (consumido por process_uart_frame)
        // ============================================================

        // Descartar la 'P' aislada de la prueba anterior.
        uart_send_byte(8'h0A);
        repeat (200) @(negedge clk_i);

        // P,0,0,0,H\n
        //
        // Al mismo tiempo se escucha uart_tx_o. Si la colocacion
        // es aceptada, la FPGA debe responder:
        //
        //     PA,0\n
        //
        fork
            begin
                uart_send_byte(8'h50); // P
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h48); // H
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
            end
        join

        // Verificar respuesta PA,0\n.
        if (uart_tx_byte0 !== 8'h50 ||
            uart_tx_byte1 !== 8'h41 ||
            uart_tx_byte2 !== 8'h2C ||
            uart_tx_byte3 !== 8'h30 ||
            uart_tx_byte4 !== 8'h0A) begin

            $display(
                "ERROR UART TX PA: recibido=%h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // 0x2504 / 4 relativo a RAM 0x2000 -> RAM[321].
        expect_ram(321, 32'd0); // UART_PARSE_STATE
        expect_ram(322, 32'd0); // UART_SHIP
        expect_ram(323, 32'd0); // UART_ROW
        expect_ram(324, 32'd0); // UART_COL
        expect_ram(325, 32'd0); // UART_ORIENT = H
        expect_ram(326, 32'd0); // UART_FRAME_READY consumido

        // BOARD_J2 empieza en RAM[128].
        // Barco 0 horizontal en (0,0), longitud 4.
        expect_ram(128, 32'd1);
        expect_ram(129, 32'd1);
        expect_ram(130, 32'd1);
        expect_ram(131, 32'd1);
        expect_ram(132, 32'd0);

        // PLACED_J2 = RAM[7].
        expect_ram(7, 32'd1);

        // J2_SHIP_MASK = 0b001.
        expect_ram(327, 32'd1);

        if (dut.u_uart.rx_pending_r !== 1'b0) begin
            $display(
                "ERROR parser UART RX_VALID: esperado=0 obtenido=%b",
                dut.u_uart.rx_pending_r
            );
            errors = errors + 1;
        end

        $display("PASS 9: parser UART P,0,0,0,H");

        // ============================================================
        // 10. Parser UART con campos no nulos y orientacion vertical
        //
        // Trama:
        //     P,2,6,4,V\n
        //
        // Resultado esperado:
        //   PARSE_STATE = 0
        //   SHIP        = 2
        //   ROW         = 6
        //   COL         = 4
        //   ORIENT      = 1  (V)
        //   FRAME_READY = 0  (consumido por process_uart_frame)
        // ============================================================

        uart_send_byte(8'h50); // P
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h32); // 2
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h36); // 6
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h34); // 4
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h56); // V
        uart_send_byte(8'h0A); // LF

        repeat (300) @(negedge clk_i);

        expect_ram(321, 32'd0); // UART_PARSE_STATE
        expect_ram(322, 32'd2); // UART_SHIP
        expect_ram(323, 32'd6); // UART_ROW
        expect_ram(324, 32'd4); // UART_COL
        expect_ram(325, 32'd1); // UART_ORIENT = V
        expect_ram(326, 32'd0); // UART_FRAME_READY consumido

        // Barco 2 vertical en (6,4), longitud 2.
        // BOARD_J2 almacena ship+1 = 3.
        expect_ram(180, 32'd3);
        expect_ram(188, 32'd3);

        // Una celda vecina debe continuar libre.
        expect_ram(181, 32'd0);

        // Dos barcos aceptados.
        expect_ram(7, 32'd2);

        // Barcos 0 y 2 colocados: 0b101.
        expect_ram(327, 32'd5);

        if (dut.u_uart.rx_pending_r !== 1'b0) begin
            $display(
                "ERROR parser UART RX_VALID: esperado=0 obtenido=%b",
                dut.u_uart.rx_pending_r
            );
            errors = errors + 1;
        end

        $display("PASS 10: parser UART P,2,6,4,V");

        // ============================================================
        // 11. Parser UART: rechazo de trama invalida
        //
        // Trama:
        //     P,2,8,4,V\n
        //
        // La fila 8 es invalida. El parser debe descartar la trama,
        // volver al estado 0 y NO activar FRAME_READY.
        // ============================================================

        uart_send_byte(8'h50); // P
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h32); // 2
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h38); // 8 -> invalido
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h34); // 4
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h56); // V
        uart_send_byte(8'h0A); // LF

        repeat (300) @(negedge clk_i);

        expect_ram(321, 32'd0); // UART_PARSE_STATE
        expect_ram(326, 32'd0); // UART_FRAME_READY

        // La trama invalida no debe modificar la colocacion de J2.
        expect_ram(7,   32'd2); // PLACED_J2 sigue en 2
        expect_ram(327, 32'd5); // mascara sigue en 0b101

        if (dut.u_uart.rx_pending_r !== 1'b0) begin
            $display(
                "ERROR parser invalido RX_VALID: esperado=0 obtenido=%b",
                dut.u_uart.rx_pending_r
            );
            errors = errors + 1;
        end

        $display("PASS 11: trama invalida descartada");

        // ============================================================
        // 12. Rechazo de traslape y ship ID duplicado en J2
        // ============================================================

        // ------------------------------------------------------------
        // 12a. Traslape:
        //     P,1,0,2,V\n
        //
        // La celda (0,2) ya pertenece al barco 0.
        // Respuesta esperada:
        //     PR,1,O\n
        // ------------------------------------------------------------
        fork
            begin
                uart_send_byte(8'h50); // P
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h31); // 1
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h32); // 2
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h56); // V
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
            end
        join

        // PR,1,O\n
        if (uart_tx_byte0 !== 8'h50 ||
            uart_tx_byte1 !== 8'h52 ||
            uart_tx_byte2 !== 8'h2C ||
            uart_tx_byte3 !== 8'h31 ||
            uart_tx_byte4 !== 8'h2C ||
            uart_tx_byte5 !== 8'h4F ||
            uart_tx_byte6 !== 8'h0A) begin

            $display(
                "ERROR UART TX PR,O traslape: recibido=%h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // No debe aceptarse.
        expect_ram(7,   32'd2); // PLACED_J2
        expect_ram(327, 32'd5); // J2_SHIP_MASK = 0b101

        // Las celdas siguientes del intento deben seguir libres.
        // (1,2) -> indice 10 -> RAM[138]
        // (2,2) -> indice 18 -> RAM[146]
        expect_ram(138, 32'd0);
        expect_ram(146, 32'd0);

        // ------------------------------------------------------------
        // 12b. Ship ID duplicado:
        //     P,0,3,0,H\n
        //
        // La posicion esta libre, pero ship 0 ya fue colocado.
        // Respuesta esperada:
        //     PR,0,O\n
        // ------------------------------------------------------------
        fork
            begin
                uart_send_byte(8'h50); // P
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h33); // 3
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h48); // H
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
            end
        join

        // PR,0,O\n
        if (uart_tx_byte0 !== 8'h50 ||
            uart_tx_byte1 !== 8'h52 ||
            uart_tx_byte2 !== 8'h2C ||
            uart_tx_byte3 !== 8'h30 ||
            uart_tx_byte4 !== 8'h2C ||
            uart_tx_byte5 !== 8'h4F ||
            uart_tx_byte6 !== 8'h0A) begin

            $display(
                "ERROR UART TX PR,O duplicado: recibido=%h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // Tampoco debe aceptarse.
        expect_ram(7,   32'd2);
        expect_ram(327, 32'd5);

        // (3,0)..(3,3) deben continuar libres.
        expect_ram(152, 32'd0);
        expect_ram(153, 32'd0);
        expect_ram(154, 32'd0);
        expect_ram(155, 32'd0);

        $display("PASS 12: PR,O por traslape y barco duplicado J2");

        // ============================================================
        // 13. Rechazo J2 por fuera de tablero
        //
        // Trama sintacticamente valida:
        //     P,1,7,7,V\n
        //
        // El barco 1 tiene longitud 3, por lo que no cabe verticalmente
        // desde la fila 7. La FPGA debe responder:
        //
        //     PR,1,F\n
        // ============================================================

        fork
            begin
                uart_send_byte(8'h50); // P
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h31); // 1
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h37); // 7
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h37); // 7
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h56); // V
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
            end
        join

        // PR,1,F\n
        if (uart_tx_byte0 !== 8'h50 ||
            uart_tx_byte1 !== 8'h52 ||
            uart_tx_byte2 !== 8'h2C ||
            uart_tx_byte3 !== 8'h31 ||
            uart_tx_byte4 !== 8'h2C ||
            uart_tx_byte5 !== 8'h46 ||
            uart_tx_byte6 !== 8'h0A) begin

            $display(
                "ERROR UART TX PR,F: recibido=%h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El rechazo no debe modificar la flota.
        expect_ram(7,   32'd2); // PLACED_J2
        expect_ram(327, 32'd5); // J2_SHIP_MASK = 0b101

        $display("PASS 13: rechazo J2 fuera de tablero -> PR,1,F");

        // ============================================================
        // 14. Completar colocacion de la flota del Jugador 2
        //
        // Trama:
        //     P,1,3,0,H\n
        //
        // Barco 1: longitud 3.
        // Debe ocupar (3,0), (3,1), (3,2).
        // ============================================================

        fork
            begin
                uart_send_byte(8'h50); // P
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h31); // 1
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h33); // 3
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h48); // H
                uart_send_byte(8'h0A); // LF
            end

            begin
                // PA,1\n
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);

                // B\n
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);

                // T,1\n
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                uart_receive_byte(uart_tx_byte9);
                uart_receive_byte(uart_tx_byte10);
            end
        join

        // Secuencia completa esperada:
        //     PA,1\n
        //     B\n
        //     T,1\n
        if (uart_tx_byte0  !== 8'h50 ||
            uart_tx_byte1  !== 8'h41 ||
            uart_tx_byte2  !== 8'h2C ||
            uart_tx_byte3  !== 8'h31 ||
            uart_tx_byte4  !== 8'h0A ||
            uart_tx_byte5  !== 8'h42 ||
            uart_tx_byte6  !== 8'h0A ||
            uart_tx_byte7  !== 8'h54 ||
            uart_tx_byte8  !== 8'h2C ||
            uart_tx_byte9  !== 8'h31 ||
            uart_tx_byte10 !== 8'h0A) begin

            $display(
                "ERROR UART inicio batalla: %h %h %h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8,
                uart_tx_byte9,
                uart_tx_byte10
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // BOARD_J2 empieza en RAM[128].
        // Fila 3 -> indice 24 -> RAM[152].
        // ship 1 se almacena como valor 2.
        expect_ram(152, 32'd2);
        expect_ram(153, 32'd2);
        expect_ram(154, 32'd2);

        // La siguiente celda debe continuar libre.
        expect_ram(155, 32'd0);

        // Flota completa de J2.
        expect_ram(7,   32'd3); // PLACED_J2
        expect_ram(327, 32'd7); // J2_SHIP_MASK = 0b111

        // FRAME_READY debe haber sido consumido.
        expect_ram(326, 32'd0);

        // Ambas flotas completas deben iniciar automaticamente
        // el estado de batalla con turno inicial del Jugador 1.
        expect_ram(0, 32'd1); // GAME_STATE = STATE_BATTLE
        expect_ram(1, 32'd1); // TURN = J1

        $display("PASS 14: flotas completas -> batalla, PA + B + T,1");

        // ============================================================
        // 15. Disparo local de J1: impacto
        //
        // Al comenzar la batalla:
        //   GAME_STATE = BATTLE
        //   TURN       = J1
        //   cursor     = (0,0)
        //
        // BOARD_J2(0,0) pertenece al barco 0, por lo que el disparo
        // debe registrarse como CELL_HIT.
        // ============================================================

        // Verificar condiciones iniciales del disparo.
        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd1);    // TURN = J1
        expect_ram(2, 32'd0);    // CURSOR_ROW
        expect_ram(3, 32'd0);    // CURSOR_COL

        // BOARD_J2[0] = RAM[128] debe contener ship 0 almacenado como 1.
        expect_ram(128, 32'd1);

        // SHOTS_J1[0] = RAM[192] aun no disparado.
        expect_ram(192, 32'd0);

        // Disparar con BTN_OK y capturar simultaneamente
        // la respuesta UART:
        //
        //     DR,0,0,I\n
        //
        // Es necesario recibir mientras el firmware transmite,
        // ya que uart_putc espera TX_BUSY antes del siguiente byte.
        fork
            begin
                press_button(6'b100000);
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h32); // T,2\n
            end
        join

        // Verificar DR,0,0,I\n.
        if (uart_tx_byte0 !== 8'h44 ||  // D
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h30 ||  // 0
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h49 ||  // I
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART DR HIT: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El disparo debe quedar registrado como impacto.
        expect_ram(192, 32'd2);  // CELL_HIT

        // El tablero real del J2 conserva la identidad del barco.
        expect_ram(128, 32'd1);

        // VGA enemigo:
        // fila 0, columna visual 10
        // tile = 0*20 + 10 = 10
        // Debe mostrar CELL_HIT.
        expect_vga(10, 32'd2);

        // Un disparo valido entrega el turno al Jugador 2.
        expect_ram(1, 32'd2);

        $display("PASS 15: disparo J1 (0,0) -> HIT, VGA y TURN=2");

        // ============================================================
        // 16. Disparo UART de J2: impacto
        //
        // Trama:
        //     S,0,0\\n
        //
        // BOARD_J1(0,0) pertenece al barco 0.
        // Por tanto, J2 debe obtener un HIT.
        // ============================================================

        // Después del disparo de J1, corresponde el turno al J2.
        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd2);    // TURN = J2

        // SHOTS_J2[0] = RAM[256] aun no disparado.
        expect_ram(256, 32'd0);

        // Enviar S,0,0\n y recibir simultaneamente:
        //
        //     SR,0,0,I\n
        fork
            begin
                uart_send_byte(8'h53); // S
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h31); // T,1\n
            end
        join

        // Verificar SR,0,0,I\n.
        if (uart_tx_byte0 !== 8'h53 ||  // S
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h30 ||  // 0
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h49 ||  // I
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART SR HIT: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El disparo debe quedar registrado como HIT.
        expect_ram(256, 32'd2);   // SHOTS_J2[0] = CELL_HIT

        // El tablero real de J1 conserva la identidad del barco.
        expect_ram(64, 32'd1);    // BOARD_J1[0]

        // VGA del tablero J1:
        // fila 0, columna 0 -> tile 0.
        expect_vga(0, 32'd2);

        // Un disparo valido devuelve el turno a J1.
        expect_ram(1, 32'd1);

        $display("PASS 16: disparo UART J2 (0,0) -> HIT, VGA y TURN=1");

        // ============================================================
        // 17. Disparo local de J1: fallo
        //
        // Estado despues del disparo UART de J2:
        //   GAME_STATE = BATTLE
        //   TURN       = J1
        //   cursor     = (0,0)
        //
        // La casilla (0,4) de BOARD_J2 esta libre.
        // Por tanto, el disparo debe registrarse como CELL_MISS.
        // ============================================================

        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd1);    // TURN = J1
        expect_ram(2, 32'd0);    // CURSOR_ROW
        expect_ram(3, 32'd0);    // CURSOR_COL

        // BOARD_J2(0,4) = RAM[132] debe ser agua.
        expect_ram(132, 32'd0);

        // SHOTS_J1(0,4) = RAM[196] aun no disparado.
        expect_ram(196, 32'd0);

        // Mover cursor de (0,0) a (0,4).
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT

        repeat (100) @(negedge clk_i);

        expect_ram(3, 32'd4);     // CURSOR_COL = 4

        // Disparar con BTN_OK y recibir simultaneamente:
        //
        //     DR,0,4,F\n
        //
        // Consumir toda la respuesta evita dejar bytes UART
        // pendientes para las pruebas posteriores.
        fork
            begin
                press_button(6'b100000);
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h32); // T,2\n
            end
        join

        // Verificar DR,0,4,F\n.
        if (uart_tx_byte0 !== 8'h44 ||  // D
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h34 ||  // 4
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h46 ||  // F
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART DR MISS: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El disparo debe quedar registrado como MISS.
        expect_ram(196, 32'd3);   // CELL_MISS

        // El tablero real de J2 permanece sin modificar.
        expect_ram(132, 32'd0);

        // VGA enemigo:
        // fila 0, columna visual 10 + 4 = 14.
        // tile = 14.
        expect_vga(14, 32'd3);

        // Un disparo valido devuelve el turno al Jugador 2.
        expect_ram(1, 32'd2);

        $display("PASS 17: disparo J1 (0,4) -> MISS, VGA y TURN=2");

        // ============================================================
        // 18. Disparo UART de J2: MISS
        //
        // Trama:
        //     S,0,4\n
        //
        // BOARD_J1(0,4) esta libre.
        // Por tanto, J2 debe obtener un MISS.
        // ============================================================

        // Despues del disparo de J1, corresponde el turno al J2.
        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd2);    // TURN = J2

        // SHOTS_J2[4] = RAM[260] aun no disparado.
        expect_ram(260, 32'd0);

        // Enviar S,0,4\n y recibir simultaneamente:
        //
        //     SR,0,4,F\n
        fork
            begin
                uart_send_byte(8'h53); // S
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h34); // 4
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h31); // T,1\n
            end
        join

        // Verificar SR,0,4,F\n.
        if (uart_tx_byte0 !== 8'h53 ||  // S
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h34 ||  // 4
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h46 ||  // F
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART SR MISS: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El disparo debe quedar registrado como MISS.
        expect_ram(260, 32'd3);   // SHOTS_J2[4] = CELL_MISS

        // El tablero real de J1 permanece sin modificar.
        expect_ram(68, 32'd0);    // BOARD_J1[4]

        // VGA del tablero J1:
        // fila 0, columna visual 10 + 4 = 14.
        expect_vga(14, 32'd3);

        // Un disparo valido devuelve el turno a J1.
        expect_ram(1, 32'd1);

        $display("PASS 18: disparo UART J2 (0,4) -> MISS, VGA y TURN=1");

        // ============================================================
        // 19. Disparo repetido de J1: debe ser ignorado
        //
        // J1 ya disparo anteriormente en (0,0) y obtuvo HIT.
        // Un segundo disparo sobre la misma casilla no debe:
        //   - modificar SHOTS_J1
        //   - modificar VGA
        //   - cambiar el turno
        // ============================================================

        // Despues del PASS 18 corresponde nuevamente el turno a J1.
        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd1);    // TURN = J1

        // La casilla (0,0) ya fue disparada por J1.
        expect_ram(192, 32'd2);  // SHOTS_J1[0] = CELL_HIT
        expect_vga(10, 32'd2);   // VGA enemigo: tile 10 = CELL_HIT

        // Intentar disparar nuevamente en (0,0).
        press_button(6'b100000); // BTN_OK

        repeat (300) @(negedge clk_i);

        // El disparo repetido debe ser ignorado.
        expect_ram(192, 32'd2);  // SHOTS_J1[0] permanece HIT

        // La VGA debe permanecer sin cambios.
        expect_vga(10, 32'd2);

        // El turno debe permanecer en J1.
        expect_ram(1, 32'd1);

        $display("PASS 19: disparo J1 repetido (0,0) -> ignorado, TURN=1");

        // ============================================================
        // 20. Disparo repetido UART de J2: debe ser ignorado
        //
        // Despues del PASS 19 corresponde el turno a J1.
        //
        // El cursor de J1 se desplaza mediante BTN_RIGHT. Debido al
        // comportamiento del debounce del testbench, las llamadas a
        // press_button() pueden generar mas de un incremento.
        // En esta prueba el cursor queda en (0,7).
        // ============================================================

        expect_ram(0, 32'd1);    // GAME_STATE = BATTLE
        expect_ram(1, 32'd1);    // TURN = J1

        // Mover el cursor hacia la derecha.
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT
        press_button(6'b001000); // BTN_RIGHT

        repeat (300) @(negedge clk_i);

        // En esta simulacion el cursor queda en (0,7).
        expect_ram(2, 32'd0);    // CURSOR_ROW
        expect_ram(3, 32'd7);    // CURSOR_COL

        // SHOTS_J1[7] = RAM[199].
        expect_ram(199, 32'd0);

        // Disparar en (0,7) y consumir:
        //
        //     DR,0,7,F\n
        //     T,2\n
        fork
            begin
                press_button(6'b100000); // BTN_OK
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);

                if (uart_tx_byte0 !== 8'h44 ||  // D
                    uart_tx_byte1 !== 8'h52 ||  // R
                    uart_tx_byte2 !== 8'h2C ||  // ,
                    uart_tx_byte3 !== 8'h30 ||  // 0
                    uart_tx_byte4 !== 8'h2C ||  // ,
                    uart_tx_byte5 !== 8'h37 ||  // 7
                    uart_tx_byte6 !== 8'h2C ||  // ,
                    uart_tx_byte7 !== 8'h46 ||  // F
                    uart_tx_byte8 !== 8'h0A) begin

                    $display(
                        "ERROR UART DR PASS20: recibido=%h %h %h %h %h %h %h %h %h",
                        uart_tx_byte0, uart_tx_byte1, uart_tx_byte2,
                        uart_tx_byte3, uart_tx_byte4, uart_tx_byte5,
                        uart_tx_byte6, uart_tx_byte7, uart_tx_byte8
                    );
                    errors = errors + 1;
                end

                expect_turn_uart(8'h32); // T,2\n
            end
        join

        repeat (300) @(negedge clk_i);

        // (0,7) esta libre en BOARD_J2, por lo que es MISS.
        expect_ram(199, 32'd3);  // CELL_MISS

        // Tile enemigo:
        // fila 0, columna visual 10 + 7 = 17.
        expect_vga(17, 32'd3);

        // El turno pasa a J2.
        expect_ram(1, 32'd2);

        // ------------------------------------------------------------
        // Intentar nuevamente S,0,0 por UART.
        //
        // J2 ya disparo anteriormente en (0,0), por lo que este
        // disparo repetido debe ser ignorado.
        // ------------------------------------------------------------

        // El disparo anterior de J2 permanece como HIT.
        expect_ram(256, 32'd2);
        expect_vga(0, 32'd2);

        fork
            begin
                uart_send_byte(8'h53); // S
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h0A); // LF
            end
        join

        repeat (300) @(negedge clk_i);

        // El disparo repetido no debe modificar la casilla.
        expect_ram(256, 32'd2);
        expect_vga(0, 32'd2);

        // El turno tampoco debe cambiar.
        expect_ram(1, 32'd2);

        $display("PASS 20: disparo UART J2 repetido (0,0) -> ignorado, TURN=2");





        // ============================================================
        // 21. Hundimiento del barco 0 de J2
        //
        // El barco 0 de J2 ocupa:
        //     (0,0), (0,1), (0,2), (0,3)
        //
        // (0,0) ya fue impactado realmente en PASS 15.
        // Para aislar la prueba de deteccion de hundimiento se
        // precargan (0,1) y (0,2) como impactos previos.
        //
        // El firmware realiza realmente el ultimo disparo en (0,3).
        // Respuesta esperada:
        //
        //     DR,0,3,H\n
        // ============================================================

        // Preparar turno de J1.
        dut.u_processor.ram.words[1] = 32'd1;   // TURN = J1

        // Preparar cursor en (0,3).
        dut.u_processor.ram.words[2] = 32'd0;   // CURSOR_ROW
        dut.u_processor.ram.words[3] = 32'd3;   // CURSOR_COL

        // Impactos previos del barco 0.
        // SHOTS_J1 comienza en RAM[192].
        expect_ram(192, 32'd2);                 // (0,0), PASS 15
        dut.u_processor.ram.words[193] = 32'd2; // (0,1)
        dut.u_processor.ram.words[194] = 32'd2; // (0,2)

        // La ultima celda aun no ha sido disparada.
        expect_ram(195, 32'd0);                 // (0,3)

        // Confirmar que las cuatro celdas pertenecen al barco 0.
        expect_ram(128, 32'd1);
        expect_ram(129, 32'd1);
        expect_ram(130, 32'd1);
        expect_ram(131, 32'd1);

        // Ejecutar realmente el disparo final y capturar:
        //
        //     DR,0,3,H\n
        fork
            begin
                press_button(6'b100000); // BTN_OK
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h32); // T,2\n
            end
        join

        // Verificar DR,0,3,H\n.
        if (uart_tx_byte0 !== 8'h44 ||  // D
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h33 ||  // 3
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h48 ||  // H
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART DR HUNDIDO: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El ultimo disparo debe registrarse como HIT.
        expect_ram(195, 32'd2);                 // SHOTS_J1(0,3)

        // BOARD_J2 conserva la identidad del barco.
        expect_ram(131, 32'd1);

        // Las cuatro celdas del barco estan impactadas.
        expect_ram(192, 32'd2);
        expect_ram(193, 32'd2);
        expect_ram(194, 32'd2);
        expect_ram(195, 32'd2);

        // VGA enemigo: columna visual = 10 + 3 = 13.
        expect_vga(13, 32'd2);

        // El disparo valido entrega el turno a J2.
        expect_ram(1, 32'd2);

        $display("PASS 21: barco 0 J2 hundido -> DR,0,3,H");


        // ============================================================
        // 22. Hundimiento del barco 0 de J1 mediante disparo UART J2
        //
        // El barco 0 de J1 ocupa:
        //     (0,0), (0,1), (0,2), (0,3)
        //
        // (0,0) ya fue impactado realmente en PASS 16.
        // Se precargan (0,1) y (0,2) como impactos previos.
        //
        // J2 realiza realmente el ultimo disparo:
        //
        //     S,0,3\n
        //
        // Respuesta esperada:
        //
        //     SR,0,3,H\n
        // ============================================================

        // Preparar turno de J2.
        dut.u_processor.ram.words[1] = 32'd2;   // TURN = J2

        // SHOTS_J2 comienza en RAM[256].
        expect_ram(256, 32'd2);                 // (0,0), PASS 16
        dut.u_processor.ram.words[257] = 32'd2; // (0,1)
        dut.u_processor.ram.words[258] = 32'd2; // (0,2)

        // La ultima celda aun no ha sido disparada.
        expect_ram(259, 32'd0);                 // (0,3)

        // Confirmar identidad del barco 0 de J1.
        expect_ram(64, 32'd1);
        expect_ram(65, 32'd1);
        expect_ram(66, 32'd1);
        expect_ram(67, 32'd1);

        // Enviar S,0,3\n y recibir simultaneamente SR,0,3,H\n.
        fork
            begin
                uart_send_byte(8'h53); // S
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h30); // 0
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h33); // 3
                uart_send_byte(8'h0A); // LF
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);
                expect_turn_uart(8'h31); // T,1\n
            end
        join

        // Verificar SR,0,3,H\n.
        if (uart_tx_byte0 !== 8'h53 ||  // S
            uart_tx_byte1 !== 8'h52 ||  // R
            uart_tx_byte2 !== 8'h2C ||  // ,
            uart_tx_byte3 !== 8'h30 ||  // 0
            uart_tx_byte4 !== 8'h2C ||  // ,
            uart_tx_byte5 !== 8'h33 ||  // 3
            uart_tx_byte6 !== 8'h2C ||  // ,
            uart_tx_byte7 !== 8'h48 ||  // H
            uart_tx_byte8 !== 8'h0A) begin

            $display(
                "ERROR UART SR HUNDIDO: recibido=%h %h %h %h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5,
                uart_tx_byte6,
                uart_tx_byte7,
                uart_tx_byte8
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // El disparo final debe quedar registrado como HIT.
        expect_ram(259, 32'd2);

        // BOARD_J1 conserva la identidad del barco.
        expect_ram(67, 32'd1);

        // Las cuatro celdas del barco quedaron impactadas.
        expect_ram(256, 32'd2);
        expect_ram(257, 32'd2);
        expect_ram(258, 32'd2);
        expect_ram(259, 32'd2);

        // VGA de J1: fila 0, columna 3 -> tile 3.
        expect_vga(3, 32'd2);

        // Tras el disparo valido vuelve el turno a J1.
        expect_ram(1, 32'd1);

        $display("PASS 22: barco 0 J1 hundido -> SR,0,3,H");


        // ============================================================
        // 23. Victoria del Jugador 1
        //
        // Flota J2:
        //   barco 0: (0,0)..(0,3)
        //   barco 1: (3,0)..(3,2)
        //   barco 2: (6,4),(7,4)
        //
        // Se dejan todas las celdas impactadas excepto (7,4).
        // El ultimo disparo real debe producir:
        //
        //     DR,7,4,H\n
        //     FIN,1\n
        //
        // y llevar el juego a STATE_FINISHED.
        // ============================================================

        // J1 debe tener el turno para realizar el disparo final.
        dut.u_processor.ram.words[1] = 32'd1;

        // Barco 0 de J2 ya estaba hundido en PASS 21:
        // SHOTS_J1[0..3] = RAM[192..195].
        expect_ram(192, 32'd2);
        expect_ram(193, 32'd2);
        expect_ram(194, 32'd2);
        expect_ram(195, 32'd2);

        // Preparar barco 1 de J2 como completamente impactado.
        // indices 24,25,26 -> RAM[216], RAM[217], RAM[218].
        dut.u_processor.ram.words[216] = 32'd2;
        dut.u_processor.ram.words[217] = 32'd2;
        dut.u_processor.ram.words[218] = 32'd2;

        // Preparar primera celda del barco 2:
        // (6,4) -> indice 52 -> RAM[244].
        dut.u_processor.ram.words[244] = 32'd2;

        // Ultima celda:
        // (7,4) -> indice 60 -> RAM[252].
        expect_ram(252, 32'd0);

        // Confirmar que BOARD_J2 contiene el barco 2.
        // BOARD_J2 base RAM[128]:
        // indice 52 -> RAM[180]
        // indice 60 -> RAM[188]
        expect_ram(180, 32'd3);
        expect_ram(188, 32'd3);

        // Colocar cursor en (7,4).
        dut.u_processor.ram.words[2] = 32'd7;
        dut.u_processor.ram.words[3] = 32'd4;

        // El marcador comienza en cero.
        expect_ram(8, 32'd0);    // WINS_J1
        expect_ram(9, 32'd0);    // WINS_J2

        // El disparo final genera dos mensajes:
        //
        //   DR,7,4,H\n  -> 9 bytes
        //   FIN,1\n     -> 6 bytes
        //
        // Total = 15 bytes.
        fork
            begin
                press_button(6'b100000);
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);

                // Reutilizamos variables despues de verificar DR
                // mediante comprobacion inmediata.
                if (uart_tx_byte0 !== 8'h44 ||  // D
                    uart_tx_byte1 !== 8'h52 ||  // R
                    uart_tx_byte2 !== 8'h2C ||  // ,
                    uart_tx_byte3 !== 8'h37 ||  // 7
                    uart_tx_byte4 !== 8'h2C ||  // ,
                    uart_tx_byte5 !== 8'h34 ||  // 4
                    uart_tx_byte6 !== 8'h2C ||  // ,
                    uart_tx_byte7 !== 8'h48 ||  // H
                    uart_tx_byte8 !== 8'h0A) begin
                    $display(
                        "ERROR UART DR VICTORIA J1: recibido=%h %h %h %h %h %h %h %h %h",
                        uart_tx_byte0, uart_tx_byte1, uart_tx_byte2,
                        uart_tx_byte3, uart_tx_byte4, uart_tx_byte5,
                        uart_tx_byte6, uart_tx_byte7, uart_tx_byte8
                    );
                    errors = errors + 1;
                end

                // FIN,1\n
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);

                if (uart_tx_byte0 !== 8'h46 ||  // F
                    uart_tx_byte1 !== 8'h49 ||  // I
                    uart_tx_byte2 !== 8'h4E ||  // N
                    uart_tx_byte3 !== 8'h2C ||  // ,
                    uart_tx_byte4 !== 8'h31 ||  // 1
                    uart_tx_byte5 !== 8'h0A) begin
                    $display(
                        "ERROR UART FIN J1: recibido=%h %h %h %h %h %h",
                        uart_tx_byte0, uart_tx_byte1, uart_tx_byte2,
                        uart_tx_byte3, uart_tx_byte4, uart_tx_byte5
                    );
                    errors = errors + 1;
                end
            end
        join

        repeat (300) @(negedge clk_i);

        // Ultimo impacto registrado.
        expect_ram(252, 32'd2);

        // El tablero real conserva la identidad del barco.
        expect_ram(188, 32'd3);

        // Estado final.
        expect_ram(0, 32'd2);    // STATE_FINISHED

        // Marcador.
        expect_ram(8, 32'd1);    // WINS_J1 = 1
        expect_ram(9, 32'd0);    // WINS_J2 = 0

        // LED_FINISHED = 4.
        if (led_o !== 3'b100) begin
            $display(
                "ERROR LED victoria J1: esperado=100 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        // VGA de (7,4) en tablero enemigo:
        // tile = 7*20 + (10+4) = 154.
        expect_vga(154, 32'd2);

        $display("PASS 23: victoria J1 -> DR,7,4,H + FIN,1 + STATE_FINISHED + WINS_J1");


        // ============================================================
        // 24. Reinicio despues de victoria
        //
        // BTN_RST debe iniciar una nueva partida pero conservar
        // el marcador acumulado.
        //
        // Antes del reset:
        //   STATE_FINISHED
        //   WINS_J1 = 1
        //   WINS_J2 = 0
        //
        // Despues:
        //   STATE_PLACEMENT
        //   WINS_J1 = 1
        //   WINS_J2 = 0
        //   tableros y disparos limpios
        // ============================================================

        expect_ram(0, 32'd2);    // STATE_FINISHED
        expect_ram(8, 32'd1);    // WINS_J1
        expect_ram(9, 32'd0);    // WINS_J2

        // BTN_RST = bit 6.
        press_button(7'b1000000);

        // Dar tiempo a init_game para limpiar RAM/VGA.
        repeat (1000) @(negedge clk_i);

        // Nueva partida.
        expect_ram(0, 32'd0);    // STATE_PLACEMENT
        expect_ram(1, 32'd1);    // TURN = J1

        // Cursor y orientacion reiniciados.
        expect_ram(2, 32'd0);    // CURSOR_ROW
        expect_ram(3, 32'd0);    // CURSOR_COL
        expect_ram(4, 32'd0);    // ORIENTATION
        expect_ram(5, 32'd0);    // CURRENT_SHIP

        // Ninguna flota colocada.
        expect_ram(6, 32'd0);    // PLACED_J1
        expect_ram(7, 32'd0);    // PLACED_J2

        // El marcador DEBE conservarse.
        expect_ram(8, 32'd1);    // WINS_J1
        expect_ram(9, 32'd0);    // WINS_J2

        // Verificar algunas posiciones que estaban ocupadas/impactadas
        // en la partida anterior.

        // BOARD_J1
        expect_ram(64, 32'd0);
        expect_ram(67, 32'd0);

        // BOARD_J2
        expect_ram(128, 32'd0);
        expect_ram(188, 32'd0);

        // SHOTS_J1
        expect_ram(192, 32'd0);
        expect_ram(252, 32'd0);

        // SHOTS_J2
        expect_ram(256, 32'd0);
        expect_ram(259, 32'd0);

        // LED vuelve al estado de colocacion.
        if (led_o !== 3'b001) begin
            $display(
                "ERROR LED reset: esperado=001 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        $display("PASS 24: BTN_RST reinicia partida y conserva WINS_J1=1");


        // ============================================================
        // 25. Victoria del Jugador 2
        //
        // Se prepara una flota completa de J1:
        //
        //   barco 0: (0,0)..(0,3)
        //   barco 1: (3,0)..(3,2)
        //   barco 2: (6,4),(7,4)
        //
        // Todas las celdas estan impactadas excepto (7,4).
        // J2 realiza el ultimo disparo mediante:
        //
        //     S,7,4\n
        //
        // Respuestas esperadas:
        //
        //     SR,7,4,H\n
        //     FIN,2\n
        // ============================================================

        // Forzar estado de batalla y turno de J2.
        dut.u_processor.ram.words[0] = 32'd1;   // STATE_BATTLE
        dut.u_processor.ram.words[1] = 32'd2;   // TURN = J2

        // ------------------------------------------------------------
        // Preparar BOARD_J1.
        // BOARD_J1 base = RAM[64].
        // ------------------------------------------------------------

        // Barco 0: (0,0)..(0,3), identidad 1.
        dut.u_processor.ram.words[64] = 32'd1;
        dut.u_processor.ram.words[65] = 32'd1;
        dut.u_processor.ram.words[66] = 32'd1;
        dut.u_processor.ram.words[67] = 32'd1;

        // Barco 1: (3,0)..(3,2), indices 24..26.
        dut.u_processor.ram.words[88] = 32'd2;
        dut.u_processor.ram.words[89] = 32'd2;
        dut.u_processor.ram.words[90] = 32'd2;

        // Barco 2: (6,4) y (7,4), indices 52 y 60.
        dut.u_processor.ram.words[116] = 32'd3;
        dut.u_processor.ram.words[124] = 32'd3;

        // ------------------------------------------------------------
        // Preparar SHOTS_J2.
        // SHOTS_J2 base = RAM[256].
        // ------------------------------------------------------------

        // Barco 0 completamente impactado.
        dut.u_processor.ram.words[256] = 32'd2;
        dut.u_processor.ram.words[257] = 32'd2;
        dut.u_processor.ram.words[258] = 32'd2;
        dut.u_processor.ram.words[259] = 32'd2;

        // Barco 1 completamente impactado.
        dut.u_processor.ram.words[280] = 32'd2;
        dut.u_processor.ram.words[281] = 32'd2;
        dut.u_processor.ram.words[282] = 32'd2;

        // Primera celda del barco 2 impactada.
        dut.u_processor.ram.words[308] = 32'd2;

        // Ultima celda (7,4), indice 60, aun no disparada.
        expect_ram(316, 32'd0);

        // Marcador heredado de la partida anterior.
        expect_ram(8, 32'd1);    // WINS_J1
        expect_ram(9, 32'd0);    // WINS_J2

        // Enviar S,7,4\n.
        //
        // Debemos recibir:
        //
        //   SR,7,4,H\n
        //   FIN,2\n
        fork
            begin
                uart_send_byte(8'h53); // S
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h37); // 7
                uart_send_byte(8'h2C); // ,
                uart_send_byte(8'h34); // 4
                uart_send_byte(8'h0A); // LF
            end

            begin
                // ----------------------------------------------------
                // SR,7,4,H\n
                // ----------------------------------------------------
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);

                if (uart_tx_byte0 !== 8'h53 ||  // S
                    uart_tx_byte1 !== 8'h52 ||  // R
                    uart_tx_byte2 !== 8'h2C ||  // ,
                    uart_tx_byte3 !== 8'h37 ||  // 7
                    uart_tx_byte4 !== 8'h2C ||  // ,
                    uart_tx_byte5 !== 8'h34 ||  // 4
                    uart_tx_byte6 !== 8'h2C ||  // ,
                    uart_tx_byte7 !== 8'h48 ||  // H
                    uart_tx_byte8 !== 8'h0A) begin

                    $display(
                        "ERROR UART SR VICTORIA J2: recibido=%h %h %h %h %h %h %h %h %h",
                        uart_tx_byte0, uart_tx_byte1, uart_tx_byte2,
                        uart_tx_byte3, uart_tx_byte4, uart_tx_byte5,
                        uart_tx_byte6, uart_tx_byte7, uart_tx_byte8
                    );
                    errors = errors + 1;
                end

                // ----------------------------------------------------
                // FIN,2\n
                // ----------------------------------------------------
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);

                if (uart_tx_byte0 !== 8'h46 ||  // F
                    uart_tx_byte1 !== 8'h49 ||  // I
                    uart_tx_byte2 !== 8'h4E ||  // N
                    uart_tx_byte3 !== 8'h2C ||  // ,
                    uart_tx_byte4 !== 8'h32 ||  // 2
                    uart_tx_byte5 !== 8'h0A) begin

                    $display(
                        "ERROR UART FIN J2: recibido=%h %h %h %h %h %h",
                        uart_tx_byte0, uart_tx_byte1, uart_tx_byte2,
                        uart_tx_byte3, uart_tx_byte4, uart_tx_byte5
                    );
                    errors = errors + 1;
                end
            end
        join

        repeat (300) @(negedge clk_i);

        // Ultimo impacto registrado.
        expect_ram(316, 32'd2);

        // BOARD_J1 conserva la identidad del barco.
        expect_ram(124, 32'd3);

        // Juego terminado.
        expect_ram(0, 32'd2);    // STATE_FINISHED

        // Marcador acumulado.
        expect_ram(8, 32'd1);    // WINS_J1 sigue en 1
        expect_ram(9, 32'd1);    // WINS_J2 ahora es 1

        // LED_FINISHED = 4.
        if (led_o !== 3'b100) begin
            $display(
                "ERROR LED victoria J2: esperado=100 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        // VGA de J1:
        // fila 7, columna 4 -> tile = 7*20 + 4 = 144.
        expect_vga(144, 32'd2);

        $display("PASS 25: victoria J2 -> SR,7,4,H + FIN,2 + STATE_FINISHED + WINS_J2");


        // ============================================================
        // 26. Orden inverso de colocacion: J2 termina antes que J1
        //
        // Debe cumplirse:
        //   1. J2 puede completar sus tres barcos primero.
        //   2. El juego permanece en STATE_PLACEMENT mientras J1
        //      no haya terminado.
        //   3. Al colocar J1 su tercer barco:
        //          GAME_STATE = STATE_BATTLE
        //          TURN       = J1
        //          LED        = LED_BATTLE
        //      y se transmite:
        //          B\n
        //          T,1\n
        // ============================================================

        // Reiniciar la partida terminada en PASS 25.
        press_button(7'b1000000); // BTN_RST

        repeat (300) @(negedge clk_i);

        expect_ram(0, 32'd0);     // STATE_PLACEMENT
        expect_ram(1, 32'd1);     // TURN = J1
        expect_ram(5, 32'd0);     // CURRENT_SHIP
        expect_ram(6, 32'd0);     // PLACED_J1
        expect_ram(7, 32'd0);     // PLACED_J2
        expect_ram(327, 32'd0);   // J2_SHIP_MASK

        // Los marcadores deben sobrevivir al nuevo reset.
        expect_ram(8, 32'd1);     // WINS_J1
        expect_ram(9, 32'd1);     // WINS_J2

        // ------------------------------------------------------------
        // J2 coloca primero toda su flota.
        //
        // Barco 0: (0,0), horizontal, longitud 4.
        // Barco 2: (6,4), vertical, longitud 2.
        // Barco 1: (3,0), horizontal, longitud 3.
        // ------------------------------------------------------------

        place_j2_expect_pa(8'd0, 8'd0, 8'd0, 8'h48); // H
        expect_ram(7, 32'd1);
        expect_ram(327, 32'd1);

        place_j2_expect_pa(8'd2, 8'd6, 8'd4, 8'h56); // V
        expect_ram(7, 32'd2);
        expect_ram(327, 32'd5);

        place_j2_expect_pa(8'd1, 8'd3, 8'd0, 8'h48); // H
        expect_ram(7, 32'd3);
        expect_ram(327, 32'd7);

        // J2 ya termino, pero J1 todavia no.
        // La batalla NO debe iniciar prematuramente.
        expect_ram(0, 32'd0);     // STATE_PLACEMENT
        expect_ram(6, 32'd0);     // PLACED_J1
        expect_ram(7, 32'd3);     // PLACED_J2

        if (led_o !== 3'b001) begin
            $display(
                "ERROR PASS26: LED antes de terminar J1 esperado=001 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        // ------------------------------------------------------------
        // Ahora J1 coloca su flota.
        // Se reutiliza la misma geometria validada en PASS 2--6.
        // ------------------------------------------------------------

        // Barco 0: horizontal (0,0), longitud 4.
        press_button(BTN_OK);

        expect_ram(5, 32'd1);
        expect_ram(6, 32'd1);

        // Barco 1: vertical (0,6), longitud 3.
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);
        press_button(BTN_RIGHT);

        expect_ram(3, 32'd6);

        press_button(BTN_SEL);
        expect_ram(4, 32'd1);

        press_button(BTN_OK);

        expect_ram(5, 32'd2);
        expect_ram(6, 32'd2);

        // El cursor/orientacion vuelve al origen.
        expect_ram(2, 32'd0);
        expect_ram(3, 32'd0);
        expect_ram(4, 32'd0);

        // Barco 2: horizontal (1,0), longitud 2.
        press_button(BTN_DOWN);

        expect_ram(2, 32'd1);
        expect_ram(3, 32'd0);

        // Este es el ultimo barco pendiente de ambas flotas.
        // Debemos escuchar B\n + T,1\n mientras se procesa BTN_OK.
        fork
            begin
                press_button(BTN_OK);
            end

            begin
                // B\n
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);

                // T,1\n
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
            end
        join

        // Comprobar B\n + T,1\n.
        if (uart_tx_byte0 !== 8'h42 ||  // B
            uart_tx_byte1 !== 8'h0A ||
            uart_tx_byte2 !== 8'h54 ||  // T
            uart_tx_byte3 !== 8'h2C ||  // ,
            uart_tx_byte4 !== 8'h31 ||  // 1
            uart_tx_byte5 !== 8'h0A) begin

            $display(
                "ERROR UART PASS26 inicio batalla: recibido=%h %h %h %h %h %h",
                uart_tx_byte0,
                uart_tx_byte1,
                uart_tx_byte2,
                uart_tx_byte3,
                uart_tx_byte4,
                uart_tx_byte5
            );
            errors = errors + 1;
        end

        repeat (300) @(negedge clk_i);

        // Ambas flotas completas.
        expect_ram(5, 32'd3);     // CURRENT_SHIP
        expect_ram(6, 32'd3);     // PLACED_J1
        expect_ram(7, 32'd3);     // PLACED_J2

        // La batalla debe haber iniciado correctamente.
        expect_ram(0, 32'd1);     // STATE_BATTLE
        expect_ram(1, 32'd1);     // TURN = J1

        if (led_o !== 3'b010) begin
            $display(
                "ERROR PASS26: LED batalla esperado=010 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        // Verificaciones representativas de ambas flotas.
        expect_ram(64,  32'd1);   // J1 barco 0
        expect_ram(70,  32'd2);   // J1 barco 1
        expect_ram(72,  32'd3);   // J1 barco 2

        expect_ram(128, 32'd1);   // J2 barco 0
        expect_ram(152, 32'd2);   // J2 barco 1
        expect_ram(180, 32'd3);   // J2 barco 2
        expect_ram(188, 32'd3);   // J2 barco 2

        // Los marcadores siguen intactos.
        expect_ram(8, 32'd1);
        expect_ram(9, 32'd1);

        $display("PASS 26: J2 termina primero -> J1 completa -> B + T,1 + BATTLE");

        // ============================================================
        // 27. STATE_FINISHED bloquea entradas excepto BTN_RST
        //
        // Primero se fuerza una situacion en la que a J1 solo le falta
        // un impacto para ganar. Se realiza el disparo final y se entra
        // en FINISHED. Luego:
        //
        //   - botones de juego no deben modificar cursor/orientacion,
        //     estado, turno ni marcador;
        //   - una trama S,row,col por UART debe ser ignorada;
        //   - no debe aparecer un nuevo impacto en SHOTS_J2.
        //
        // BTN_RST no se prueba aqui porque ya fue validado en PASS 24.
        // ============================================================

        // J1 debe tener el turno.
        dut.u_processor.ram.words[1] = 32'd1;

        // Preparar todos los barcos de J2 como alcanzados excepto
        // la ultima celda del barco 2: (7,4), indice 60.
        //
        // Barco 0: indices 0..3.
        dut.u_processor.ram.words[192] = 32'd2;
        dut.u_processor.ram.words[193] = 32'd2;
        dut.u_processor.ram.words[194] = 32'd2;
        dut.u_processor.ram.words[195] = 32'd2;

        // Barco 1: indices 24..26.
        dut.u_processor.ram.words[216] = 32'd2;
        dut.u_processor.ram.words[217] = 32'd2;
        dut.u_processor.ram.words[218] = 32'd2;

        // Barco 2: indice 52 alcanzado; indice 60 pendiente.
        dut.u_processor.ram.words[244] = 32'd2;
        dut.u_processor.ram.words[252] = 32'd0;

        // Cursor J1 -> (7,4).
        dut.u_processor.ram.words[2] = 32'd7;
        dut.u_processor.ram.words[3] = 32'd4;

        // Disparo ganador:
        //     DR,7,4,H\n
        //     FIN,1\n
        fork
            begin
                press_button(BTN_OK);
            end

            begin
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);
                uart_receive_byte(uart_tx_byte6);
                uart_receive_byte(uart_tx_byte7);
                uart_receive_byte(uart_tx_byte8);

                if (uart_tx_byte0 !== 8'h44 || // D
                    uart_tx_byte1 !== 8'h52 || // R
                    uart_tx_byte2 !== 8'h2C ||
                    uart_tx_byte3 !== 8'h37 || // 7
                    uart_tx_byte4 !== 8'h2C ||
                    uart_tx_byte5 !== 8'h34 || // 4
                    uart_tx_byte6 !== 8'h2C ||
                    uart_tx_byte7 !== 8'h48 || // H
                    uart_tx_byte8 !== 8'h0A) begin

                    $display("ERROR PASS27: DR,7,4,H incorrecto");
                    errors = errors + 1;
                end

                // FIN,1\n
                uart_receive_byte(uart_tx_byte0);
                uart_receive_byte(uart_tx_byte1);
                uart_receive_byte(uart_tx_byte2);
                uart_receive_byte(uart_tx_byte3);
                uart_receive_byte(uart_tx_byte4);
                uart_receive_byte(uart_tx_byte5);

                if (uart_tx_byte0 !== 8'h46 || // F
                    uart_tx_byte1 !== 8'h49 || // I
                    uart_tx_byte2 !== 8'h4E || // N
                    uart_tx_byte3 !== 8'h2C ||
                    uart_tx_byte4 !== 8'h31 || // 1
                    uart_tx_byte5 !== 8'h0A) begin

                    $display("ERROR PASS27: FIN,1 incorrecto");
                    errors = errors + 1;
                end
            end
        join

        repeat (300) @(negedge clk_i);

        // Debemos estar completamente terminados.
        expect_ram(0,   32'd2);   // STATE_FINISHED
        expect_ram(252, 32'd2);   // ultimo impacto J1

        // Marcador anterior era 1-1; gana nuevamente J1.
        expect_ram(8, 32'd2);     // WINS_J1
        expect_ram(9, 32'd1);     // WINS_J2

        if (led_o !== 3'b100) begin
            $display(
                "ERROR PASS27: LED FINISHED esperado=100 obtenido=%b",
                led_o
            );
            errors = errors + 1;
        end

        // Guardar valores que deben permanecer inmutables.
        // Cursor actual = (7,4), orientacion = 0.
        expect_ram(2, 32'd7);
        expect_ram(3, 32'd4);
        expect_ram(4, 32'd0);

        // Una posicion de SHOTS_J2 que sigue vacia.
        // indice 63 -> RAM[319].
        dut.u_processor.ram.words[319] = 32'd0;

        // ------------------------------------------------------------
        // Intentar controles locales durante FINISHED.
        // Ninguno debe modificar el estado del juego.
        // ------------------------------------------------------------
        press_button(BTN_UP);
        press_button(BTN_DOWN);
        press_button(BTN_LEFT);
        press_button(BTN_RIGHT);
        press_button(BTN_SEL);
        press_button(BTN_OK);

        repeat (300) @(negedge clk_i);

        expect_ram(0, 32'd2);     // sigue FINISHED
        expect_ram(2, 32'd7);     // cursor fila intacta
        expect_ram(3, 32'd4);     // cursor columna intacta
        expect_ram(4, 32'd0);     // orientacion intacta
        expect_ram(8, 32'd2);     // marcador intacto
        expect_ram(9, 32'd1);

        // ------------------------------------------------------------
        // Intentar disparo UART de J2 durante FINISHED.
        //
        // No abrimos un receptor UART porque la respuesta correcta
        // es no transmitir SR ni alterar el juego.
        // ------------------------------------------------------------
        uart_send_byte(8'h53); // S
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h37); // 7
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h37); // 7
        uart_send_byte(8'h0A); // LF

        repeat (2000) @(negedge clk_i);

        // Nada del estado final debe cambiar.
        expect_ram(0, 32'd2);     // STATE_FINISHED
        expect_ram(8, 32'd2);     // WINS_J1
        expect_ram(9, 32'd1);     // WINS_J2
        expect_ram(319, 32'd0);   // disparo UART ignorado

        if (led_o !== 3'b100) begin
            $display(
                "ERROR PASS27: LED cambio durante FINISHED: %b",
                led_o
            );
            errors = errors + 1;
        end

        $display("PASS 27: FINISHED ignora botones y disparos UART excepto reset");

        // ============================================================
        // 28. Disparo UART fuera de turno
        //
        // Durante STATE_BATTLE, si TURN=1, una trama de disparo de J2:
        //
        //     S,0,0\n
        //
        // debe ser consumida pero ignorada:
        //   - TURN permanece en 1
        //   - SHOTS_J2 no cambia
        //   - BOARD_J1 no cambia
        //   - VGA no cambia
        //   - marcador no cambia
        // ============================================================

        // Reiniciar la partida terminada en PASS 27.
        press_button(7'b1000000); // BTN_RST
        repeat (300) @(negedge clk_i);

        expect_ram(0, 32'd0);     // STATE_PLACEMENT
        expect_ram(1, 32'd1);     // TURN = J1
        expect_ram(8, 32'd2);     // WINS_J1 preservado
        expect_ram(9, 32'd1);     // WINS_J2 preservado

        // Preparar una batalla controlada.
        dut.u_processor.ram.words[0] = 32'd1; // STATE_BATTLE
        dut.u_processor.ram.words[1] = 32'd1; // TURN = J1

        // Casilla representativa del tablero J1.
        // BOARD_J1[0] = barco.
        dut.u_processor.ram.words[64] = 32'd1;

        // J2 aun no ha disparado a (0,0).
        dut.u_processor.ram.words[256] = 32'd0;

        // VGA propio (0,0): barco.
        dut.u_vga.u_memory.mem[0] = 32'd1;

        repeat (50) @(negedge clk_i);

        // Enviar disparo de J2 cuando corresponde jugar a J1.
        uart_send_byte(8'h53); // S
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h30); // 0
        uart_send_byte(8'h2C); // ,
        uart_send_byte(8'h30); // 0
        uart_send_byte(8'h0A); // LF

        // Dar tiempo suficiente para parsear y descartar la trama.
        repeat (2000) @(negedge clk_i);

        // Debe continuar siendo batalla y turno de J1.
        expect_ram(0, 32'd1);
        expect_ram(1, 32'd1);

        // El disparo fuera de turno no debe registrarse.
        expect_ram(256, 32'd0);

        // El barco de J1 no debe modificarse.
        expect_ram(64, 32'd1);

        // VGA tampoco debe mostrar impacto.
        expect_vga(0, 32'd1);

        // Marcadores intactos.
        expect_ram(8, 32'd2);
        expect_ram(9, 32'd1);

        // Parser debe haber consumido completamente la trama.
        expect_ram(321, 32'd0);   // UART_PARSE_STATE
        expect_ram(326, 32'd0);   // UART_FRAME_READY

        if (dut.u_uart.rx_pending_r !== 1'b0) begin
            $display(
                "ERROR PASS28: RX_VALID no fue limpiado: %b",
                dut.u_uart.rx_pending_r
            );
            errors = errors + 1;
        end

        $display("PASS 28: disparo UART fuera de turno ignorado sin cambiar estado");

        if (errors != 0)
            $fatal(1,
                "FAIL: game firmware con %0d errores",
                errors);

        $display("----------------------------------------");
        $display("TODAS LAS PRUEBAS PASARON");
        $display("Barco 0: longitud 4 OK");
        $display("Limites: OK");
        $display("Barco 1: longitud 3 OK");
        $display("Traslape: OK");
        $display("Barco 2: longitud 2 OK");
        $display("BOARD_J1 + VGA: OK");
        $display("----------------------------------------");

        $finish;
    end

endmodule
