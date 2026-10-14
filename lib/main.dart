import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() => runApp(const BrickBreakerApp());

class BrickBreakerApp extends StatelessWidget {
  const BrickBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brick Breaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

/// The game world is always [worldWidth] units wide; its height follows the
/// screen's aspect ratio. Everything is drawn scaled to fit the screen.
const double worldWidth = 360;

const double paddleWidth = 72;
const double paddleHeight = 12;
const double paddleBottomGap = 36;
const double paddleSpeed = 340; // world units per second
const double ballRadius = 7;
const double baseBallSpeed = 280;

const int brickCols = 8;
const double brickHeight = 18;
const double brickGap = 4;
const double brickTop = 48;
const double brickSideMargin = 8;
const List<Color> rowColors = [
  Color(0xFFEF5350), // red
  Color(0xFFFF9800), // orange
  Color(0xFFFFEB3B), // yellow
  Color(0xFF66BB6A), // green
  Color(0xFF42A5F5), // blue
  Color(0xFFAB47BC), // purple
];

const int startingLives = 3;

class Brick {
  Brick(this.rect, this.color);

  final Rect rect;
  final Color color;
  bool alive = true;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final FocusNode _keyboardFocus = FocusNode();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _worldHeight = 600;
  double _paddleX = worldWidth / 2; // paddle center
  Offset _ball = Offset.zero;
  Offset _velocity = Offset.zero;
  bool _launched = false;

  bool _leftHeld = false;
  bool _rightHeld = false;

  int _lives = startingLives;
  int _score = 0;
  int _level = 1;
  List<Brick> _bricks = [];

  bool get _gameOver => _lives <= 0;
  double get _paddleTop => _worldHeight - paddleBottomGap;
  Rect get _paddleRect => Rect.fromLTWH(
        _paddleX - paddleWidth / 2,
        _paddleTop,
        paddleWidth,
        paddleHeight,
      );

  @override
  void initState() {
    super.initState();
    _resetGame();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _resetGame() {
    _lives = startingLives;
    _score = 0;
    _level = 1;
    _paddleX = worldWidth / 2;
    _bricks = _buildBricks();
    _launched = false;
  }

  List<Brick> _buildBricks() {
    final brickWidth =
        (worldWidth - 2 * brickSideMargin - (brickCols - 1) * brickGap) /
            brickCols;
    return [
      for (var row = 0; row < rowColors.length; row++)
        for (var col = 0; col < brickCols; col++)
          Brick(
            Rect.fromLTWH(
              brickSideMargin + col * (brickWidth + brickGap),
              brickTop + row * (brickHeight + brickGap),
              brickWidth,
              brickHeight,
            ),
            rowColors[row],
          ),
    ];
  }

  void _launch() {
    if (_launched || _gameOver) return;
    final speed = baseBallSpeed + (_level - 1) * 30;
    // Random angle between 15° and 40° off vertical, either direction.
    final angle = (15 + _random.nextDouble() * 25) *
        pi /
        180 *
        (_random.nextBool() ? 1 : -1);
    setState(() {
      _velocity = Offset(speed * sin(angle), -speed * cos(angle));
      _launched = true;
    });
  }

  void _onTick(Duration elapsed) {
    // Clamp dt so a backgrounded tab doesn't teleport the ball on return.
    final dt = min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 30);
    _lastTick = elapsed;
    if (_gameOver) return;
    setState(() => _update(dt));
  }

  void _update(double dt) {
    final direction = (_rightHeld ? 1 : 0) - (_leftHeld ? 1 : 0);
    _paddleX = (_paddleX + direction * paddleSpeed * dt)
        .clamp(paddleWidth / 2, worldWidth - paddleWidth / 2);

    if (!_launched) {
      _ball = Offset(_paddleX, _paddleTop - ballRadius - 1);
      return;
    }

    // Small sub-steps keep the fast ball from tunnelling through bricks.
    const subSteps = 4;
    for (var i = 0; i < subSteps && _launched; i++) {
      _step(dt / subSteps);
    }

    if (_bricks.every((b) => !b.alive)) {
      _level++;
      _bricks = _buildBricks();
      _launched = false;
    }
  }

  void _step(double h) {
    var p = _ball + _velocity * h;
    var v = _velocity;

    // Walls and ceiling.
    if (p.dx < ballRadius) {
      p = Offset(ballRadius, p.dy);
      v = Offset(v.dx.abs(), v.dy);
    } else if (p.dx > worldWidth - ballRadius) {
      p = Offset(worldWidth - ballRadius, p.dy);
      v = Offset(-v.dx.abs(), v.dy);
    }
    if (p.dy < ballRadius) {
      p = Offset(p.dx, ballRadius);
      v = Offset(v.dx, v.dy.abs());
    }

    // Paddle: bounce angle depends on where the ball hits it.
    final paddle = _paddleRect;
    if (v.dy > 0 &&
        p.dy + ballRadius >= paddle.top &&
        p.dy - ballRadius <= paddle.bottom &&
        p.dx >= paddle.left - ballRadius &&
        p.dx <= paddle.right + ballRadius) {
      final hit = ((p.dx - _paddleX) / (paddleWidth / 2)).clamp(-1.0, 1.0);
      final angle = hit * 60 * pi / 180;
      final speed = v.distance;
      v = Offset(speed * sin(angle), -speed * cos(angle));
      p = Offset(p.dx, paddle.top - ballRadius);
    }

    // Bricks: break at most one per sub-step.
    for (final brick in _bricks) {
      if (!brick.alive) continue;
      final r = brick.rect;
      final closest = Offset(
        p.dx.clamp(r.left, r.right),
        p.dy.clamp(r.top, r.bottom),
      );
      if ((p - closest).distanceSquared > ballRadius * ballRadius) continue;

      brick.alive = false;
      _score += 10;
      final overlapX =
          min(p.dx + ballRadius - r.left, r.right - (p.dx - ballRadius));
      final overlapY =
          min(p.dy + ballRadius - r.top, r.bottom - (p.dy - ballRadius));
      if (overlapX < overlapY) {
        v = Offset(p.dx < r.center.dx ? -v.dx.abs() : v.dx.abs(), v.dy);
      } else {
        v = Offset(v.dx, p.dy < r.center.dy ? -v.dy.abs() : v.dy.abs());
      }
      break;
    }

    _ball = p;
    _velocity = v;

    // Ball fell past the paddle.
    if (p.dy - ballRadius > _worldHeight) {
      _lives--;
      _launched = false;
      _ball = Offset(_paddleX, _paddleTop - ballRadius - 1);
    }
  }

  void _restart() {
    setState(() {
      _resetGame();
      _leftHeld = false;
      _rightHeld = false;
    });
    _keyboardFocus.requestFocus();
  }

  /// Desktop testing shortcuts. Phones have no keyboard, so on an iPhone the
  /// on-screen buttons remain the only controls.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is! KeyUpEvent;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      setState(() => _leftHeld = down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      setState(() => _rightHeld = down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      if (event is KeyDownEvent) _gameOver ? _restart() : _launch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Center(
            // On a computer, show the game in a phone-sized frame so it
            // looks the same as it will on an iPhone.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430, maxHeight: 932),
              child: Column(
                children: [
                  _buildHud(),
                  Expanded(child: _buildField()),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Lives ', style: TextStyle(fontSize: 18)),
          for (var i = 0; i < startingLives; i++)
            Icon(
              i < _lives ? Icons.favorite : Icons.favorite_border,
              color: Colors.redAccent,
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                'Level $_level   Score $_score',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _worldHeight =
            constraints.maxHeight * worldWidth / constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _launch(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                ),
                child: CustomPaint(
                  painter: _GamePainter(
                    bricks: _bricks,
                    paddle: _paddleRect,
                    ball: _ball,
                  ),
                ),
              ),
              if (!_launched && !_gameOver)
                const IgnorePointer(
                  child: Center(
                    child: Text(
                      'Tap to launch',
                      style: TextStyle(fontSize: 22, color: Colors.white70),
                    ),
                  ),
                ),
              if (_gameOver) _buildGameOver(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameOver() {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Score: $_score', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: const Text('Restart'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _HoldButton(
              icon: Icons.arrow_back_rounded,
              pressed: _leftHeld,
              onChanged: (down) => setState(() => _leftHeld = down),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _HoldButton(
              icon: Icons.arrow_forward_rounded,
              pressed: _rightHeld,
              onChanged: (down) => setState(() => _rightHeld = down),
            ),
          ),
        ],
      ),
    );
  }
}

/// A button that reports press-and-hold state. Uses raw pointer events so it
/// responds instantly and both buttons can be held with two fingers.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.icon,
    required this.pressed,
    required this.onChanged,
  });

  final IconData icon;
  final bool pressed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: 84,
        decoration: BoxDecoration(
          color: pressed ? Colors.cyan.shade700 : const Color(0xFF263238),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.cyan.shade300, width: 2),
        ),
        child: Icon(icon, size: 48, color: Colors.white),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.bricks,
    required this.paddle,
    required this.ball,
  });

  final List<Brick> bricks;
  final Rect paddle;
  final Offset ball;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = size.width / worldWidth;
    canvas.scale(scale);

    final brickPaint = Paint();
    for (final brick in bricks) {
      if (!brick.alive) continue;
      brickPaint.color = brick.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(brick.rect, const Radius.circular(3)),
        brickPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(paddle, const Radius.circular(6)),
      Paint()..color = Colors.cyanAccent,
    );
    canvas.drawCircle(ball, ballRadius, Paint()..color = Colors.white);

    canvas.restore();
  }

  // Game state is mutated in place every frame, so always repaint.
  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
