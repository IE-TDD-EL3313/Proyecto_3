"""Pruebas del estado de presentación del Jugador 2."""

import sys
import unittest
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from player2_state import Player2State  # noqa: E402
from protocol import Message, ProtocolError  # noqa: E402


class TestPlacement(unittest.TestCase):

    def setUp(self):
        self.state = Player2State()

    def test_request_placement(self):
        frame = self.state.request_placement(0, 2, 3, "H")

        self.assertEqual(frame, "P,0,2,3,H\n")
        self.assertEqual(
            self.state.pending_placements[0],
            (2, 3, "H"),
        )

        # Todavía no debe mostrarse el barco.
        self.assertNotIn((2, 3), self.state.own_board)

    def test_accepted_horizontal_ship(self):
        self.state.request_placement(0, 2, 3, "H")
        self.state.handle_message(Message(type="PA", ship=0))

        expected = {
            (2, 3),
            (2, 4),
            (2, 5),
            (2, 6),
        }

        for cell in expected:
            self.assertEqual(self.state.own_board[cell], "B")

        self.assertNotIn(0, self.state.pending_placements)
        self.assertEqual(
            self.state.accepted_ships[0],
            (2, 3, "H"),
        )

    def test_accepted_vertical_ship(self):
        self.state.request_placement(1, 1, 5, "V")
        self.state.handle_message(Message(type="PA", ship=1))

        expected = {
            (1, 5),
            (2, 5),
            (3, 5),
        }

        for cell in expected:
            self.assertEqual(self.state.own_board[cell], "B")

    def test_rejected_ship_is_not_drawn(self):
        self.state.request_placement(2, 3, 4, "H")

        self.state.handle_message(
            Message(type="PR", ship=2, reason="O")
        )

        self.assertNotIn(2, self.state.pending_placements)
        self.assertNotIn(2, self.state.accepted_ships)
        self.assertEqual(self.state.own_board, {})
        self.assertIn("traslapa", self.state.status)

    def test_outside_board_rejection_message(self):
        self.state.request_placement(1, 7, 7, "V")

        self.state.handle_message(
            Message(type="PR", ship=1, reason="F")
        )

        self.assertIn("fuera del tablero", self.state.status)


class TestBattle(unittest.TestCase):

    def setUp(self):
        self.state = Player2State()

    def test_battle_start(self):
        self.state.handle_message(Message(type="B"))

        self.assertTrue(self.state.battle_started)
        self.assertIn("batalla", self.state.status)

    def test_player2_turn(self):
        self.state.handle_message(
            Message(type="T", player=2)
        )

        self.assertEqual(self.state.turn, 2)
        self.assertEqual(
            self.state.status,
            "Turno del Jugador 2.",
        )

    def test_player1_turn(self):
        self.state.handle_message(
            Message(type="T", player=1)
        )

        self.assertEqual(self.state.turn, 1)
        self.assertEqual(
            self.state.status,
            "Turno del Jugador 1.",
        )

    def test_request_shot_does_not_modify_enemy_board(self):
        frame = self.state.request_shot(5, 2)

        self.assertEqual(frame, "S,5,2\n")
        self.assertEqual(self.state.pending_shot, (5, 2))
        self.assertEqual(self.state.enemy_board, {})

    def test_shot_result_hit(self):
        self.state.request_shot(5, 2)

        self.state.handle_message(
            Message(
                type="SR",
                row=5,
                column=2,
                result="I",
            )
        )

        self.assertEqual(
            self.state.enemy_board[(5, 2)],
            "I",
        )
        self.assertIsNone(self.state.pending_shot)

    def test_shot_result_miss(self):
        self.state.handle_message(
            Message(
                type="SR",
                row=4,
                column=1,
                result="F",
            )
        )

        self.assertEqual(
            self.state.enemy_board[(4, 1)],
            "F",
        )

    def test_shot_result_sunk(self):
        self.state.handle_message(
            Message(
                type="SR",
                row=3,
                column=3,
                result="H",
            )
        )

        self.assertEqual(
            self.state.enemy_board[(3, 3)],
            "H",
        )
        self.assertIn("hundido", self.state.status)

    def test_received_shot(self):
        self.state.handle_message(
            Message(
                type="DR",
                row=3,
                column=6,
                result="F",
            )
        )

        self.assertEqual(
            self.state.own_board[(3, 6)],
            "F",
        )


class TestGameEnd(unittest.TestCase):

    def test_player2_wins(self):
        state = Player2State()

        state.handle_message(
            Message(type="FIN", winner=2)
        )

        self.assertTrue(state.game_finished)
        self.assertEqual(state.winner, 2)
        self.assertIn("ganó el Jugador 2", state.status)

    def test_player1_wins(self):
        state = Player2State()

        state.handle_message(
            Message(type="FIN", winner=1)
        )

        self.assertTrue(state.game_finished)
        self.assertEqual(state.winner, 1)
        self.assertIn("ganó el Jugador 1", state.status)

    def test_summary(self):
        state = Player2State()

        state.enemy_board[(0, 0)] = "I"
        state.enemy_board[(0, 1)] = "H"
        state.enemy_board[(0, 2)] = "F"

        state.own_board[(1, 1)] = "I"
        state.winner = 2

        summary = state.summary()

        self.assertIn("Victoria del Jugador 2", summary)
        self.assertIn("Impactos realizados: 2", summary)
        self.assertIn("Fallos realizados: 1", summary)
        self.assertIn("Impactos recibidos: 1", summary)


class TestUnsupportedMessage(unittest.TestCase):

    def test_unsupported_message(self):
        state = Player2State()

        with self.assertRaises(ProtocolError):
            state.handle_message(Message(type="XYZ"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
