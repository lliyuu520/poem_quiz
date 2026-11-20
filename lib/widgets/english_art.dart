import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 英语条目的插画。
///
/// 全部用 [CustomPainter] 画，不打位图：一是 40 张图的位图会让 APK 涨几 MB，
/// 二是自绘的图形跟随 [AppColors]，换科目印色时整屏统一，不会出现
/// 「插画是饱和的卡通色、界面是宣纸墨色」的割裂感。
///
/// 画法统一为「淡彩底 + 墨线勾形」：底色取科目印色的淡版，轮廓取墨色。
/// 尺寸由调用方给定，内部按 100×100 的逻辑坐标绘制后等比缩放。
class EnglishArt extends StatelessWidget {
  const EnglishArt({
    super.key,
    required this.name,
    this.size = 96,
    this.color,
  });

  /// 插画键名，与题库里的 `word` 一致（如 `cat`）。
  /// 找不到对应画法时退化成首字母印章，不会崩。
  final String name;
  final double size;

  /// 主色，默认取科目印色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.english;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArtPainter(name: name, color: c),
        isComplex: false,
      ),
    );
  }
}

/// 有没有这张插画。出题时用它筛掉没有配图的词，避免出现空白卡。
bool hasEnglishArt(String name) => _ArtPainter.painters.containsKey(name);

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.name, required this.color});

  final String name;
  final Color color;

  /// 画法表：键是题库里的单词。
  ///
  /// 每个画法都只画「能一眼认出」的特征，不做写实。低龄儿童的认图能力
  /// 依赖轮廓鲜明、部位夸张，写实反而更难辨认。
  static final Map<String, void Function(Canvas, Paint, Paint, Color)> painters =
      <String, void Function(Canvas, Paint, Paint, Color)>{
    'cat': _cat,
    'dog': _dog,
    'pig': _pig,
    'cow': _cow,
    'duck': _duck,
    'bird': _bird,
    'fish': _fish,
    'bee': _bee,
    'apple': _apple,
    'banana': _banana,
    'cake': _cake,
    'egg': _egg,
    'milk': _milk,
    'bread': _bread,
    'rice': _rice,
    'water': _water,
    'red': _red,
    'blue': _blue,
    'green': _green,
    'yellow': _yellow,
    'black': _black,
    'white': _white,
    'mom': _mom,
    'dad': _dad,
    'baby': _baby,
    'family': _family,
    'eye': _eye,
    'ear': _ear,
    'hand': _hand,
    'nose': _nose,
    'sun': _sun,
    'moon': _moon,
    'star': _star,
    'tree': _tree,
    'flower': _flower,
    'rain': _rain,
    'ball': _ball,
    'book': _book,
    'car': _car,
    'bus': _bus,
    'cup': _cup,
    'hat': _hat,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.16);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final painter = painters[name];
    if (painter == null) {
      _fallback(canvas, fill, stroke);
    } else {
      painter(canvas, fill, stroke, color);
    }
    canvas.restore();
  }

  /// 没有画法时画一个印章式圆牌 + 首字母，保持视觉一致。
  void _fallback(Canvas canvas, Paint fill, Paint stroke) {
    canvas.drawCircle(const Offset(50, 50), 34, fill);
    canvas.drawCircle(const Offset(50, 50), 34, stroke);
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.name != name || old.color != color;
}

// ── 动物 ──────────────────────────────────────────────

void _cat(Canvas c, Paint f, Paint s, Color col) {
  // 头 + 两只尖耳 + 胡须
  c.drawCircle(const Offset(50, 55), 26, f);
  c.drawCircle(const Offset(50, 55), 26, s);
  final ear = Path()
    ..moveTo(30, 38)..lineTo(26, 16)..lineTo(45, 30)..close();
  final ear2 = Path()
    ..moveTo(70, 38)..lineTo(74, 16)..lineTo(55, 30)..close();
  c.drawPath(ear, f);
  c.drawPath(ear, s);
  c.drawPath(ear2, f);
  c.drawPath(ear2, s);
  c.drawCircle(const Offset(41, 52), 3.4, s);
  c.drawCircle(const Offset(59, 52), 3.4, s);
  c.drawLine(const Offset(47, 62), const Offset(53, 62), s);
  for (final dy in <double>[-2, 3]) {
    c.drawLine(Offset(24, 60 + dy), Offset(38, 62 + dy), s);
    c.drawLine(Offset(76, 60 + dy), Offset(62, 62 + dy), s);
  }
}

void _dog(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 54), 25, f);
  c.drawCircle(const Offset(50, 54), 25, s);
  // 垂耳
  c.drawOval(Rect.fromCenter(center: const Offset(24, 52), width: 18, height: 34), f);
  c.drawOval(Rect.fromCenter(center: const Offset(24, 52), width: 18, height: 34), s);
  c.drawOval(Rect.fromCenter(center: const Offset(76, 52), width: 18, height: 34), f);
  c.drawOval(Rect.fromCenter(center: const Offset(76, 52), width: 18, height: 34), s);
  c.drawCircle(const Offset(42, 50), 3.4, s);
  c.drawCircle(const Offset(58, 50), 3.4, s);
  c.drawCircle(const Offset(50, 64), 6, s);
}

void _pig(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 54), 25, f);
  c.drawCircle(const Offset(50, 54), 25, s);
  // 三角耳
  c.drawPath(Path()..moveTo(32, 36)..lineTo(28, 18)..lineTo(46, 30)..close(), s);
  c.drawPath(Path()..moveTo(68, 36)..lineTo(72, 18)..lineTo(54, 30)..close(), s);
  c.drawCircle(const Offset(41, 48), 3.2, s);
  c.drawCircle(const Offset(59, 48), 3.2, s);
  // 鼻盘
  c.drawOval(Rect.fromCenter(center: const Offset(50, 64), width: 24, height: 17), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 64), width: 24, height: 17), s);
  c.drawCircle(const Offset(46, 64), 2.2, s);
  c.drawCircle(const Offset(54, 64), 2.2, s);
}

void _cow(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 54), 25, f);
  c.drawCircle(const Offset(50, 54), 25, s);
  // 角
  c.drawPath(Path()..moveTo(34, 34)..quadraticBezierTo(24, 20, 34, 16), s);
  c.drawPath(Path()..moveTo(66, 34)..quadraticBezierTo(76, 20, 66, 16), s);
  c.drawCircle(const Offset(40, 48), 3.2, s);
  c.drawCircle(const Offset(60, 48), 3.2, s);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 66), width: 26, height: 18), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 66), width: 26, height: 18), s);
}

void _duck(Canvas c, Paint f, Paint s, Color col) {
  // 身体 + 头 + 扁嘴
  c.drawOval(Rect.fromCenter(center: const Offset(48, 62), width: 52, height: 34), f);
  c.drawOval(Rect.fromCenter(center: const Offset(48, 62), width: 52, height: 34), s);
  c.drawCircle(const Offset(66, 36), 16, f);
  c.drawCircle(const Offset(66, 36), 16, s);
  c.drawCircle(const Offset(70, 32), 2.8, s);
  final beak = Path()
    ..moveTo(80, 38)..lineTo(94, 41)..lineTo(80, 45)..close();
  c.drawPath(beak, f);
  c.drawPath(beak, s);
}

void _bird(Canvas c, Paint f, Paint s, Color col) {
  c.drawOval(Rect.fromCenter(center: const Offset(50, 58), width: 40, height: 32), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 58), width: 40, height: 32), s);
  c.drawCircle(const Offset(64, 36), 13, f);
  c.drawCircle(const Offset(64, 36), 13, s);
  c.drawCircle(const Offset(68, 33), 2.6, s);
  final beak = Path()..moveTo(76, 36)..lineTo(88, 39)..lineTo(76, 42)..close();
  c.drawPath(beak, f);
  c.drawPath(beak, s);
  // 翅膀
  c.drawPath(Path()..moveTo(40, 52)..quadraticBezierTo(28, 60, 40, 68), s);
}

void _fish(Canvas c, Paint f, Paint s, Color col) {
  c.drawOval(Rect.fromCenter(center: const Offset(50, 52), width: 56, height: 34), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 52), width: 56, height: 34), s);
  // 尾
  final tail = Path()..moveTo(78, 52)..lineTo(94, 38)..lineTo(94, 66)..close();
  c.drawPath(tail, f);
  c.drawPath(tail, s);
  c.drawCircle(const Offset(34, 47), 3.2, s);
  c.drawPath(Path()..moveTo(46, 52)..quadraticBezierTo(56, 46, 62, 52), s);
}

void _bee(Canvas c, Paint f, Paint s, Color col) {
  c.drawOval(Rect.fromCenter(center: const Offset(50, 56), width: 38, height: 30), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 56), width: 38, height: 30), s);
  // 条纹
  for (final x in <double>[42, 54]) {
    c.drawLine(Offset(x, 42), Offset(x, 70), s);
  }
  // 翅膀
  c.drawOval(Rect.fromCenter(center: const Offset(40, 34), width: 22, height: 14), f);
  c.drawOval(Rect.fromCenter(center: const Offset(40, 34), width: 22, height: 14), s);
  c.drawOval(Rect.fromCenter(center: const Offset(60, 34), width: 22, height: 14), f);
  c.drawOval(Rect.fromCenter(center: const Offset(60, 34), width: 22, height: 14), s);
  // 触角
  c.drawPath(Path()..moveTo(44, 42)..quadraticBezierTo(38, 28, 32, 26), s);
  c.drawPath(Path()..moveTo(56, 42)..quadraticBezierTo(62, 28, 68, 26), s);
}

// ── 食物 ──────────────────────────────────────────────

void _apple(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 58), 26, f);
  c.drawCircle(const Offset(50, 58), 26, s);
  c.drawPath(Path()..moveTo(50, 34)..quadraticBezierTo(50, 22, 56, 16), s);
  c.drawOval(Rect.fromCenter(center: const Offset(64, 22), width: 18, height: 10), f);
  c.drawOval(Rect.fromCenter(center: const Offset(64, 22), width: 18, height: 10), s);
}

void _banana(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(20, 34)
    ..quadraticBezierTo(34, 78, 80, 66)
    ..quadraticBezierTo(46, 66, 34, 30)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
}

void _cake(Canvas c, Paint f, Paint s, Color col) {
  c.drawRect(const Rect.fromLTWH(26, 46, 48, 34), f);
  c.drawRect(const Rect.fromLTWH(26, 46, 48, 34), s);
  // 奶油层
  c.drawPath(Path()..moveTo(26, 56)..quadraticBezierTo(50, 66, 74, 56), s);
  // 蜡烛
  c.drawLine(const Offset(50, 46), const Offset(50, 28), s);
  c.drawCircle(const Offset(50, 24), 4, s);
}

void _egg(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(50, 22)
    ..quadraticBezierTo(80, 40, 74, 64)
    ..quadraticBezierTo(66, 82, 50, 82)
    ..quadraticBezierTo(34, 82, 26, 64)
    ..quadraticBezierTo(20, 40, 50, 22)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
}

void _milk(Canvas c, Paint f, Paint s, Color col) {
  // 纸盒 + 斜顶
  final box = Path()
    ..moveTo(32, 34)..lineTo(68, 34)..lineTo(68, 80)..lineTo(32, 80)..close();
  c.drawPath(box, f);
  c.drawPath(box, s);
  final top = Path()..moveTo(32, 34)..lineTo(50, 20)..lineTo(68, 34);
  c.drawPath(top, s);
  c.drawRect(const Rect.fromLTWH(32, 56, 36, 12), f);
  c.drawRect(const Rect.fromLTWH(32, 56, 36, 12), s);
}

void _bread(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(26, 46)
    ..quadraticBezierTo(26, 26, 50, 26)
    ..quadraticBezierTo(74, 26, 74, 46)
    ..lineTo(74, 74)
    ..lineTo(26, 74)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
  for (final x in <double>[38, 50, 62]) {
    c.drawLine(Offset(x, 36), Offset(x, 46), s);
  }
}

void _rice(Canvas c, Paint f, Paint s, Color col) {
  // 碗 + 饭堆
  final bowl = Path()
    ..moveTo(24, 52)
    ..quadraticBezierTo(24, 78, 50, 78)
    ..quadraticBezierTo(76, 78, 76, 52)
    ..close();
  c.drawPath(bowl, f);
  c.drawPath(bowl, s);
  c.drawPath(Path()..moveTo(30, 52)..quadraticBezierTo(50, 34, 70, 52), f);
  c.drawPath(Path()..moveTo(30, 52)..quadraticBezierTo(50, 34, 70, 52), s);
}

void _water(Canvas c, Paint f, Paint s, Color col) {
  // 水滴
  final p = Path()
    ..moveTo(50, 20)
    ..quadraticBezierTo(76, 52, 72, 66)
    ..quadraticBezierTo(66, 84, 50, 84)
    ..quadraticBezierTo(34, 84, 28, 66)
    ..quadraticBezierTo(24, 52, 50, 20)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
}

// ── 颜色（色块 + 汉字提示，避免只靠颜色区分）────────────────

void _swatch(Canvas c, Paint f, Paint s, Color col, Color swatch) {
  final p = Paint()
    ..style = PaintingStyle.fill
    ..color = swatch;
  final r = RRect.fromRectAndRadius(
    const Rect.fromLTWH(20, 20, 60, 60),
    const Radius.circular(14),
  );
  c.drawRRect(r, p);
  c.drawRRect(r, s);
}

void _red(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFFC0392B));
void _blue(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFF2C5F9E));
void _green(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFF3F7A4E));
void _yellow(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFFD4A017));
void _black(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFF2B2B2B));
void _white(Canvas c, Paint f, Paint s, Color col) =>
    _swatch(c, f, s, col, const Color(0xFFFAF7F0));

// ── 家人 ──────────────────────────────────────────────

/// 一个人形：头 + 身体。发型与身高用来区分不同角色。
void _person(Canvas c, Paint f, Paint s, {required double headY, required bool longHair}) {
  c.drawCircle(Offset(50, headY), 15, f);
  c.drawCircle(Offset(50, headY), 15, s);
  if (longHair) {
    c.drawPath(
      Path()
        ..moveTo(35, headY - 6)
        ..quadraticBezierTo(34, headY + 20, 42, headY + 24)
        ..moveTo(65, headY - 6)
        ..quadraticBezierTo(66, headY + 20, 58, headY + 24),
      s,
    );
  }
  c.drawPath(
    Path()
      ..moveTo(50, headY + 15)
      ..lineTo(50, headY + 34)
      ..moveTo(34, headY + 24)
      ..lineTo(66, headY + 24)
      ..moveTo(50, headY + 34)
      ..lineTo(36, headY + 54)
      ..moveTo(50, headY + 34)
      ..lineTo(64, headY + 54),
    s,
  );
}

void _mom(Canvas c, Paint f, Paint s, Color col) =>
    _person(c, f, s, headY: 34, longHair: true);

void _dad(Canvas c, Paint f, Paint s, Color col) =>
    _person(c, f, s, headY: 32, longHair: false);

void _baby(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 52), 20, f);
  c.drawCircle(const Offset(50, 52), 20, s);
  c.drawCircle(const Offset(43, 50), 3, s);
  c.drawCircle(const Offset(57, 50), 3, s);
  c.drawPath(Path()..moveTo(44, 60)..quadraticBezierTo(50, 66, 56, 60), s);
}

void _family(Canvas c, Paint f, Paint s, Color col) {
  // 三个并排的人：高、中、小
  for (final e in <({double x, double y, double r})>[
    (x: 26, y: 40, r: 11),
    (x: 50, y: 34, r: 13),
    (x: 74, y: 48, r: 9),
  ]) {
    c.drawCircle(Offset(e.x, e.y), e.r, f);
    c.drawCircle(Offset(e.x, e.y), e.r, s);
    c.drawLine(Offset(e.x, e.y + e.r), Offset(e.x, e.y + e.r * 2.6), s);
    c.drawLine(Offset(e.x - e.r, e.y + e.r * 1.5), Offset(e.x + e.r, e.y + e.r * 1.5), s);
  }
}

// ── 身体 ──────────────────────────────────────────────

void _eye(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(18, 52)
    ..quadraticBezierTo(50, 24, 82, 52)
    ..quadraticBezierTo(50, 80, 18, 52)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
  c.drawCircle(const Offset(50, 52), 12, s);
  c.drawCircle(const Offset(50, 52), 4, s);
}

void _ear(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(38, 24)
    ..quadraticBezierTo(76, 30, 66, 62)
    ..quadraticBezierTo(60, 80, 44, 72)
    ..quadraticBezierTo(34, 64, 38, 24)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
  c.drawPath(
    Path()
      ..moveTo(48, 40)
      ..quadraticBezierTo(60, 46, 54, 62),
    s,
  );
}

void _hand(Canvas c, Paint f, Paint s, Color col) {
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(36, 48, 28, 32), const Radius.circular(10)),
    f,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(36, 48, 28, 32), const Radius.circular(10)),
    s,
  );
  for (var i = 0; i < 4; i++) {
    final x = 38.0 + i * 8;
    c.drawLine(Offset(x, 48), Offset(x, 24 + (i == 1 || i == 2 ? 0 : 6)), s);
  }
  c.drawPath(
    Path()..moveTo(36, 60)..quadraticBezierTo(22, 56, 24, 44),
    s,
  );
}

void _nose(Canvas c, Paint f, Paint s, Color col) {
  c.drawPath(
    Path()
      ..moveTo(50, 22)
      ..lineTo(50, 56)
      ..quadraticBezierTo(50, 68, 62, 68)
      ..quadraticBezierTo(72, 68, 70, 58),
    s,
  );
  c.drawCircle(const Offset(40, 62), 5, s);
  c.drawCircle(const Offset(60, 62), 5, s);
}

// ── 自然 ──────────────────────────────────────────────

void _sun(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 50), 20, f);
  c.drawCircle(const Offset(50, 50), 20, s);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    c.drawLine(
      Offset(50 + 28 * math.cos(a), 50 + 28 * math.sin(a)),
      Offset(50 + 38 * math.cos(a), 50 + 38 * math.sin(a)),
      s,
    );
  }
}

void _moon(Canvas c, Paint f, Paint s, Color col) {
  final outer = Path()
    ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 28));
  final inner = Path()
    ..addOval(Rect.fromCircle(center: const Offset(62, 42), radius: 24));
  final crescent = Path.combine(PathOperation.difference, outer, inner);
  c.drawPath(crescent, f);
  c.drawPath(crescent, s);
}

void _star(Canvas c, Paint f, Paint s, Color col) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? 32.0 : 13.0;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(50 + r * math.cos(a), 50 + r * math.sin(a));
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  c.drawPath(p, f);
  c.drawPath(p, s);
}

void _tree(Canvas c, Paint f, Paint s, Color col) {
  c.drawRect(const Rect.fromLTWH(46, 58, 8, 26), f);
  c.drawRect(const Rect.fromLTWH(46, 58, 8, 26), s);
  c.drawCircle(const Offset(50, 40), 24, f);
  c.drawCircle(const Offset(50, 40), 24, s);
}

void _flower(Canvas c, Paint f, Paint s, Color col) {
  c.drawLine(const Offset(50, 56), const Offset(50, 84), s);
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final cx = 50 + 15 * math.cos(a);
    final cy = 42 + 15 * math.sin(a);
    c.drawCircle(Offset(cx, cy), 11, f);
    c.drawCircle(Offset(cx, cy), 11, s);
  }
  c.drawCircle(const Offset(50, 42), 9, s);
}

void _rain(Canvas c, Paint f, Paint s, Color col) {
  // 云
  c.drawOval(Rect.fromCenter(center: const Offset(38, 36), width: 34, height: 26), f);
  c.drawOval(Rect.fromCenter(center: const Offset(38, 36), width: 34, height: 26), s);
  c.drawOval(Rect.fromCenter(center: const Offset(60, 34), width: 38, height: 30), f);
  c.drawOval(Rect.fromCenter(center: const Offset(60, 34), width: 38, height: 30), s);
  // 雨点
  for (final e in <({double x, double y})>[
    (x: 32, y: 58), (x: 50, y: 64), (x: 68, y: 58),
    (x: 40, y: 74), (x: 60, y: 78),
  ]) {
    c.drawLine(Offset(e.x, e.y), Offset(e.x - 4, e.y + 12), s);
  }
}

// ── 物品 ──────────────────────────────────────────────

void _ball(Canvas c, Paint f, Paint s, Color col) {
  c.drawCircle(const Offset(50, 50), 28, f);
  c.drawCircle(const Offset(50, 50), 28, s);
  c.drawPath(
    Path()
      ..moveTo(24, 42)
      ..quadraticBezierTo(50, 56, 76, 42),
    s,
  );
  c.drawPath(
    Path()
      ..moveTo(24, 58)
      ..quadraticBezierTo(50, 44, 76, 58),
    s,
  );
}

void _book(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(24, 26)
    ..lineTo(76, 26)
    ..lineTo(76, 76)
    ..lineTo(24, 76)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
  c.drawLine(const Offset(38, 26), const Offset(38, 76), s);
  for (final y in <double>[40, 52, 64]) {
    c.drawLine(Offset(46, y), Offset(68, y), s);
  }
}

void _car(Canvas c, Paint f, Paint s, Color col) {
  // 车身 + 车顶
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(16, 48, 68, 24), const Radius.circular(7)),
    f,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(16, 48, 68, 24), const Radius.circular(7)),
    s,
  );
  c.drawPath(
    Path()
      ..moveTo(32, 48)
      ..lineTo(42, 30)
      ..lineTo(64, 30)
      ..lineTo(74, 48),
    f,
  );
  c.drawPath(
    Path()
      ..moveTo(32, 48)
      ..lineTo(42, 30)
      ..lineTo(64, 30)
      ..lineTo(74, 48),
    s,
  );
  c.drawCircle(const Offset(34, 72), 8, s);
  c.drawCircle(const Offset(66, 72), 8, s);
}

void _bus(Canvas c, Paint f, Paint s, Color col) {
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(14, 30, 72, 40), const Radius.circular(8)),
    f,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(14, 30, 72, 40), const Radius.circular(8)),
    s,
  );
  for (final x in <double>[26, 44, 62]) {
    c.drawRect(Rect.fromLTWH(x, 38, 14, 12), s);
  }
  c.drawCircle(const Offset(30, 74), 7, s);
  c.drawCircle(const Offset(70, 74), 7, s);
}

void _cup(Canvas c, Paint f, Paint s, Color col) {
  final p = Path()
    ..moveTo(30, 32)
    ..lineTo(70, 32)
    ..lineTo(64, 80)
    ..lineTo(36, 80)
    ..close();
  c.drawPath(p, f);
  c.drawPath(p, s);
  c.drawPath(
    Path()..moveTo(70, 42)..quadraticBezierTo(86, 46, 70, 62),
    s,
  );
}

void _hat(Canvas c, Paint f, Paint s, Color col) {
  // 帽檐 + 帽身
  c.drawOval(Rect.fromCenter(center: const Offset(50, 68), width: 68, height: 16), f);
  c.drawOval(Rect.fromCenter(center: const Offset(50, 68), width: 68, height: 16), s);
  c.drawPath(
    Path()
      ..moveTo(32, 68)
      ..quadraticBezierTo(34, 30, 50, 30)
      ..quadraticBezierTo(66, 30, 68, 68),
    f,
  );
  c.drawPath(
    Path()
      ..moveTo(32, 68)
      ..quadraticBezierTo(34, 30, 50, 30)
      ..quadraticBezierTo(66, 30, 68, 68),
    s,
  );
}
