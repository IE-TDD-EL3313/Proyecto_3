"""Estado local de presentación para la aplicación del Jugador 2.

Este módulo no implementa las reglas de Batalla Naval. Únicamente
mantiene la información que la FPGA ha confirmado mediante el
protocolo UART.
"""

from dataclasses import dataclass, field
from typing import Dict, Optional, Tuple

from protocol import Message, ProtocolError, build_placement, build_shot


Coord = Tuple[int, int]

SHIP_LENGTHS = {
    0: 4,
    1: 3,
    2: 2,
}

RESULT_TEXT = {
    "F": "Fallo",
    "I": "Impacto",
    "H": "Barco hundido",
}

REJECTION_TEXT = {
    "O": "La colocación se traslapa con otro barco.",
    "F": "El barco queda fuera del tablero.",
}


@dataclass
class Player2State:
    """Estado mostrado por la terminal remota del Jugador 2."""

    turn: Optional[int] = None
    battle_started: bool = False
    game_finished: bool = False
    winner: Optional[int] = None

    # Victorias acumuladas entre partidas.
    wins_j1: int = 0
    wins_j2: int = 0

    # Estadisticas de la partida actual.
    hits_j1: int = 0
    hits_j2: int = 0
    misses_j1: int = 0
    misses_j2: int = 0

    own_board: Dict[Coord, str] = field(default_factory=dict)
    enemy_board: Dict[Coord, str] = field(default_factory=dict)

    accepted_ships: Dict[int, Tuple[int, int, str]] = field(
        default_factory=dict
    )

    pending_placements: Dict[int, Tuple[int, int, str]] = field(
        default_factory=dict
    )

    pending_shot: Optional[Coord] = None

    status: str = "Esperando colocación de barcos."

    def reset_all(self) -> None:
        """Reinicia completamente el juego y el marcador."""
        self.reset()
        self.wins_j1 = 0
        self.wins_j2 = 0

    def reset(self) -> None:
        """Restablece el estado local para una nueva partida."""
        self.turn = None
        self.battle_started = False
        self.game_finished = False
        self.winner = None

        # Reiniciar estadisticas de la partida, conservar victorias.
        self.hits_j1 = 0
        self.hits_j2 = 0
        self.misses_j1 = 0
        self.misses_j2 = 0

        self.own_board.clear()
        self.enemy_board.clear()
        self.accepted_ships.clear()
        self.pending_placements.clear()
        self.pending_shot = None

        self.status = "Nueva partida: esperando colocación de barcos."

    def request_placement(
        self,
        ship: int,
        row: int,
        column: int,
        orientation: str,
    ) -> str:
        """Genera una solicitud de colocación válida."""

        frame = build_placement(ship, row, column, orientation)

        self.pending_placements[ship] = (
            row,
            column,
            orientation.upper(),
        )

        self.status = f"Esperando respuesta para barco {ship}."
        return frame

    def request_shot(self, row: int, column: int) -> str:
        """Genera una solicitud de disparo válida."""

        frame = build_shot(row, column)
        self.pending_shot = (row, column)
        self.status = f"Esperando resultado del disparo ({row}, {column})."

        return frame

    def handle_message(self, msg: Message) -> None:
        """Actualiza la presentación según un mensaje confirmado por FPGA."""

        if msg.type == "ST":
            self.wins_j1 = msg.wins_j1
            self.wins_j2 = msg.wins_j2

            self.hits_j1 = msg.hits_j1
            self.misses_j1 = msg.misses_j1

            self.hits_j2 = msg.hits_j2
            self.misses_j2 = msg.misses_j2
            return

        if msg.type == "PA":
            self._handle_placement_accepted(msg)
            return

        if msg.type == "PR":
            self._handle_placement_rejected(msg)
            return

        if msg.type == "B":
            self.battle_started = True
            self.status = "Fase de batalla iniciada."
            return

        if msg.type == "T":
            self.turn = msg.player

            if msg.player == 2:
                self.status = "Turno del Jugador 2."
            else:
                self.status = "Turno del Jugador 1."

            return

        if msg.type == "SR":
            coord = (msg.row, msg.column)

            # Evitar contabilizar dos veces la misma casilla.
            if coord not in self.enemy_board:
                if msg.result in {"I", "H"}:
                    self.hits_j2 += 1
                elif msg.result == "F":
                    self.misses_j2 += 1

            self.enemy_board[coord] = msg.result
            self.pending_shot = None
            self.status = (
                f"Disparo ({msg.row}, {msg.column}): "
                f"{RESULT_TEXT[msg.result]}."
            )
            return

        if msg.type == "DR":
            coord = (msg.row, msg.column)

            # Evitar contabilizar dos veces la misma casilla.
            if coord not in self.own_board or (
                self.own_board[coord] == "B"
            ):
                if msg.result in {"I", "H"}:
                    self.hits_j1 += 1
                elif msg.result == "F":
                    self.misses_j1 += 1

            self.own_board[coord] = msg.result
            self.status = (
                f"Disparo recibido ({msg.row}, {msg.column}): "
                f"{RESULT_TEXT[msg.result]}."
            )
            return

        if msg.type == "FIN":
            # Contabilizar una victoria una sola vez.
            if not self.game_finished:
                if msg.winner == 1:
                    self.wins_j1 += 1
                elif msg.winner == 2:
                    self.wins_j2 += 1

            self.game_finished = True
            self.winner = msg.winner

            if msg.winner == 2:
                self.status = "Fin de la partida: ganó el Jugador 2."
            else:
                self.status = "Fin de la partida: ganó el Jugador 1."

            return

        raise ProtocolError(f"Mensaje no soportado: {msg.type}")

    def _handle_placement_accepted(self, msg: Message) -> None:
        placement = self.pending_placements.pop(msg.ship, None)

        if placement is None:
            self.status = (
                f"FPGA aceptó el barco {msg.ship}, "
                "pero no existe una solicitud local pendiente."
            )
            return

        row, column, orientation = placement
        self.accepted_ships[msg.ship] = placement

        length = SHIP_LENGTHS[msg.ship]

        for offset in range(length):
            r = row + (offset if orientation == "V" else 0)
            c = column + (offset if orientation == "H" else 0)
            self.own_board[(r, c)] = "B"

        self.status = f"Barco {msg.ship} colocado correctamente."

    def _handle_placement_rejected(self, msg: Message) -> None:
        self.pending_placements.pop(msg.ship, None)

        self.status = (
            f"Barco {msg.ship} rechazado: "
            f"{REJECTION_TEXT[msg.reason]}"
        )

    def summary(self) -> str:
        """Devuelve un resumen básico de la partida."""

        own_hits = sum(
            value in {"I", "H"}
            for value in self.own_board.values()
        )

        enemy_hits = sum(
            value in {"I", "H"}
            for value in self.enemy_board.values()
        )

        enemy_misses = sum(
            value == "F"
            for value in self.enemy_board.values()
        )

        if self.winner is None:
            result = "Partida en curso"
        elif self.winner == 2:
            result = "Victoria del Jugador 2"
        else:
            result = "Victoria del Jugador 1"

        return (
            f"{result} | "
            f"Impactos realizados: {enemy_hits} | "
            f"Fallos realizados: {enemy_misses} | "
            f"Impactos recibidos: {own_hits}"
        )
