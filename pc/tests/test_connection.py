"""Pruebas de conexión, reconexión y sincronización UART."""

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(
    0,
    str(Path(__file__).resolve().parents[1] / "src"),
)

from player2 import Player2App
from player2_state import Player2State
from protocol import parse_message


class FakeLink:
    """Simula la comunicación con la FPGA."""

    def __init__(self, port):
        self.port = port
        self.is_open = False
        self.sent = []
        self.rx_queue = []

    def open(self):
        self.is_open = True

    def close(self):
        self.is_open = False

    def send(self, frame):
        if not self.is_open:
            raise RuntimeError("Puerto cerrado")
        self.sent.append(frame)

    def receive(self):
        if self.rx_queue:
            return parse_message(self.rx_queue.pop(0))
        return None


class TestConnection(unittest.TestCase):

    def setUp(self):
        # Construir la aplicación sin inicializar Tkinter.
        self.app = Player2App.__new__(Player2App)

        self.app.state = Player2State()
        self.app.link = FakeLink("/dev/ttyTEST")

        self.app.port_var = MagicMock()
        self.app.port_var.get.return_value = "/dev/ttyTEST"

        self.app.connection_var = MagicMock()
        self.app.connect_button = MagicMock()
        self.app.status_var = MagicMock()

        self.app.root = MagicMock()

        self.app._refresh = MagicMock()

    @patch("player2.SerialLink", FakeLink)
    def test_connect_sends_statistics_request(self):
        self.app._toggle_connection()

        self.assertTrue(self.app.link.is_open)
        self.assertEqual(self.app.link.sent, ["Q\n"])

    @patch("player2.SerialLink", FakeLink)
    def test_disconnect_closes_port(self):
        self.app._toggle_connection()
        self.app._toggle_connection()

        self.assertFalse(self.app.link.is_open)

        self.app.connection_var.set.assert_any_call(
            "Desconectado"
        )

    @patch("player2.SerialLink", FakeLink)
    def test_reconnect_requests_statistics_again(self):
        self.app._toggle_connection()

        first_link = self.app.link

        self.assertEqual(first_link.sent, ["Q\n"])

        self.app._toggle_connection()

        self.assertFalse(first_link.is_open)

        self.app._toggle_connection()

        self.assertTrue(self.app.link.is_open)
        self.assertEqual(self.app.link.sent, ["Q\n"])
        self.assertIsNot(self.app.link, first_link)

    @patch("player2.SerialLink", FakeLink)
    def test_receive_statistics_after_connection(self):
        self.app._toggle_connection()

        self.app.link.rx_queue.append(
            "ST,03,02,05,04,07,06\n"
        )

        self.app._poll_serial()

        self.assertEqual(self.app.state.wins_j1, 3)
        self.assertEqual(self.app.state.wins_j2, 2)
        self.assertEqual(self.app.state.hits_j1, 5)
        self.assertEqual(self.app.state.misses_j1, 4)
        self.assertEqual(self.app.state.hits_j2, 7)
        self.assertEqual(self.app.state.misses_j2, 6)


if __name__ == "__main__":
    unittest.main()
