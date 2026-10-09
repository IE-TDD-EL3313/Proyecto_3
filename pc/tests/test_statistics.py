"""Pruebas de estadísticas de ambos jugadores."""

import sys
import unittest
from pathlib import Path

sys.path.insert(
    0,
    str(Path(__file__).resolve().parents[1] / "src"),
)

from player2_state import Player2State
from protocol import parse_message


class TestStatistics(unittest.TestCase):

    def setUp(self):
        self.state = Player2State()

    def test_initial_statistics(self):
        self.assertEqual(self.state.wins_j1, 0)
        self.assertEqual(self.state.wins_j2, 0)
        self.assertEqual(self.state.hits_j1, 0)
        self.assertEqual(self.state.hits_j2, 0)
        self.assertEqual(self.state.misses_j1, 0)
        self.assertEqual(self.state.misses_j2, 0)

    def test_player2_shots(self):
        self.state.handle_message(parse_message("SR,0,0,I\n"))
        self.state.handle_message(parse_message("SR,0,1,H\n"))
        self.state.handle_message(parse_message("SR,0,2,F\n"))

        self.assertEqual(self.state.hits_j2, 2)
        self.assertEqual(self.state.misses_j2, 1)

    def test_player1_shots(self):
        self.state.handle_message(parse_message("DR,1,0,I\n"))
        self.state.handle_message(parse_message("DR,1,1,H\n"))
        self.state.handle_message(parse_message("DR,1,2,F\n"))

        self.assertEqual(self.state.hits_j1, 2)
        self.assertEqual(self.state.misses_j1, 1)

    def test_duplicate_shot(self):
        message = parse_message("SR,2,3,I\n")

        self.state.handle_message(message)
        self.state.handle_message(message)

        self.assertEqual(self.state.hits_j2, 1)

    def test_duplicate_received_shot(self):
        message = parse_message("DR,2,3,F\n")

        self.state.handle_message(message)
        self.state.handle_message(message)

        self.assertEqual(self.state.misses_j1, 1)

    def test_ship_cell_counts_as_first_shot(self):
        self.state.own_board[(3, 4)] = "B"

        self.state.handle_message(
            parse_message("DR,3,4,I\n")
        )

        self.assertEqual(self.state.hits_j1, 1)

    def test_victories_accumulate(self):
        self.state.handle_message(parse_message("FIN,1\n"))
        self.state.reset()

        self.state.handle_message(parse_message("FIN,2\n"))
        self.state.reset()

        self.state.handle_message(parse_message("FIN,1\n"))

        self.assertEqual(self.state.wins_j1, 2)
        self.assertEqual(self.state.wins_j2, 1)

    def test_duplicate_victory(self):
        message = parse_message("FIN,1\n")

        self.state.handle_message(message)
        self.state.handle_message(message)

        self.assertEqual(self.state.wins_j1, 1)

    def test_reset_preserves_wins(self):
        self.state.handle_message(parse_message("SR,0,0,I\n"))
        self.state.handle_message(parse_message("DR,1,1,F\n"))
        self.state.handle_message(parse_message("FIN,2\n"))

        self.state.reset()

        self.assertEqual(self.state.wins_j1, 0)
        self.assertEqual(self.state.wins_j2, 1)
        self.assertEqual(self.state.hits_j1, 0)
        self.assertEqual(self.state.hits_j2, 0)
        self.assertEqual(self.state.misses_j1, 0)
        self.assertEqual(self.state.misses_j2, 0)


    def test_st_synchronizes_all_statistics(self):
        msg = parse_message("ST,03,02,05,04,07,06\n")
        self.state.handle_message(msg)

        self.assertEqual(self.state.wins_j1, 3)
        self.assertEqual(self.state.wins_j2, 2)
        self.assertEqual(self.state.hits_j1, 5)
        self.assertEqual(self.state.misses_j1, 4)
        self.assertEqual(self.state.hits_j2, 7)
        self.assertEqual(self.state.misses_j2, 6)

    def test_st_replaces_previous_statistics(self):
        self.state.handle_message(parse_message("SR,0,0,I\n"))
        self.state.handle_message(parse_message("FIN,2\n"))

        msg = parse_message("ST,03,02,05,04,07,06\n")
        self.state.handle_message(msg)
        self.state.handle_message(msg)

        self.assertEqual(self.state.wins_j1, 3)
        self.assertEqual(self.state.wins_j2, 2)
        self.assertEqual(self.state.hits_j2, 7)

    def test_st_then_game_reset(self):
        self.state.handle_message(
            parse_message("ST,03,02,05,04,07,06\n")
        )

        self.state.reset()

        self.assertEqual(self.state.wins_j1, 3)
        self.assertEqual(self.state.wins_j2, 2)
        self.assertEqual(self.state.hits_j1, 0)
        self.assertEqual(self.state.misses_j1, 0)
        self.assertEqual(self.state.hits_j2, 0)
        self.assertEqual(self.state.misses_j2, 0)

    def test_st_then_global_reset(self):
        self.state.handle_message(
            parse_message("ST,03,02,05,04,07,06\n")
        )

        self.state.reset_all()

        self.assertEqual(self.state.wins_j1, 0)
        self.assertEqual(self.state.wins_j2, 0)
        self.assertEqual(self.state.hits_j1, 0)
        self.assertEqual(self.state.misses_j1, 0)
        self.assertEqual(self.state.hits_j2, 0)
        self.assertEqual(self.state.misses_j2, 0)

    def test_invalid_st_messages(self):
        from protocol import ProtocolError

        invalid_frames = [
            "ST,03,02,05,04,07\n",
            "ST,03,02,05,04,07,100\n",
            "ST,03,02,05,04,07,XX\n",
            "ST,03,02,05,04,07,-1\n",
            "ST,03,02,05,04,07,6\n",
            "ST,03,02,05,04,07,06,01\n",
        ]

        for frame in invalid_frames:
            with self.subTest(frame=frame):
                with self.assertRaises(ProtocolError):
                    parse_message(frame)


if __name__ == "__main__":
    unittest.main()
