"""Interfaz gráfica del Jugador 2 para Batalla Naval."""

import argparse
import tkinter as tk
from tkinter import messagebox, ttk

from player2_state import Player2State
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
        self._refresh()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

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

        self._create_board(own_frame, self.own_cells)
        self._create_board(enemy_frame, self.enemy_cells)

    def _create_board(self, parent, storage) -> None:
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

    def _build_controls(self, parent) -> None:
        placement = ttk.LabelFrame(
            parent,
            text="Colocación de barcos",
            padding=8,
        )
        placement.grid(
            row=2,
            column=0,
            sticky="ew",
            pady=10,
            padx=(0, 8),
        )

        ttk.Label(placement, text="Barco:").grid(row=0, column=0)
        ttk.Spinbox(
            placement,
            from_=0,
            to=2,
            width=4,
            textvariable=self.ship_var,
        ).grid(row=0, column=1)

        ttk.Label(placement, text="Fila:").grid(row=1, column=0)
        ttk.Spinbox(
            placement,
            from_=0,
            to=7,
            width=4,
            textvariable=self.place_row_var,
        ).grid(row=1, column=1)

        ttk.Label(placement, text="Columna:").grid(row=2, column=0)
        ttk.Spinbox(
            placement,
            from_=0,
            to=7,
            width=4,
            textvariable=self.place_col_var,
        ).grid(row=2, column=1)

        ttk.Label(
            placement,
            text="Orientación:",
        ).grid(row=3, column=0)

        ttk.Combobox(
            placement,
            values=("H", "V"),
            width=3,
            state="readonly",
            textvariable=self.orientation_var,
        ).grid(row=3, column=1)

        self.place_button = ttk.Button(
            placement,
            text="Enviar colocación",
            command=self._send_placement,
        )
        self.place_button.grid(
            row=4,
            column=0,
            columnspan=2,
            pady=(8, 0),
        )

        shot = ttk.LabelFrame(
            parent,
            text="Disparo",
            padding=8,
        )
        shot.grid(
            row=2,
            column=1,
            sticky="ew",
            pady=10,
            padx=(8, 0),
        )

        ttk.Label(shot, text="Fila:").grid(row=0, column=0)
        ttk.Spinbox(
            shot,
            from_=0,
            to=7,
            width=4,
            textvariable=self.shot_row_var,
        ).grid(row=0, column=1)

        ttk.Label(shot, text="Columna:").grid(row=1, column=0)
        ttk.Spinbox(
            shot,
            from_=0,
            to=7,
            width=4,
            textvariable=self.shot_col_var,
        ).grid(row=1, column=1)

        self.shot_button = ttk.Button(
            shot,
            text="Enviar disparo",
            command=self._send_shot,
        )
        self.shot_button.grid(
            row=2,
            column=0,
            columnspan=2,
            pady=(8, 0),
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
            return

        self.link = SerialLink(self.port_var.get())

        try:
            self.link.open()
        except SerialLinkError as exc:
            messagebox.showerror("Error de conexión", str(exc))
            return

        self.connection_var.set("Conectado")
        self.connect_button.configure(text="Desconectar")
        self._poll_serial()

    def _send_placement(self) -> None:
        try:
            frame = self.state.request_placement(
                self.ship_var.get(),
                self.place_row_var.get(),
                self.place_col_var.get(),
                self.orientation_var.get(),
            )
            self.link.send(frame)

        except (ProtocolError, SerialLinkError, tk.TclError) as exc:
            messagebox.showerror("Colocación", str(exc))
            return

        self._refresh()

    def _send_shot(self) -> None:
        try:
            frame = self.state.request_shot(
                self.shot_row_var.get(),
                self.shot_col_var.get(),
            )
            self.link.send(frame)

        except (ProtocolError, SerialLinkError, tk.TclError) as exc:
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

    def _refresh(self) -> None:
        self.status_var.set(self.state.status)

        for coord, label in self.own_cells.items():
            value = self.state.own_board.get(coord)
            label.configure(text=CELL_SYMBOL.get(value, "·"))

        for coord, label in self.enemy_cells.items():
            value = self.state.enemy_board.get(coord)
            label.configure(text=CELL_SYMBOL.get(value, "·"))

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
