# Original board game sounds

Run `python3 tools/generate-board-game-sounds.py` to regenerate these six original
sound effects. They are synthesized from damped sine resonances, seeded filtered
noise and a short victory arpeggio; no recordings or third-party samples are used.

All clips are mono, PCM signed 16-bit, 22,050 Hz. Peak levels are deliberately
soft (0.20–0.29 full scale), with short attack/release envelopes.

- `chess-move.wav`: wooden placement tap, 0.23 s.
- `chess-capture.wav`: two wooden contacts, 0.36 s.
- `checkers-move.wav`: bright checker clack, 0.21 s.
- `checkers-capture.wav`: paired clacks, 0.34 s.
- `connect4-drop.wav`: plastic chute rattle and settling contact, 0.46 s.
- `game-win.wav`: ascending four-note chime, 0.95 s.

The generator checks channel count, bit depth, rate and duration. Repeated runs
produce byte-identical WAVs. In-game loudness and timing require a live test.
