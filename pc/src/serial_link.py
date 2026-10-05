"""Enlace UART entre la aplicación del Jugador 2 y la FPGA."""

from typing import Optional

import serial

from protocol import Message, ProtocolError, parse_message


DEFAULT_BAUDRATE = 115200
DEFAULT_TIMEOUT = 0.1


class SerialLinkError(Exception):
    """Error relacionado con la comunicación serial."""


class SerialLink:
    """Gestiona la comunicación UART con la FPGA."""

    def __init__(
        self,
        port: str,
        baudrate: int = DEFAULT_BAUDRATE,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self._serial: Optional[serial.Serial] = None

    @property
    def is_open(self) -> bool:
        return self._serial is not None and self._serial.is_open

    def open(self) -> None:
        """Abre el puerto serial configurado."""

        if self.is_open:
            return

        try:
            self._serial = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout,
                write_timeout=self.timeout,
            )
        except (serial.SerialException, ValueError) as exc:
            self._serial = None
            raise SerialLinkError(
                f"No se pudo abrir el puerto {self.port}: {exc}"
            ) from exc

    def close(self) -> None:
        """Cierra el puerto serial."""

        if self._serial is not None:
            try:
                if self._serial.is_open:
                    self._serial.close()
            except serial.SerialException as exc:
                raise SerialLinkError(
                    f"Error al cerrar el puerto {self.port}: {exc}"
                ) from exc
            finally:
                self._serial = None

    def send(self, frame: str) -> None:
        """Envía una trama ASCII completa hacia la FPGA."""

        if not self.is_open:
            raise SerialLinkError("El puerto serial no está abierto")

        if not isinstance(frame, str):
            raise SerialLinkError("La trama a transmitir debe ser texto")

        if not frame.endswith("\n"):
            raise SerialLinkError(
                "La trama a transmitir debe terminar con salto de línea"
            )

        try:
            data = frame.encode("ascii")
        except UnicodeEncodeError as exc:
            raise SerialLinkError(
                "La trama contiene caracteres no ASCII"
            ) from exc

        try:
            self._serial.write(data)
            self._serial.flush()
        except (serial.SerialException, serial.SerialTimeoutException) as exc:
            raise SerialLinkError(
                f"Error al transmitir por {self.port}: {exc}"
            ) from exc

    def receive_raw(self) -> Optional[str]:
        """Recibe una trama terminada en '\\n'.

        Devuelve None cuando vence el timeout sin recibir una trama.
        """

        if not self.is_open:
            raise SerialLinkError("El puerto serial no está abierto")

        try:
            data = self._serial.readline()
        except serial.SerialException as exc:
            raise SerialLinkError(
                f"Error al recibir desde {self.port}: {exc}"
            ) from exc

        if not data:
            return None

        try:
            return data.decode("ascii")
        except UnicodeDecodeError as exc:
            raise SerialLinkError(
                "Se recibieron datos que no son ASCII"
            ) from exc

    def receive(self) -> Optional[Message]:
        """Recibe y valida un mensaje enviado por la FPGA."""

        raw = self.receive_raw()

        if raw is None:
            return None

        try:
            return parse_message(raw)
        except ProtocolError as exc:
            raise SerialLinkError(
                f"Trama recibida inválida: {raw!r}: {exc}"
            ) from exc

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
        return False
