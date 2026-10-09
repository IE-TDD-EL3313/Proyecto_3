"""Protocolo de aplicación UART para el Jugador 2.

La aplicación de PC actúa únicamente como interfaz remota.
La lógica y validación definitiva del juego corresponden a la FPGA.
"""

from dataclasses import dataclass
from typing import Optional


BOARD_MIN = 0
BOARD_MAX = 7
SHIP_MIN = 0
SHIP_MAX = 2

VALID_ORIENTATIONS = {"H", "V"}
VALID_RESULTS = {"F", "I", "H"}
VALID_REJECTION_REASONS = {"O", "F"}
VALID_PLAYERS = {1, 2}


class ProtocolError(ValueError):
    """Indica que una trama no cumple el protocolo definido."""


@dataclass(frozen=True)
class Message:
    """Mensaje recibido desde la FPGA."""

    type: str
    ship: Optional[int] = None
    row: Optional[int] = None
    column: Optional[int] = None
    orientation: Optional[str] = None
    result: Optional[str] = None
    reason: Optional[str] = None
    player: Optional[int] = None
    winner: Optional[int] = None
    wins_j1: Optional[int] = None
    wins_j2: Optional[int] = None
    hits_j1: Optional[int] = None
    misses_j1: Optional[int] = None
    hits_j2: Optional[int] = None
    misses_j2: Optional[int] = None


def _parse_int(value: str, field: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ProtocolError(
            f"Campo {field} debe ser un entero: {value!r}"
        ) from exc


def _validate_ship(ship: int) -> None:
    if not SHIP_MIN <= ship <= SHIP_MAX:
        raise ProtocolError("El identificador de barco debe estar entre 0 y 2")


def _validate_coordinate(value: int, name: str) -> None:
    if not BOARD_MIN <= value <= BOARD_MAX:
        raise ProtocolError(f"{name} debe estar entre 0 y 7")


def build_placement(
    ship: int,
    row: int,
    column: int,
    orientation: str,
) -> str:
    """Construye una solicitud de colocación P."""

    _validate_ship(ship)
    _validate_coordinate(row, "fila")
    _validate_coordinate(column, "columna")

    orientation = orientation.upper()

    if orientation not in VALID_ORIENTATIONS:
        raise ProtocolError("La orientación debe ser H o V")

    return f"P,{ship},{row},{column},{orientation}\n"


def build_shot(row: int, column: int) -> str:
    """Construye una solicitud de disparo S."""

    _validate_coordinate(row, "fila")
    _validate_coordinate(column, "columna")

    return f"S,{row},{column}\n"


def parse_message(raw: str) -> Message:
    """Valida e interpreta una trama enviada por la FPGA."""

    if not isinstance(raw, str):
        raise ProtocolError("La trama debe ser texto")

    if not raw.endswith("\n"):
        raise ProtocolError("La trama debe terminar con salto de línea")

    line = raw[:-1]

    if line.endswith("\r"):
        line = line[:-1]

    if not line:
        raise ProtocolError("Trama vacía")

    fields = line.split(",")
    msg_type = fields[0]

    if msg_type in {"RST", "RST_ALL"}:
        if len(fields) != 1:
            raise ProtocolError(f"Formato esperado: {msg_type}")

        return Message(type=msg_type)

    if msg_type == "ST":
        if len(fields) != 7:
            raise ProtocolError(
                "Formato esperado: ST,V1,V2,A1,F1,A2,F2"
            )

        values = []

        for value in fields[1:]:
            if len(value) != 2 or not value.isascii() or not value.isdigit():
                raise ProtocolError(
                    "Cada estadística ST debe tener dos dígitos ASCII"
                )

            number = int(value)

            if not 0 <= number <= 99:
                raise ProtocolError("Estadística ST fuera de rango")

            values.append(number)

        return Message(
            type="ST",
            wins_j1=values[0],
            wins_j2=values[1],
            hits_j1=values[2],
            misses_j1=values[3],
            hits_j2=values[4],
            misses_j2=values[5],
        )

    if msg_type == "PA":
        if len(fields) != 2:
            raise ProtocolError("Formato esperado: PA,barco")

        ship = _parse_int(fields[1], "barco")
        _validate_ship(ship)

        return Message(type="PA", ship=ship)

    if msg_type == "PR":
        if len(fields) != 3:
            raise ProtocolError("Formato esperado: PR,barco,motivo")

        ship = _parse_int(fields[1], "barco")
        reason = fields[2]

        _validate_ship(ship)

        if reason not in VALID_REJECTION_REASONS:
            raise ProtocolError("Motivo de rechazo inválido")

        return Message(type="PR", ship=ship, reason=reason)

    if msg_type == "B":
        if len(fields) != 1:
            raise ProtocolError("Formato esperado: B")

        return Message(type="B")

    if msg_type == "T":
        if len(fields) != 2:
            raise ProtocolError("Formato esperado: T,jugador")

        player = _parse_int(fields[1], "jugador")

        if player not in VALID_PLAYERS:
            raise ProtocolError("Jugador inválido")

        return Message(type="T", player=player)

    if msg_type in {"SR", "DR"}:
        if len(fields) != 4:
            raise ProtocolError(
                f"Formato esperado: {msg_type},fila,columna,resultado"
            )

        row = _parse_int(fields[1], "fila")
        column = _parse_int(fields[2], "columna")
        result = fields[3]

        _validate_coordinate(row, "fila")
        _validate_coordinate(column, "columna")

        if result not in VALID_RESULTS:
            raise ProtocolError("Resultado de disparo inválido")

        return Message(
            type=msg_type,
            row=row,
            column=column,
            result=result,
        )

    if msg_type == "FIN":
        if len(fields) != 2:
            raise ProtocolError("Formato esperado: FIN,ganador")

        winner = _parse_int(fields[1], "ganador")

        if winner not in VALID_PLAYERS:
            raise ProtocolError("Ganador inválido")

        return Message(type="FIN", winner=winner)

    raise ProtocolError(f"Tipo de mensaje desconocido: {msg_type!r}")
