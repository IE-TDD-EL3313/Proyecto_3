"""Pruebas unitarias del protocolo UART del Jugador 2."""

import sys
import unittest
from pathlib import Path

# Permite importar módulos desde pc/src sin instalar un paquete.
SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from protocol import (  # noqa: E402
    ProtocolError,
    build_placement,
    build_shot,
    parse_message,
)


class TestOutgoingMessages(unittest.TestCase):

    def test_build_placement(self):
        self.assertEqual(
            build_placement(1, 3, 4, "H"),
            "P,1,3,4,H\n",
        )

    def test_build_placement_vertical_lowercase(self):
        self.assertEqual(
            build_placement(2, 0, 7, "v"),
            "P,2,0,7,V\n",
        )

    def test_build_shot(self):
        self.assertEqual(
            build_shot(5, 2),
            "S,5,2\n",
        )

    def test_invalid_ship(self):
        with self.assertRaises(ProtocolError):
            build_placement(3, 0, 0, "H")

    def test_invalid_row(self):
        with self.assertRaises(ProtocolError):
            build_shot(8, 0)

    def test_invalid_column(self):
        with self.assertRaises(ProtocolError):
            build_shot(0, -1)

    def test_invalid_orientation(self):
        with self.assertRaises(ProtocolError):
            build_placement(0, 0, 0, "X")


class TestIncomingMessages(unittest.TestCase):

    def test_placement_accepted(self):
        msg = parse_message("PA,1\n")

        self.assertEqual(msg.type, "PA")
        self.assertEqual(msg.ship, 1)

    def test_placement_rejected_overlap(self):
        msg = parse_message("PR,1,O\n")

        self.assertEqual(msg.type, "PR")
        self.assertEqual(msg.ship, 1)
        self.assertEqual(msg.reason, "O")

    def test_placement_rejected_outside_board(self):
        msg = parse_message("PR,2,F\n")

        self.assertEqual(msg.type, "PR")
        self.assertEqual(msg.ship, 2)
        self.assertEqual(msg.reason, "F")

    def test_battle_start(self):
        msg = parse_message("B\n")

        self.assertEqual(msg.type, "B")

    def test_turn(self):
        msg = parse_message("T,2\n")

        self.assertEqual(msg.type, "T")
        self.assertEqual(msg.player, 2)

    def test_shot_result(self):
        msg = parse_message("SR,5,2,I\n")

        self.assertEqual(msg.type, "SR")
        self.assertEqual(msg.row, 5)
        self.assertEqual(msg.column, 2)
        self.assertEqual(msg.result, "I")

    def test_received_shot(self):
        msg = parse_message("DR,3,6,F\n")

        self.assertEqual(msg.type, "DR")
        self.assertEqual(msg.row, 3)
        self.assertEqual(msg.column, 6)
        self.assertEqual(msg.result, "F")

    def test_game_finished(self):
        msg = parse_message("FIN,2\n")

        self.assertEqual(msg.type, "FIN")
        self.assertEqual(msg.winner, 2)

    def test_crlf_is_accepted(self):
        msg = parse_message("T,1\r\n")

        self.assertEqual(msg.type, "T")
        self.assertEqual(msg.player, 1)


class TestInvalidIncomingMessages(unittest.TestCase):

    def test_empty_message(self):
        with self.assertRaises(ProtocolError):
            parse_message("\n")

    def test_missing_newline(self):
        with self.assertRaises(ProtocolError):
            parse_message("T,2")

    def test_unknown_message(self):
        with self.assertRaises(ProtocolError):
            parse_message("XYZ,1\n")

    def test_invalid_field_count(self):
        with self.assertRaises(ProtocolError):
            parse_message("SR,5,2\n")

    def test_non_integer_coordinate(self):
        with self.assertRaises(ProtocolError):
            parse_message("SR,A,2,I\n")

    def test_coordinate_out_of_range(self):
        with self.assertRaises(ProtocolError):
            parse_message("DR,8,0,F\n")

    def test_invalid_result(self):
        with self.assertRaises(ProtocolError):
            parse_message("SR,1,2,X\n")

    def test_invalid_rejection_reason(self):
        with self.assertRaises(ProtocolError):
            parse_message("PR,1,X\n")

    def test_invalid_player(self):
        with self.assertRaises(ProtocolError):
            parse_message("T,3\n")

    def test_invalid_winner(self):
        with self.assertRaises(ProtocolError):
            parse_message("FIN,0\n")

    def test_invalid_ship_received(self):
        with self.assertRaises(ProtocolError):
            parse_message("PA,5\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
