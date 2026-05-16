const { createCanvas } = require('C:\\Users\\DaneceChou\\AppData\\Local\\Temp\\node_modules\\canvas');
const fs   = require('fs');
const path = require('path');

const SIZE  = 1024;
const CX    = SIZE / 2;
const TEAL  = '#00695C';
const TEAL2 = 'rgba(0,105,92,0.30)'; // page lines
const WHITE = '#FFFFFF';

// ── Layout constants ──────────────────────────────────────────────────────────
const PAGE_W  = 258;  // each page width
const PAGE_H  = 318;  // page height
const SPINE   = 20;   // gap between pages (spine)
const BOOK_Y  = 188;  // top of book
const CORNER  = 20;

const LEFT_X  = CX - PAGE_W - SPINE / 2;
const RIGHT_X = CX + SPINE / 2;

// ── Helpers ───────────────────────────────────────────────────────────────────
function roundRect(ctx, x, y, w, h, tl, tr, br, bl) {
  ctx.beginPath();
  ctx.moveTo(x + tl, y);
  ctx.lineTo(x + w - tr, y);
  ctx.arcTo(x + w, y,     x + w, y + tr,  tr);
  ctx.lineTo(x + w, y + h - br);
  ctx.arcTo(x + w, y + h, x + w - br, y + h, br);
  ctx.lineTo(x + bl, y + h);
  ctx.arcTo(x,  y + h, x, y + h - bl, bl);
  ctx.lineTo(x, y + tl);
  ctx.arcTo(x,  y,     x + tl, y,    tl);
  ctx.closePath();
}

function drawIcon(canvas, bg) {
  const ctx = canvas.getContext('2d');
  if (bg) { ctx.fillStyle = TEAL; ctx.fillRect(0, 0, SIZE, SIZE); }
  else     { ctx.clearRect(0, 0, SIZE, SIZE); }

  // ── Left page ───────────────────────────────────────────────────────────────
  ctx.fillStyle = WHITE;
  roundRect(ctx, LEFT_X, BOOK_Y, PAGE_W, PAGE_H, CORNER, 0, 0, CORNER);
  ctx.fill();

  // ── Right page ──────────────────────────────────────────────────────────────
  roundRect(ctx, RIGHT_X, BOOK_Y, PAGE_W, PAGE_H, 0, CORNER, CORNER, 0);
  ctx.fill();

  // ── Spine ───────────────────────────────────────────────────────────────────
  ctx.fillStyle = TEAL;
  ctx.fillRect(CX - SPINE / 2, BOOK_Y, SPINE, PAGE_H);

  // ── Ruled lines on left page ─────────────────────────────────────────────────
  ctx.strokeStyle = TEAL2;
  ctx.lineWidth = 7;
  ctx.lineCap = 'round';
  const margin  = 26;
  const lineTop = BOOK_Y + 54;
  const lineGap = 50;
  for (let i = 0; i < 5; i++) {
    const ly = lineTop + i * lineGap;
    ctx.beginPath();
    ctx.moveTo(LEFT_X + margin, ly);
    ctx.lineTo(LEFT_X + PAGE_W - margin, ly);
    ctx.stroke();
  }

  // ── Map pin on right page (the "mark" function) ──────────────────────────────
  const pinX = RIGHT_X + PAGE_W * 0.52;
  const pinY = BOOK_Y + PAGE_H * 0.36;
  const pinR = 52;

  // Teardrop body (circle + pointed bottom)
  ctx.save();
  ctx.beginPath();
  ctx.arc(pinX, pinY, pinR, 0, Math.PI * 2);
  // Pointed tail
  ctx.moveTo(pinX - 24, pinY + pinR - 8);
  ctx.quadraticCurveTo(pinX, pinY + pinR + 68, pinX, pinY + pinR + 68);
  ctx.quadraticCurveTo(pinX, pinY + pinR + 68, pinX + 24, pinY + pinR - 8);
  ctx.fillStyle = TEAL;
  ctx.fill();
  ctx.restore();

  // Draw teardrop properly
  ctx.beginPath();
  ctx.arc(pinX, pinY, pinR, (Math.PI * 3) / 4, Math.PI / 4, true);
  ctx.quadraticCurveTo(pinX + pinR * 0.6, pinY + pinR * 1.2, pinX, pinY + pinR + 65);
  ctx.quadraticCurveTo(pinX - pinR * 0.6, pinY + pinR * 1.2, pinX - pinR * Math.sin(Math.PI / 4), pinY + pinR * Math.cos(Math.PI / 4));
  ctx.arc(pinX, pinY, pinR, (Math.PI * 5) / 4, (Math.PI * 3) / 4, true);
  ctx.closePath();
  ctx.fillStyle = TEAL;
  ctx.fill();

  // Inner white dot
  ctx.beginPath();
  ctx.arc(pinX, pinY, 22, 0, Math.PI * 2);
  ctx.fillStyle = WHITE;
  ctx.fill();

  // Pencil on right page (bottom area — writing tool)
  const penX1 = RIGHT_X + 38, penY1 = BOOK_Y + PAGE_H - 70;
  const penX2 = RIGHT_X + 158, penY2 = BOOK_Y + PAGE_H - 70;
  ctx.strokeStyle = TEAL2;
  ctx.lineWidth = 7;
  ctx.beginPath();
  ctx.moveTo(penX1, penY1);
  ctx.lineTo(penX2, penY2);
  ctx.stroke();

  // ── Text "生活隨筆" ──────────────────────────────────────────────────────────
  const textY = BOOK_Y + PAGE_H + 110;
  ctx.fillStyle = WHITE;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  // Try to render Chinese text; fall back gracefully
  ctx.font = `bold 148px "Microsoft YaHei", "SimHei", "PingFang SC", sans-serif`;
  ctx.fillText('生活隨筆', CX, textY);
}

const iconDir = path.join(__dirname, 'assets', 'icon');
if (!fs.existsSync(iconDir)) fs.mkdirSync(iconDir, { recursive: true });

const full = createCanvas(SIZE, SIZE);
drawIcon(full, true);
fs.writeFileSync(path.join(iconDir, 'app_icon.png'), full.toBuffer('image/png'));
console.log('✓ app_icon.png');

const fg = createCanvas(SIZE, SIZE);
drawIcon(fg, false);
fs.writeFileSync(path.join(iconDir, 'app_icon_foreground.png'), fg.toBuffer('image/png'));
console.log('✓ app_icon_foreground.png');
