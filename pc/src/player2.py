"""Interfaz gráfica del Jugador 2 para Batalla Naval."""

import argparse
import tkinter as tk
from tkinter import messagebox, ttk

from player2_state import Player2State, SHIP_LENGTHS
from protocol import ProtocolError
from serial_link import SerialLink, SerialLinkError


CELL_SYMBOL = {
    "B": "B",
    "F": "○",
    "I": "X",
    "H": "X",
}


class Player2App:
    """Interfaz remota del Jugador 2."""

    def __init__(self, root: tk.Tk, port: str) -> None:
        self.root = root
        self.root.title("Batalla Naval - Jugador 2")
        self.root.resizable(False, False)

        self.state = Player2State()
        self.link = SerialLink(port)

        self.own_cells = {}
        self.enemy_cells = {}

        self.own_cell_selected = False
        self.enemy_cell_selected = False

        self.port_var = tk.StringVar(value=port)
        self.connection_var = tk.StringVar(value="Desconectado")
        self.status_var = tk.StringVar(value=self.state.status)

        self.ship_var = tk.IntVar(value=0)
        self.place_row_var = tk.IntVar(value=0)
        self.place_col_var = tk.IntVar(value=0)
        self.orientation_var = tk.StringVar(value="H")

        self.shot_row_var = tk.IntVar(value=0)
        self.shot_col_var = tk.IntVar(value=0)

        self._build_gui()

        self.ship_var.trace_add("write", lambda *_: self._refresh())
        self.orientation_var.trace_add("write", lambda *_: self._refresh())
        self.place_row_var.trace_add("write", lambda *_: self._refresh())
        self.place_col_var.trace_add("write", lambda *_: self._refresh())

        self._refresh()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)
        self.root.bind(
            "<KeyPress-r>",
            lambda event: self._rotate_ship()
            if not isinstance(event.widget, (tk.Entry, ttk.Entry))
            else None,
        )
        self.root.bind(
            "<KeyPress-R>",
            lambda event: self._rotate_ship()
            if not isinstance(event.widget, (tk.Entry, ttk.Entry))
            else None,
        )

    def _build_gui(self) -> None:
        main = ttk.Frame(self.root, padding=12)
        main.grid(row=0, column=0)

        self._build_connection(main)
        self._build_boards(main)
        self._build_controls(main)
        self._build_status(main)

    def _build_connection(self, parent) -> None:
        frame = ttk.LabelFrame(parent, text="Conexión UART", padding=8)
        frame.grid(
            row=0,
            column=0,
            columnspan=2,
            sticky="ew",
            pady=(0, 10),
        )

        ttk.Label(frame, text="Puerto:").grid(row=0, column=0)

        ttk.Entry(
            frame,
            textvariable=self.port_var,
            width=20,
        ).grid(row=0, column=1, padx=5)

        self.connect_button = ttk.Button(
            frame,
            text="Conectar",
            command=self._toggle_connection,
        )
        self.connect_button.grid(row=0, column=2, padx=5)

        ttk.Label(
            frame,
            textvariable=self.connection_var,
        ).grid(row=0, column=3, padx=10)

        ttk.Label(
            frame,
            text="115200 8N1",
        ).grid(row=0, column=4, padx=10)

    def _build_boards(self, parent) -> None:
        own_frame = ttk.LabelFrame(
            parent,
            text="Mi tablero",
            padding=8,
        )
        own_frame.grid(row=1, column=0, padx=(0, 8))

        enemy_frame = ttk.LabelFrame(
            parent,
            text="Tablero rival",
            padding=8,
        )
        enemy_frame.grid(row=1, column=1, padx=(8, 0))

        self._create_board(own_frame, self.own_cells, "own")
        self._create_board(enemy_frame, self.enemy_cells, "enemy")

    def _create_board(self, parent, storage, board_type) -> None:
        ttk.Label(parent, text="").grid(row=0, column=0)

        for column in range(8):
            ttk.Label(
                parent,
                text=str(column),
                width=3,
                anchor="center",
            ).grid(row=0, column=column + 1)

        for row in range(8):
            ttk.Label(
                parent,
                text=str(row),
                width=3,
                anchor="center",
            ).grid(row=row + 1, column=0)

            for column in range(8):
                label = tk.Label(
                    parent,
                    text="·",
                    width=3,
                    height=1,
                    relief="solid",
                    borderwidth=1,
                    font=("TkFixedFont", 12),
                )
                label.grid(row=row + 1, column=column + 1)
                storage[(row, column)] = label
                label.bind(
                    "<Button-1>",
                    lambda event, r=row, c=column, b=board_type:
                        self._select_cell(b, r, c),
                )

    def _select_cell(self, board_type, row, column) -> None:
        if board_type == "own":
            self.own_cell_selected = True
            self.place_row_var.set(row)
            self.place_col_var.set(column)
            self.status_var.set(
                f"Posición seleccionada para barco: ({row}, {column})."
            )
        else:
            self.enemy_cell_selected = True
            self.shot_row_var.set(row)
            self.shot_col_var.set(column)
            self.status_var.set(
                f"Objetivo seleccionado: ({row}, {column})."
            )

        self._refresh()

    def _build_controls(self, parent) -> None:
        placement = ttk.LabelFrame(
            parent,
            text="Colocación de barcos",
            padding=10,
        )
        placement.grid(
            row=2,
            column=0,
            sticky="ew",
            pady=10,
            padx=(0, 8),
        )

        self.ship_info_var = tk.StringVar()
        self.place_info_var = tk.StringVar()

        ttk.Label(
            placement,
            textvariable=self.ship_info_var,
            font=("TkDefaultFont", 10, "bold"),
        ).grid(row=0, column=0, sticky="w", pady=3)

        ttk.Label(
            placement,
            textvariable=self.place_info_var,
        ).grid(row=1, column=0, sticky="w", pady=3)

        self.rotate_button = ttk.Button(
            placement,
            text="Rotar barco (R)",
            command=self._rotate_ship,
        )
        self.rotate_button.grid(
            row=2,
            column=0,
            sticky="ew",
            pady=(8, 4),
        )

        self.place_button = ttk.Button(
            placement,
            text="Confirmar colocación",
            command=self._send_placement,
        )
        self.place_button.grid(
            row=3,
            column=0,
            sticky="ew",
            pady=4,
        )

        shot = ttk.LabelFrame(
            parent,
            text="Disparo",
            padding=10,
        )
        shot.grid(
            row=2,
            column=1,
            sticky="ew",
            pady=10,
            padx=(8, 0),
        )

        self.shot_info_var = tk.StringVar()

        ttk.Label(
            shot,
            text="Selecciona una casilla del tablero rival.",
            wraplength=240,
        ).grid(row=0, column=0, sticky="w", pady=3)

        ttk.Label(
            shot,
            textvariable=self.shot_info_var,
            font=("TkDefaultFont", 10, "bold"),
        ).grid(row=1, column=0, sticky="w", pady=3)

        self.shot_button = ttk.Button(
            shot,
            text="Confirmar disparo",
            command=self._send_shot,
        )
        self.shot_button.grid(
            row=2,
            column=0,
            sticky="ew",
            pady=(8, 4),
        )

    def _build_status(self, parent) -> None:
        frame = ttk.LabelFrame(
            parent,
            text="Estado de la partida",
            padding=8,
        )
        frame.grid(
            row=3,
            column=0,
            columnspan=2,
            sticky="ew",
        )

        ttk.Label(
            frame,
            textvariable=self.status_var,
            wraplength=600,
        ).grid(row=0, column=0, sticky="w")

    def _toggle_connection(self) -> None:
        if self.link.is_open:
            try:
                self.link.close()
            except SerialLinkError as exc:
                messagebox.showerror("UART", str(exc))

            self.connection_var.set("Desconectado")
            self.connect_button.configure(text="Conectar")
            self._refresh()
            return

        self.link = SerialLink(self.port_var.get())

        try:
            self.link.open()
        except SerialLinkError as exc:
            messagebox.showerror("Error de conexión", str(exc))
            return

        self.connection_var.set("Conectado")
        self.connect_button.configure(text="Desconectar")
        self._refresh()
        self._poll_serial()

    def _send_placement(self) -> None:
        if self.state.battle_started or self.state.game_finished:
            messagebox.showinfo(
                "Colocación",
                "La fase de colocación ya terminó.",
            )
            return

        next_ship = self._next_ship()

        if next_ship is None:
            messagebox.showinfo(
                "Colocación",
                "Todos los barcos ya fueron colocados.",
            )
            return

        if self.state.pending_placements:
            messagebox.showinfo(
                "Colocación",
                "Esperando confirmación de la FPGA.",
            )
            return

        self.ship_var.set(next_ship)

        _, preview_valid = self._ship_preview()

        if not preview_valid:
            messagebox.showwarning(
                "Colocación inválida",
                "El barco queda fuera del tablero o se superpone "
                "con otro barco. Selecciona otra posición.",
            )
            return

        try:
            frame = self.state.request_placement(
                next_ship,
                self.place_row_var.get(),
                self.place_col_var.get(),
                self.orientation_var.get(),
            )
            self.link.send(frame)

        except (ProtocolError, SerialLinkError, tk.TclError) as exc:
            self.state.pending_placements.pop(next_ship, None)
            messagebox.showerror("Colocación", str(exc))
            self._refresh()
            return

        self._refresh()

    def _send_shot(self) -> None:
        if not self.enemy_cell_selected:
            messagebox.showinfo(
                "Disparo",
                "Selecciona primero una casilla del tablero rival.",
            )
            return

        if self.state.game_finished:
            messagebox.showinfo(
                "Disparo",
                "La partida ya terminó.",
            )
            return

        if not self.state.battle_started:
            messagebox.showinfo(
                "Disparo",
                "La batalla todavía no ha comenzado.",
            )
            return

        if self.state.turn != 2:
            messagebox.showinfo(
                "Disparo",
                "Espera tu turno para disparar.",
            )
            return

        if self.state.pending_shot is not None:
            messagebox.showinfo(
                "Disparo",
                "Esperando el resultado del disparo anterior.",
            )
            return

        try:
            row = self.shot_row_var.get()
            column = self.shot_col_var.get()
        except tk.TclError as exc:
            messagebox.showerror("Disparo", str(exc))
            return

        if (row, column) in self.state.enemy_board:
            messagebox.showinfo(
                "Disparo",
                "Ya disparaste a esa casilla. Selecciona otra.",
            )
            return

        try:
            frame = self.state.request_shot(row, column)
            self.link.send(frame)
        except (ProtocolError, SerialLinkError) as exc:
            self.state.pending_shot = None
            messagebox.showerror("Disparo", str(exc))
            return

        self._refresh()

    def _poll_serial(self) -> None:
        if not self.link.is_open:
            return

        try:
            while True:
                msg = self.link.receive()

                if msg is None:
                    break

                self.state.handle_message(msg)

                if msg.type == "PA":
                    # Limpiar la selección del barco anterior.
                    self.own_cell_selected = False

                    # Seleccionar automáticamente el siguiente barco.
                    next_ship = self._next_ship()

                    if next_ship is not None:
                        self.ship_var.set(next_ship)

                if msg.type == "FIN":
                    messagebox.showinfo(
                        "Fin de la partida",
                        self.state.summary(),
                    )

        except (SerialLinkError, ProtocolError) as exc:
            self.status_var.set(f"Error de comunicación: {exc}")

        self._refresh()

        if self.link.is_open:
            self.root.after(50, self._poll_serial)

    def _next_ship(self):
        """Devuelve el siguiente barco pendiente de colocación."""

        for ship in sorted(SHIP_LENGTHS):
            if ship not in self.state.accepted_ships:
                return ship

        return None

    def _rotate_ship(self) -> None:
        """Alterna la orientación del barco seleccionado."""

        if self.state.battle_started or self.state.game_finished:
            return

        if self.state.pending_placements:
            return

        orientation = self.orientation_var.get()

        self.orientation_var.set(
            "V" if orientation == "H" else "H"
        )

        self._refresh()

    def _ship_preview(self):
        """Calcula las casillas de la vista previa sin modificar el juego."""

        if not self.own_cell_selected:
            return set(), False

        try:
            ship = self.ship_var.get()
            row = self.place_row_var.get()
            column = self.place_col_var.get()
            orientation = self.orientation_var.get()
        except tk.TclError:
            return set(), False

        if ship not in SHIP_LENGTHS:
            return set(), False

        if ship in self.state.accepted_ships:
            return set(), False

        length = SHIP_LENGTHS[ship]
        cells = set()

        for offset in range(length):
            r = row + (offset if orientation == "V" else 0)
            c = column + (offset if orientation == "H" else 0)
            cells.add((r, c))

        valid = all(
            0 <= r < 8
            and 0 <= c < 8
            and self.state.own_board.get((r, c)) is None
            for r, c in cells
        )

        return cells, valid

    def _refresh_buttons(self) -> None:
        """Actualiza los controles según la fase y el turno."""

        connected = self.link.is_open

        placing = (
            connected
            and not self.state.battle_started
            and not self.state.game_finished
            and not self.state.pending_placements
            and self._next_ship() is not None
        )

        shooting = (
            connected
            and self.state.battle_started
            and not self.state.game_finished
            and self.state.turn == 2
            and self.state.pending_shot is None
            and self.enemy_cell_selected
            and (
                self.shot_row_var.get(),
                self.shot_col_var.get(),
            ) not in self.state.enemy_board
        )

        _, preview_valid = self._ship_preview()

        self.place_button.configure(
            state="normal" if placing and preview_valid else "disabled"
        )

        can_rotate = (
            not self.state.battle_started
            and not self.state.game_finished
            and not self.state.pending_placements
            and self._next_ship() is not None
        )

        self.rotate_button.configure(
            state="normal" if can_rotate else "disabled"
        )

        self.shot_button.configure(
            state="normal" if shooting else "disabled"
        )

    def _refresh(self) -> None:
        self.status_var.set(self.state.status)
        self._refresh_buttons()

        ship = self._next_ship()

        if ship is None:
            self.ship_info_var.set("Todos los barcos colocados")
        else:
            self.ship_info_var.set(
                f"Barco {ship}: {SHIP_LENGTHS[ship]} casillas"
            )

        orientation = self.orientation_var.get()
        self.place_info_var.set(
            f"Posición: ({self.place_row_var.get()}, "
            f"{self.place_col_var.get()}) | "
            f"Orientación: {orientation}"
        )

        self.shot_info_var.set(
            f"Objetivo: ({self.shot_row_var.get()}, "
            f"{self.shot_col_var.get()})"
        )

        colors = {
            "B": "#2563eb",
            "F": "#9ca3af",
            "I": "#ef4444",
            "H": "#b91c1c",
        }

        selected_own = (
            self.place_row_var.get(),
            self.place_col_var.get(),
        )

        selected_enemy = (
            self.shot_row_var.get(),
            self.shot_col_var.get(),
        )

        preview_cells, preview_valid = self._ship_preview()

        for coord, label in self.own_cells.items():
            value = self.state.own_board.get(coord)
            background = colors.get(value, "#dbeafe")

            if (
                not self.state.battle_started
                and not self.state.game_finished
                and coord in preview_cells
            ):
                background = (
                    "#86efac" if preview_valid else "#fca5a5"
                )

            elif (
                self.own_cell_selected
                and coord == selected_own
                and not self.state.battle_started
            ):
                background = "#facc15"

            label.configure(
                text=CELL_SYMBOL.get(value, "·"),
                bg=background,
                fg="#111827",
            )

        for coord, label in self.enemy_cells.items():
            value = self.state.enemy_board.get(coord)
            background = colors.get(value, "#dbeafe")

            if self.enemy_cell_selected and coord == selected_enemy:
                background = "#facc15"

            label.configure(
                text=CELL_SYMBOL.get(value, "·"),
                bg=background,
                fg="#111827",
            )

    def _on_close(self) -> None:
        try:
            self.link.close()
        except SerialLinkError:
            pass

        self.root.destroy()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Interfaz UART del Jugador 2"
    )

    parser.add_argument(
        "--port",
        default="/dev/ttyUSB0",
        help="Puerto serial conectado a la FPGA",
    )

    args = parser.parse_args()

    root = tk.Tk()
    Player2App(root, args.port)
    root.mainloop()


if __name__ == "__main__":
    main()
