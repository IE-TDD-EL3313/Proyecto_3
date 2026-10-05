"""Pruebas unitarias de la capa de comunicación serial."""

import sys
import unittest
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from serial_link import SerialLink, SerialLinkError  # noqa: E402


class FakeSerial:
    """Puerto serial simulado para pruebas sin FPGA."""

    def __init__(self):
        self.is_open = True
        self.written = bytearray()
        self.rx_queue = []
        self.flush_called = False

    def write(self, data):
        self.written.extend(data)
        return len(data)

    def flush(self):
        self.flush_called = True

    def readline(self):
        if self.rx_queue:
            return self.rx_queue.pop(0)
        return b""

    def close(self):
        self.is_open = False


class TestSerialLink(unittest.TestCase):

    def setUp(self):
        self.link = SerialLink("/dev/ttyTEST")
        self.fake = FakeSerial()
        self.link._serial = self.fake

    def test_default_configuration(self):
        self.assertEqual(self.link.port, "/dev/ttyTEST")
        self.assertEqual(self.link.baudrate, 115200)
        self.assertEqual(self.link.timeout, 0.1)
        self.assertTrue(self.link.is_open)

    def test_send_placement(self):
        self.link.send("P,1,3,4,H\n")

        self.assertEqual(
            self.fake.written,
            b"P,1,3,4,H\n",
        )
        self.assertTrue(self.fake.flush_called)

    def test_send_shot(self):
        self.link.send("S,5,2\n")

        self.assertEqual(
            self.fake.written,
            b"S,5,2\n",
        )

    def test_send_requires_newline(self):
        with self.assertRaises(SerialLinkError):
            self.link.send("S,5,2")

    def test_send_requires_ascii(self):
        with self.assertRaises(SerialLinkError):
            self.link.send("S,á,2\n")

    def test_send_requires_open_port(self):
        self.link._serial = None

        with self.assertRaises(SerialLinkError):
            self.link.send("S,5,2\n")

    def test_receive_raw(self):
        self.fake.rx_queue.append(b"T,2\n")

        raw = self.link.receive_raw()

        self.assertEqual(raw, "T,2\n")

    def test_receive_timeout(self):
        self.assertIsNone(self.link.receive_raw())

    def test_receive_valid_message(self):
        self.fake.rx_queue.append(b"SR,5,2,I\n")

        msg = self.link.receive()

        self.assertEqual(msg.type, "SR")
        self.assertEqual(msg.row, 5)
        self.assertEqual(msg.column, 2)
        self.assertEqual(msg.result, "I")

    def test_receive_crlf(self):
        self.fake.rx_queue.append(b"T,1\r\n")

        msg = self.link.receive()

        self.assertEqual(msg.type, "T")
        self.assertEqual(msg.player, 1)

    def test_receive_invalid_protocol(self):
        self.fake.rx_queue.append(b"XYZ,1\n")

        with self.assertRaises(SerialLinkError):
            self.link.receive()

    def test_receive_non_ascii(self):
        self.fake.rx_queue.append(b"\xff\xfe\n")

        with self.assertRaises(SerialLinkError):
            self.link.receive_raw()

    def test_receive_requires_open_port(self):
        self.link._serial = None

        with self.assertRaises(SerialLinkError):
            self.link.receive_raw()

    def test_close(self):
        self.link.close()

        self.assertFalse(self.fake.is_open)
        self.assertFalse(self.link.is_open)


if __name__ == "__main__":
    unittest.main(verbosity=2)
