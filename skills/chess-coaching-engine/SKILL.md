---
name: chess-coaching-engine
description: Build automated chess coaching tools - Stockfish/Leela Chess Zero integration, game analysis, puzzle generation, opening repertoire builder, training plans, ELO tracking, and position evaluation. Covers python-chess for board manipulation, UCI engine communication, PGN parsing, and web-based chess UI. Use when building chess training apps, analyzing games, generating puzzles, or creating coaching bots.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Chess, Coaching, Stockfish, Leela Chess Zero, python-chess, Puzzle, Opening, Training, UCI, PGN]
dependencies: [python-chess, stockfish, pandas, matplotlib]
---

# Chess Coaching Engine

## When to Use

- Building automated chess coaching systems
- Integrating Stockfish/Leela Chess Zero for analysis
- Analyzing games and finding mistakes/blunders
- Generating tactical puzzles from real games
- Building opening repertoire trainers
- Creating ELO tracking and progress dashboards
- Web-based chess training applications

## Quick Start

```bash
pip install python-chess stockfish pandas matplotlib cairosvg
```

Download Stockfish binary from https://stockfishchess.org/download/

## Board & Move Basics (python-chess)

```python
import chess
import chess.svg
import chess.pgn

board = chess.Board()

# Make moves
board.push_san("e4")
board.push_san("e5")
board.push_san("Nf3")
board.push_san("Nc6")

# Board state
print(board)
print(f"FEN: {board.fen()}")
print(f"Legal moves: {[board.san(m) for m in board.legal_moves]}")
print(f"Is check: {board.is_check()}")

# Generate SVG
svg = chess.svg.board(board, size=400)
with open("board.svg", "w") as f:
    f.write(svg)
```

## Stockfish Integration

```python
from stockfish import Stockfish

def create_engine(path: str = "stockfish", depth: int = 20,
                   threads: int = 4, hash_mb: int = 256) -> Stockfish:
    sf = Stockfish(path=path, depth=depth, parameters={
        "Threads": threads,
        "Hash": hash_mb,
        "MultiPV": 3,  # Show top 3 lines
    })
    return sf

def analyze_position(engine: Stockfish, fen: str) -> dict:
    engine.set_fen_position(fen)
    evaluation = engine.get_evaluation()
    best_move = engine.get_best_move()
    top_moves = engine.get_top_moves(5)

    return {
        'fen': fen,
        'evaluation': evaluation,  # {'type': 'cp'|'mate', 'value': int}
        'best_move': best_move,
        'top_moves': [
            {
                'move': m['Move'],
                'centipawn': m.get('Centipawn'),
                'mate': m.get('Mate'),
                'pv': m.get('pv', ''),
            }
            for m in top_moves
        ],
    }

engine = create_engine("stockfish.exe")
result = analyze_position(engine, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
print(f"Eval: {result['evaluation']}, Best: {result['best_move']}")
```

## Full Game Analysis

```python
import chess.pgn
import io

def analyze_game(pgn_text: str, engine_path: str = "stockfish",
                  depth: int = 18) -> list[dict]:
    """Analyze every move in a game, classify mistakes."""
    game = chess.pgn.read_game(io.StringIO(pgn_text))
    engine = create_engine(engine_path, depth=depth)
    board = game.board()
    analysis = []

    prev_eval = 0
    for i, move in enumerate(game.mainline_moves()):
        # Evaluate before move
        engine.set_fen_position(board.fen())
        eval_before = engine.get_evaluation()
        best_move = engine.get_best_move()

        # Make the move
        san = board.san(move)
        board.push(move)

        # Evaluate after move
        engine.set_fen_position(board.fen())
        eval_after = engine.get_evaluation()

        # Calculate centipawn loss
        cp_before = eval_before['value'] if eval_before['type'] == 'cp' else 10000 * (1 if eval_before['value'] > 0 else -1)
        cp_after = eval_after['value'] if eval_after['type'] == 'cp' else 10000 * (1 if eval_after['value'] > 0 else -1)

        # Flip evaluation for black's perspective
        if i % 2 == 1:  # Black's move
            cp_loss = cp_before + cp_after  # Both from white's perspective
        else:
            cp_loss = cp_before - (-cp_after)

        cp_loss = abs(cp_loss) if (i % 2 == 0 and cp_after < cp_before) or \
                                   (i % 2 == 1 and cp_after > cp_before) else 0

        # Classify
        if cp_loss > 300:
            classification = "BLUNDER"
        elif cp_loss > 100:
            classification = "MISTAKE"
        elif cp_loss > 50:
            classification = "INACCURACY"
        elif san == best_move:
            classification = "BEST"
        else:
            classification = "GOOD"

        analysis.append({
            'move_number': i // 2 + 1,
            'color': 'White' if i % 2 == 0 else 'Black',
            'move': san,
            'best_move': best_move,
            'eval_before': f"{cp_before/100:+.2f}",
            'eval_after': f"{-cp_after/100:+.2f}",
            'cp_loss': cp_loss,
            'classification': classification,
            'fen': board.fen(),
        })

    return analysis

def game_summary(analysis: list[dict]) -> dict:
    import pandas as pd
    df = pd.DataFrame(analysis)
    summary = {}
    for color in ['White', 'Black']:
        moves = df[df['color'] == color]
        summary[color] = {
            'blunders': int((moves['classification'] == 'BLUNDER').sum()),
            'mistakes': int((moves['classification'] == 'MISTAKE').sum()),
            'inaccuracies': int((moves['classification'] == 'INACCURACY').sum()),
            'best_moves': int((moves['classification'] == 'BEST').sum()),
            'avg_cp_loss': round(moves['cp_loss'].mean(), 1),
            'accuracy_pct': round((1 - moves['cp_loss'].mean() / 100) * 100, 1),
        }
    return summary
```

## Puzzle Generator

```python
def generate_puzzles(pgn_text: str, engine_path: str = "stockfish",
                      min_cp_swing: int = 200, depth: int = 20) -> list[dict]:
    """Extract tactical puzzles from games where one best move exists."""
    analysis = analyze_game(pgn_text, engine_path, depth)
    puzzles = []

    for i, move_info in enumerate(analysis):
        if move_info['cp_loss'] >= min_cp_swing and move_info['classification'] in ['BLUNDER', 'MISTAKE']:
            # The position BEFORE the blunder is a puzzle
            # Solution = the best move the player missed
            puzzle = {
                'fen': analysis[i-1]['fen'] if i > 0 else chess.STARTING_FEN,
                'solution': move_info['best_move'],
                'played': move_info['move'],
                'theme': classify_puzzle_theme(move_info),
                'difficulty': estimate_difficulty(move_info['cp_loss']),
                'to_move': move_info['color'],
            }
            puzzles.append(puzzle)

    return puzzles

def classify_puzzle_theme(move_info: dict) -> str:
    """Classify puzzle theme (simplified)."""
    if move_info.get('eval_after', '').startswith('#'):
        return 'Checkmate'
    cp = move_info['cp_loss']
    if cp > 500:
        return 'Winning Material'
    elif cp > 200:
        return 'Tactics'
    return 'Positional'

def estimate_difficulty(cp_loss: int) -> str:
    if cp_loss > 500:
        return 'Easy'  # Obvious blunder
    elif cp_loss > 200:
        return 'Medium'
    return 'Hard'  # Subtle mistake
```

## Opening Repertoire Builder

```python
class OpeningRepertoire:
    def __init__(self):
        self.repertoire = {}  # FEN -> recommended move + notes

    def add_line(self, moves: list[str], notes: str = ""):
        board = chess.Board()
        for move in moves:
            fen = board.fen()
            board.push_san(move)
            if fen not in self.repertoire:
                self.repertoire[fen] = {
                    'move': move,
                    'notes': notes,
                    'times_practiced': 0,
                    'last_practiced': None,
                }

    def get_recommendation(self, fen: str) -> dict:
        return self.repertoire.get(fen, None)

    def practice_session(self, color: str = 'white', num_positions: int = 10) -> list:
        """Get positions to practice, prioritizing least-practiced."""
        positions = []
        for fen, data in self.repertoire.items():
            board = chess.Board(fen)
            is_our_turn = (color == 'white' and board.turn == chess.WHITE) or \
                          (color == 'black' and board.turn == chess.BLACK)
            if is_our_turn:
                positions.append({'fen': fen, **data})

        positions.sort(key=lambda x: x['times_practiced'])
        return positions[:num_positions]

# Build repertoire for White (Italian Game)
rep = OpeningRepertoire()
rep.add_line(["e4", "e5", "Nf3", "Nc6", "Bc4"], "Italian Game - Main Line")
rep.add_line(["e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "d3"], "Giuoco Pianissimo")
rep.add_line(["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "c3"], "Italian - c3 variation")
rep.add_line(["e4", "c5", "Nf3", "d6", "d4"], "Sicilian - Open")
```

## ELO Tracking & Progress

```python
from datetime import datetime

class ELOTracker:
    def __init__(self, initial_elo: int = 1200):
        self.elo = initial_elo
        self.history = [{'date': datetime.now(), 'elo': initial_elo, 'event': 'start'}]
        self.games = []

    def record_game(self, result: str, opponent_elo: int, time_control: str = 'rapid'):
        """result: 'win', 'loss', 'draw'"""
        K = 32 if self.elo < 1600 else 24 if self.elo < 2000 else 16
        expected = 1 / (1 + 10 ** ((opponent_elo - self.elo) / 400))
        actual = {'win': 1.0, 'draw': 0.5, 'loss': 0.0}[result]

        self.elo = round(self.elo + K * (actual - expected))
        self.history.append({
            'date': datetime.now(), 'elo': self.elo,
            'result': result, 'opponent_elo': opponent_elo,
        })
        self.games.append({
            'result': result, 'opponent_elo': opponent_elo,
            'elo_change': round(K * (actual - expected)),
        })

    def stats(self) -> dict:
        if not self.games:
            return {'elo': self.elo, 'games': 0}
        wins = sum(1 for g in self.games if g['result'] == 'win')
        draws = sum(1 for g in self.games if g['result'] == 'draw')
        return {
            'current_elo': self.elo,
            'peak_elo': max(h['elo'] for h in self.history),
            'total_games': len(self.games),
            'win_rate': f"{wins/len(self.games)*100:.1f}%",
            'draw_rate': f"{draws/len(self.games)*100:.1f}%",
        }
```

## Training Plan Generator

```python
def create_training_plan(elo: int, hours_per_week: int = 7) -> dict:
    """Generate personalized training plan based on ELO level."""
    if elo < 1000:
        plan = {
            'level': 'Beginner',
            'focus': ['Basic tactics (forks, pins, skewers)', 'Checkmate patterns',
                      'Piece values and basic endgames', 'Opening principles'],
            'split': {'Puzzles': 40, 'Games': 30, 'Lessons': 20, 'Endgames': 10},
            'daily_puzzles': 10,
            'recommended_openings': {
                'white': 'Italian Game (e4 e5 Nf3 Nc6 Bc4)',
                'black_vs_e4': 'Sicilian Defense (...c5) or Mirror (e5)',
                'black_vs_d4': 'Queens Gambit Declined (...d5 ...e6)',
            },
        }
    elif elo < 1400:
        plan = {
            'level': 'Intermediate',
            'focus': ['Complex tactics (combinations, sacrifices)', 'Pawn structure',
                      'Basic positional play', 'Rook endgames'],
            'split': {'Puzzles': 35, 'Games': 30, 'Analysis': 20, 'Endgames': 15},
            'daily_puzzles': 15,
            'recommended_openings': {
                'white': 'Italian/Ruy Lopez',
                'black_vs_e4': 'Sicilian Najdorf or French',
                'black_vs_d4': 'Nimzo-Indian or QGD',
            },
        }
    elif elo < 1800:
        plan = {
            'level': 'Advanced',
            'focus': ['Deep calculation (4-5 moves ahead)', 'Positional sacrifices',
                      'Prophylaxis', 'Complex endgames', 'Opening preparation'],
            'split': {'Analysis': 30, 'Puzzles': 25, 'Games': 25, 'Openings': 20},
            'daily_puzzles': 20,
            'recommended_openings': {
                'white': 'Build deep repertoire in 1 main system',
                'black_vs_e4': 'Sicilian + backup system',
                'black_vs_d4': 'Build complete repertoire',
            },
        }
    else:
        plan = {
            'level': 'Expert',
            'focus': ['Master game study', 'Opening novelties', 'Endgame theory',
                      'Psychological preparation', 'Time management'],
            'split': {'Analysis': 35, 'Openings': 25, 'Games': 20, 'Study': 20},
            'daily_puzzles': 25,
        }

    plan['hours_per_week'] = hours_per_week
    plan['elo'] = elo
    return plan

print(create_training_plan(1200, hours_per_week=7))
```

## Web UI Integration (with chessboard.js)

```python
from flask import Flask, render_template_string, jsonify, request

CHESS_UI_HTML = """
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://unpkg.com/@chrisoakman/chessboardjs/dist/chessboard-1.0.0.min.css">
  <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
  <script src="https://unpkg.com/@chrisoakman/chessboardjs/dist/chessboard-1.0.0.min.js"></script>
</head>
<body>
  <div id="board" style="width:500px"></div>
  <div id="analysis"></div>
  <script>
    var board = Chessboard('board', {draggable: true, position: 'start',
        onDrop: function(src, tgt) {
            fetch('/analyze', {method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({from: src, to: tgt})
            }).then(r => r.json()).then(d => {
                document.getElementById('analysis').innerHTML = JSON.stringify(d);
            });
        }
    });
  </script>
</body>
</html>
"""

app = Flask(__name__)

@app.route('/')
def index():
    return render_template_string(CHESS_UI_HTML)

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    return jsonify({'status': 'ok', 'move': f"{data['from']}-{data['to']}"})
```

## Key Libraries

| Library | Purpose |
|---------|---------|
| `python-chess` | Board representation, PGN parsing, move generation |
| `stockfish` (Python wrapper) | Engine analysis via UCI protocol |
| `cairosvg` | Convert board SVG to PNG |
| `Flask` + `chessboard.js` | Web-based chess UI |
| `lichess` API | Online game data, puzzles database |
