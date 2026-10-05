"""Prueba de integración del flujo completo del Jugador 2.

Simula las respuestas de la FPGA sin requerir hardware físico.
"""

import sys
import unittest
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from player2_state import Player2State  # noqa: E402
from protocol import parse_message  # noqa: E402


class TestCompleteGameFlow(unittest.TestCase):

    def test_complete_player2_game(self):
        state = Player2State()

        # ----------------------------------------------------------
        # 1. Colocación del barco 0: aceptada
        # ----------------------------------------------------------
        frame = state.request_placement(0, 0, 0, "H")
        self.assertEqual(frame, "P,0,0,0,H\n")

        state.handle_message(parse_message("PA,0\n"))

        self.assertIn(0, state.accepted_ships)
        self.assertEqual(state.own_board[(0, 0)], "B")
        self.assertEqual(state.own_board[(0, 3)], "B")

        # ----------------------------------------------------------
        # 2. Barco 1: primer intento rechazado
        # ----------------------------------------------------------
        frame = state.request_placement(1, 7, 7, "V")
        self.assertEqual(frame, "P,1,7,7,V\n")

        state.handle_message(parse_message("PR,1,F\n"))

        self.assertNotIn(1, state.accepted_ships)
        self.assertIn("fuera del tablero", state.status)

        # ----------------------------------------------------------
        # 3. Barco 1: segundo intento aceptado
        # ----------------------------------------------------------
        frame = state.request_placement(1, 2, 2, "V")
        self.assertEqual(frame, "P,1,2,2,V\n")

        state.handle_message(parse_message("PA,1\n"))

        self.assertIn(1, state.accepted_ships)

        # ----------------------------------------------------------
        # 4. Barco 2: aceptado
        # ----------------------------------------------------------
        frame = state.request_placement(2, 6, 4, "H")
        self.assertEqual(frame, "P,2,6,4,H\n")

        state.handle_message(parse_message("PA,2\n"))

        self.assertEqual(len(state.accepted_ships), 3)

        # ----------------------------------------------------------
        # 5. FPGA anuncia inicio de batalla
        # ----------------------------------------------------------
        state.handle_message(parse_message("B\n"))

        self.assertTrue(state.battle_started)

        # ----------------------------------------------------------
        # 6. Turno del Jugador 2
        # ----------------------------------------------------------
        state.handle_message(parse_message("T,2\n"))

        self.assertEqual(state.turn, 2)

        # ----------------------------------------------------------
        # 7. Jugador 2 dispara y falla
        # ----------------------------------------------------------
        frame = state.request_shot(1, 1)
        self.assertEqual(frame, "S,1,1\n")

        # El tablero no cambia hasta recibir SR.
        self.assertNotIn((1, 1), state.enemy_board)

        state.handle_message(parse_message("SR,1,1,F\n"))

        self.assertEqual(state.enemy_board[(1, 1)], "F")

        # ----------------------------------------------------------
        # 8. Turno del Jugador 1 y disparo recibido
        # ----------------------------------------------------------
        state.handle_message(parse_message("T,1\n"))

        self.assertEqual(state.turn, 1)

        state.handle_message(parse_message("DR,0,0,I\n"))

        self.assertEqual(state.own_board[(0, 0)], "I")

        # ----------------------------------------------------------
        # 9. Nuevo turno del Jugador 2: impacto
        # ----------------------------------------------------------
        state.handle_message(parse_message("T,2\n"))

        frame = state.request_shot(3, 5)
        self.assertEqual(frame, "S,3,5\n")

        state.handle_message(parse_message("SR,3,5,I\n"))

        self.assertEqual(state.enemy_board[(3, 5)], "I")

        # ----------------------------------------------------------
        # 10. Otro disparo confirmado como barco hundido
        # ----------------------------------------------------------
        state.handle_message(parse_message("T,2\n"))

        frame = state.request_shot(3, 6)
        self.assertEqual(frame, "S,3,6\n")

        state.handle_message(parse_message("SR,3,6,H\n"))

        self.assertEqual(state.enemy_board[(3, 6)], "H")

        # ----------------------------------------------------------
        # 11. FPGA anuncia fin de partida
        # ----------------------------------------------------------
        state.handle_message(parse_message("FIN,2\n"))

        self.assertTrue(state.game_finished)
        self.assertEqual(state.winner, 2)

        # ----------------------------------------------------------
        # 12. Resumen
        # ----------------------------------------------------------
        summary = state.summary()

        self.assertIn("Victoria del Jugador 2", summary)
        self.assertIn("Impactos realizados: 2", summary)
        self.assertIn("Fallos realizados: 1", summary)
        self.assertIn("Impactos recibidos: 1", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
