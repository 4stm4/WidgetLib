program HUDCyberpunk;

{$mode objfpc}{$H+}

{ ═══════════════════════════════════════════════════════════════
  Cyberpunk Neon HUD v2 — bottom-center of 1360×720.
  Q / Esc : quit
  ═══════════════════════════════════════════════════════════════ }

uses
  SysUtils, Math,
  SDL2, SDL2_ttf,
  Core.Contracts,
  SDL2Renderer,
  SDL2FontLoader,
  SDL2ImageLoader,
  ResourceManager;

// ─────────────────────────────────────────────────────────────
//  Window & layout constants
// ─────────────────────────────────────────────────────────────
const
  WIN_W = 1360;
  WIN_H = 720;

  // ── Panel — scaled ×0.72 vs original, bottom-center ─────────
  // Original: 1256×306 at (52,394).  New: 900×220, centered, near bottom.
  PNL_X = 230;   // (1360-900)/2
  PNL_Y = 465;   // 720-220-35
  PNL_W = 900;
  PNL_H = 220;

  // ── Ring positions (all offsets = original × 0.718) ──────────
  // Health circle
  H_CX  = PNL_X + 119;   // was PNL_X+165  (165×0.718)
  H_CY  = PNL_Y + 102;   // was PNL_Y+142  (142×0.718)
  H_R   = 92;             // was 128        (128×0.718)
  H_T   = 13;             // was 18

  // Ammo circle
  A_CX  = PNL_X + 462;   // was PNL_X+644  (644×0.718)
  A_CY  = PNL_Y + 111;   // was PNL_Y+155  (155×0.718)
  A_R   = 100;            // was 140        (140×0.718)
  A_T   = 12;             // was 16

  // Weapon panel — sprite 391×273, scaled to WPN_H maintaining aspect ratio
  // WPN_H=203 → WPN_W = Round(391×203/273) = 291
  WPN_H = PNL_H - 17;          // = 203
  WPN_W = 291;                  // 391:273 aspect at WPN_H
  WPN_Y = PNL_Y + 9;
  WPN_X = PNL_X + PNL_W - WPN_W - 15;  // = 809, right-aligned

  // Center content area
  CTR_X = H_CX + H_R + 16;     // = PNL_X+227 = 457
  CTR_R = A_CX - A_R - 13;     // = PNL_X+349 = 579

  // Angular corner cut size
  ANG = 19;   // was 26 (26×0.718)

  // ── Colors ────────────────────────────────────────────────
  C_BG     = $060611;
  C_PANEL  = $080016;
  C_INNER  = $030009;
  C_DARK2  = $04000E;

  C_PINK   = $FF00CC;
  C_PINK2  = $CC0099;
  C_PINK3  = $660050;

  C_CYAN   = $00EEFF;
  C_CYAN2  = $0099BB;
  C_CYAN3  = $004455;

  C_WHITE  = $FFFFFF;
  C_LGRAY  = $AABBCC;
  C_GRAY   = $445566;
  C_DGRAY  = $1A2233;

  C_RADFG  = $003322;
  C_RADBG  = $020C0C;

// ─────────────────────────────────────────────────────────────
//  Sprite images (loaded at startup, used in draw procedures)
// ─────────────────────────────────────────────────────────────
var
  imgPanelBg:        IImage = nil;
  imgSlotHex:        IImage = nil;  // slot_hex_1.png  (inactive)
  imgSlotHexActive:  IImage = nil;  // slot_hex_active.png
  imgWeaponPanel:    IImage = nil;
  imgObjectivePanel: IImage = nil;
  imgCornerBrackets: IImage = nil;

// ─────────────────────────────────────────────────────────────
//  Small helpers
// ─────────────────────────────────────────────────────────────
function R(x,y,w,h: Integer): TRect;
begin Result.x:=x; Result.y:=y; Result.w:=w; Result.h:=h; end;

// Pack alpha into a color: A = top byte
function A(col: LongWord; alpha: Byte): LongWord;
begin Result := (LongWord(alpha) shl 24) or (col and $00FFFFFF); end;

// ─────────────────────────────────────────────────────────────
//  Glowing line — multiple additive offset passes
// ─────────────────────────────────────────────────────────────
procedure GlowLine(ren: IRenderer; x1,y1,x2,y2: Integer;
                   col: LongWord; passes: Integer = 5);
var i: Integer; ga: Byte;
begin
  ren.PushBlendAdd;
  for i := passes downto 1 do
  begin
    ga := Trunc(100.0 * i / passes);
    ren.DrawLine(x1-i, y1,   x2-i, y2,   A(col, ga));
    ren.DrawLine(x1+i, y1,   x2+i, y2,   A(col, ga));
    ren.DrawLine(x1,   y1-i, x2,   y2-i, A(col, ga));
    ren.DrawLine(x1,   y1+i, x2,   y2+i, A(col, ga));
  end;
  ren.PopBlend;
  ren.DrawLine(x1, y1, x2, y2, col);
end;

// ─────────────────────────────────────────────────────────────
//  Glowing arc — additive glow ring before the solid arc
// ─────────────────────────────────────────────────────────────
procedure GlowArc(ren: IRenderer; cx,cy,rad,a1,a2,thk: Integer;
                  col: LongWord; passes: Integer = 6);
var i: Integer; ga: Byte;
begin
  ren.PushBlendAdd;
  for i := passes downto 1 do
  begin
    ga := Trunc(90.0 * i / passes);
    ren.DrawArc(cx, cy, rad,       a1, a2, A(col, ga), thk + i*5);
    ren.DrawArc(cx, cy, rad + thk, a1, a2, A(col, ga div 3), i*3);
  end;
  ren.PopBlend;
end;

// ─────────────────────────────────────────────────────────────
//  Dotted arc — series of small bright circles along the arc
//  Creates the "LED dot" look of the reference image
// ─────────────────────────────────────────────────────────────
procedure DrawDottedArc(ren: IRenderer; cx,cy,rad,a1,a2,dotR: Integer;
                        col: LongWord; spacingPx: Single = 5.0);
var angle, step, range: Single;
    dx, dy: Integer;
    ga: Byte;
begin
  if rad <= 0 then Exit;
  step  := spacingPx / rad * (180.0 / Pi);   // deg per dot
  range := a2 - a1;
  if range <= 0 then Exit;

  // Additive glow pass (larger dots, lower alpha)
  ren.PushBlendAdd;
  angle := a1;
  while angle <= a2 do
  begin
    ga := Byte(Trunc(55.0 * (1.0 - Abs(angle - (a1+range/2)) / (range/2))));
    dx := cx + Round(rad * Cos(angle * Pi / 180));
    dy := cy + Round(rad * Sin(angle * Pi / 180));
    ren.DrawFilledCircle(dx, dy, dotR + 3, A(col, Max(20, ga)));
    angle := angle + step;
  end;
  ren.PopBlend;

  // Solid dot pass
  angle := a1;
  while angle <= a2 do
  begin
    dx := cx + Round(rad * Cos(angle * Pi / 180));
    dy := cy + Round(rad * Sin(angle * Pi / 180));
    ren.DrawFilledCircle(dx, dy, dotR, col);
    angle := angle + step;
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Hex outline (flat-top)
// ─────────────────────────────────────────────────────────────
procedure HexOutline(ren: IRenderer; cx,cy,rad: Integer;
                     col: LongWord; thick: Integer = 1);
const D2R = Pi / 180.0;
var i,t: Integer; x1,y1,x2,y2: Integer; a: Single;
begin
  for t := 0 to thick-1 do
  for i := 0 to 5 do
  begin
    a  := (i*60 + 30) * D2R;
    x1 := cx + Round((rad-t) * Cos(a));
    y1 := cy + Round((rad-t) * Sin(a));
    a  := ((i+1)*60 + 30) * D2R;
    x2 := cx + Round((rad-t) * Cos(a));
    y2 := cy + Round((rad-t) * Sin(a));
    ren.DrawLine(x1, y1, x2, y2, col);
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Hex fill (by horizontal spans)
// ─────────────────────────────────────────────────────────────
procedure HexFill(ren: IRenderer; cx,cy,rad: Integer; col: LongWord);
var y, x1, x2, row: Integer; a1: Single;
begin
  for y := cy-rad to cy+rad do
  begin
    row := y - cy;
    if Abs(row) > rad then Continue;
    a1 := ArcCos(Abs(row) / Max(rad, 1));
    if rad * Sin(a1) < 1 then Continue;
    x1 := cx - Round(rad * Sin(a1));
    x2 := cx + Round(rad * Sin(a1));
    if Abs(row) > rad div 2 then
    begin
      x1 := cx - Round((rad - Abs(row)) * 2);
      x2 := cx + Round((rad - Abs(row)) * 2);
    end;
    if x2 > x1 then
      ren.DrawFilledRect(R(x1, y, x2-x1, 1), col);
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Glowing hex border
// ─────────────────────────────────────────────────────────────
procedure GlowHex(ren: IRenderer; cx,cy,rad: Integer;
                  col: LongWord; passes: Integer = 5);
var i: Integer; ga: Byte;
begin
  ren.PushBlendAdd;
  for i := passes downto 1 do
  begin
    ga := Trunc(80.0 * i / passes);
    HexOutline(ren, cx, cy, rad + i*2, A(col, ga), 2);
  end;
  ren.PopBlend;
end;

// ─────────────────────────────────────────────────────────────
//  Radar interior — dark teal sphere with sweep and blips
// ─────────────────────────────────────────────────────────────
procedure DrawRadar(ren: IRenderer; cx,cy,rr: Integer; tick: Single);
var i, tri, dot: Integer; ang, sweep: Single; ex,ey: Integer;
begin
  // Background
  ren.DrawFilledCircle(cx, cy, rr, C_RADBG);
  ren.DrawCircle(cx, cy, rr,     $0A2020);
  ren.DrawCircle(cx, cy, rr-1,   $062020);

  // Concentric rings
  ren.DrawCircle(cx, cy, rr*3 div 4, $003322);
  ren.DrawCircle(cx, cy, rr   div 2, $003322);
  ren.DrawCircle(cx, cy, rr   div 4, $004433);

  // Cross lines
  ren.DrawLine(cx-rr, cy,    cx+rr, cy,    $003322);
  ren.DrawLine(cx,    cy-rr, cx,    cy+rr, $003322);

  // Diagonal faint lines
  ren.DrawLine(cx - rr*7 div 10, cy - rr*7 div 10,
               cx + rr*7 div 10, cy + rr*7 div 10, $001A11);
  ren.DrawLine(cx + rr*7 div 10, cy - rr*7 div 10,
               cx - rr*7 div 10, cy + rr*7 div 10, $001A11);

  // Sweep trail (additive cyan)
  sweep := tick * 1.3;
  ren.PushBlendAdd;
  for i := 0 to 24 do
  begin
    ang := sweep - i * 0.045;
    ex  := cx + Round(rr * Cos(ang));
    ey  := cy + Round(rr * Sin(ang));
    ren.DrawLine(cx, cy, ex, ey,
                 A(C_CYAN, Byte(Max(0, 40 - i * 2))));
  end;
  ren.PopBlend;

  // Main sweep line (bright)
  ex := cx + Round(rr * Cos(sweep));
  ey := cy + Round(rr * Sin(sweep));
  ren.PushBlendAdd;
  ren.DrawLine(cx, cy, ex, ey, A(C_CYAN, 120));
  ren.DrawLine(cx, cy, cx + Round((rr+3)*Cos(sweep)),
                       cy + Round((rr+3)*Sin(sweep)), A(C_CYAN, 60));
  ren.PopBlend;
  ren.DrawLine(cx, cy, ex, ey, A(C_CYAN, 200));

  // Sizes scale with rr so they look right at any radar size
  tri := Max(3, rr * 13 div 100);  // triangle half-size  (≈8px when rr=63)
  dot := Max(1, rr *  5 div 100);  // blip radius          (≈3px when rr=63)

  // Enemy blips (red-orange)
  ren.PushBlendAdd;
  ren.DrawFilledCircle(cx - rr*3 div 10, cy - rr*3 div 10, dot+1, $FF3300);
  ren.DrawFilledCircle(cx + rr*4 div 10, cy - rr*5 div 10, dot+1, $FF2200);
  ren.DrawFilledCircle(cx + rr*6 div 10, cy + rr*2 div 10, dot,   $FF1100);
  ren.DrawFilledCircle(cx - rr   div 8,  cy + rr*5 div 10, dot,   $DD1100);
  ren.PopBlend;

  // Player triangle (pointing up)
  ren.DrawLine(cx,        cy-tri,   cx-tri*2 div 3, cy+tri*2 div 3, A(C_CYAN, 220));
  ren.DrawLine(cx,        cy-tri,   cx+tri*2 div 3, cy+tri*2 div 3, A(C_CYAN, 220));
  ren.DrawLine(cx-tri*2 div 3, cy+tri*2 div 3, cx+tri*2 div 3, cy+tri*2 div 3, A(C_CYAN, 220));
  ren.PushBlendAdd;
  ren.DrawFilledCircle(cx, cy - tri div 3, Max(2, dot), A(C_CYAN, 80));
  ren.PopBlend;
end;

// ─────────────────────────────────────────────────────────────
//  Health dial — large number at top, radar at bottom half
// ─────────────────────────────────────────────────────────────
procedure DrawHealthDial(ren: IRenderer; cx,cy,value: Integer;
                         fontBig, fontSmall: IFont; tick: Single);
const
  ARC_S = 130;  ARC_E = 410;  // 280° sweep
var
  fillEnd, innerR, radarCY, radarR: Integer;
  sz: TPoint;
  vStr: String;
  capX, capY: Integer;
begin
  fillEnd := ARC_S + Round((ARC_E - ARC_S) * value / 100);
  innerR  := H_R - H_T div 2 - 5;   // usable interior radius (~104)

  // 1. Dark fill — clean interior so radar/text sit on black
  ren.DrawFilledCircle(cx, cy, innerR, C_INNER);

  // 2. Radar — animated sweep (purely dynamic)
  radarCY := cy + innerR * 28 div 100;  // ~28% of innerR below center
  radarR  := innerR * 55 div 100;
  DrawRadar(ren, cx, radarCY, radarR, tick);

  // 3. Filled dotted arc — shows current health value (dynamic)
  DrawDottedArc(ren, cx, cy, H_R, ARC_S, fillEnd, Max(3, H_T*26 div 100), C_PINK, H_R*44 div 1000 + 2.5);

  // 4. End-cap at arc tip (marks current value position)
  capX := cx + Round(H_R * Cos(fillEnd * Pi / 180));
  capY := cy + Round(H_R * Sin(fillEnd * Pi / 180));
  ren.DrawFilledCircle(capX, capY, H_T div 2 + 1, C_PINK);
  ren.PushBlendAdd;
  ren.DrawFilledCircle(capX, capY, H_T div 2 + 5,  A(C_PINK, 70));
  ren.DrawFilledCircle(capX, capY, H_T div 2 + 10, A(C_PINK, 30));
  ren.PopBlend;

  // 5. Value text (dynamic)
  if fontBig <> nil then
  begin
    vStr := IntToStr(value);
    sz   := fontBig.MeasureText(vStr);
    ren.DrawText(fontBig, vStr,
                 cx - sz.x div 2,
                 cy - innerR + 14,
                 C_WHITE);
  end;
  if fontSmall <> nil then
  begin
    sz := fontSmall.MeasureText('HEALTH');
    ren.DrawText(fontSmall, 'HEALTH',
                 cx - sz.x div 2,
                 cy - innerR + 14 + 46,
                 $FFAABB);
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Ammo dial — simple number centered in cyan arc
// ─────────────────────────────────────────────────────────────
procedure DrawAmmoDial(ren: IRenderer; cx,cy,value: Integer;
                       fontBig, fontSmall: IFont; tick: Single);
const
  ARC_S = 130;  ARC_E = 410;
var
  fillEnd, innerR: Integer;
  sz: TPoint;
  vStr: String;
  capX, capY: Integer;
begin
  fillEnd := ARC_S + Round((ARC_E - ARC_S) * value / 300);
  innerR  := A_R - A_T div 2 - 4;

  // 1. Dark fill — clean interior
  ren.DrawFilledCircle(cx, cy, innerR, C_INNER);

  // 2. Filled dotted arc — shows current ammo (dynamic)
  DrawDottedArc(ren, cx, cy, A_R, ARC_S, fillEnd, Max(2, A_T*25 div 100), C_CYAN, A_R*50 div 1000 + 2.5);

  // 3. End-cap at arc tip
  capX := cx + Round(A_R * Cos(fillEnd * Pi / 180));
  capY := cy + Round(A_R * Sin(fillEnd * Pi / 180));
  ren.DrawFilledCircle(capX, capY, A_T div 2 + 1, C_CYAN);
  ren.PushBlendAdd;
  ren.DrawFilledCircle(capX, capY, A_T div 2 + 5,  A(C_CYAN, 70));
  ren.DrawFilledCircle(capX, capY, A_T div 2 + 10, A(C_CYAN, 25));
  ren.PopBlend;

  // 4. Value text (dynamic)
  if fontBig <> nil then
  begin
    vStr := IntToStr(value);
    sz   := fontBig.MeasureText(vStr);
    ren.DrawText(fontBig, vStr,
                 cx - sz.x div 2,
                 cy - sz.y div 2 - 5,
                 C_WHITE);
  end;
  if fontSmall <> nil then
  begin
    sz := fontSmall.MeasureText('AMMO');
    ren.DrawText(fontSmall, 'AMMO',
                 cx - sz.x div 2,
                 cy + 11,
                 $AACCDD);
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Weapon image — detailed holographic rifle
// ─────────────────────────────────────────────────────────────
procedure DrawWeaponImage(ren: IRenderer; bx,by,bw,bh: Integer; tick: Single);
var
  bri: Single;
begin
  bri := 0.75 + 0.25 * ((Sin(tick * 1.8) + 1.0) * 0.5);

  // Weapon panel sprite — 391×273 baked 3D rifle render
  if imgWeaponPanel <> nil then
    ren.DrawImage(imgWeaponPanel,
                  R(0, 0, imgWeaponPanel.GetWidth, imgWeaponPanel.GetHeight),
                  R(bx, by, bw, bh))
  else
  begin
    ren.DrawFilledRect(R(bx, by, bw, bh), $010810);
    ren.DrawRoundRect(R(bx, by, bw, bh), 4, C_CYAN3, False);
  end;

  // Animated pulse glow over the whole panel (dynamic only)
  ren.PushBlendAdd;
  ren.DrawFilledRect(R(bx, by, bw, bh), A(C_CYAN, Byte(Trunc(18 * bri))));
  ren.PopBlend;
end;

// ─────────────────────────────────────────────────────────────
//  Single hexagonal weapon slot
// ─────────────────────────────────────────────────────────────
procedure DrawWeaponSlot(ren: IRenderer; cx,cy,hr: Integer;
                         numLabel: String; iconType: Integer;
                         active: Boolean; col: LongWord;
                         font: IFont; tick: Single);
var
  i: Integer;
  ic: LongWord;
  pm: Single;
  sz: TPoint;
begin
  pm := 1.0;
  if active then pm := 0.55 + 0.45 * ((Sin(tick * 5.0) + 1.0) * 0.5);

  // Glow halo (active only) — very prominent
  if active then
  begin
    GlowHex(ren, cx, cy, hr + 8, col, 7);
    GlowHex(ren, cx, cy, hr + 2, col, 4);
  end;

  // Hex slot sprite — иконка уже запечена в спрайте
  if active and (imgSlotHexActive <> nil) then
  begin
    ren.DrawImage(imgSlotHexActive,
                  R(0, 0, imgSlotHexActive.GetWidth, imgSlotHexActive.GetHeight),
                  R(cx - hr, cy - hr, hr * 2, hr * 2));
  end
  else if (not active) and (imgSlotHex <> nil) then
  begin
    ren.DrawImage(imgSlotHex,
                  R(0, 0, imgSlotHex.GetWidth, imgSlotHex.GetHeight),
                  R(cx - hr, cy - hr, hr * 2, hr * 2));
  end
  else
  begin
    // Fallback procedural (масштабируем иконку под hr)
    HexFill(ren, cx, cy, hr-1, IfThen(active, $180030, $06000E));
    HexOutline(ren, cx, cy, hr, col, 2);
    ic := IfThen(active, col, $334466);
    i  := hr * 55 div 100;   // ~55% от радиуса
    case iconType of
      0: begin  // Крест
           ren.DrawLine(cx-i, cy, cx+i, cy, ic);
           ren.DrawLine(cx, cy-i, cx, cy+i, ic);
         end;
      1: begin  // Угол
           ren.DrawLine(cx-i, cy-i, cx+i, cy-i, ic);
           ren.DrawLine(cx-i, cy-i, cx-i, cy+i, ic);
         end;
      2: begin  // Ромб
           ren.DrawLine(cx, cy-i, cx+i, cy, ic);
           ren.DrawLine(cx+i, cy, cx, cy+i, ic);
           ren.DrawLine(cx, cy+i, cx-i, cy, ic);
           ren.DrawLine(cx-i, cy, cx, cy-i, ic);
         end;
    end;
  end;

  // Pulsing center glow on active slot
  if active then
  begin
    ren.PushBlendAdd;
    ren.DrawFilledCircle(cx, cy, Round(10 * pm), A(col, Byte(Trunc(35 * pm))));
    ren.PopBlend;
  end;

  // Number label (below hex)
  if font <> nil then
  begin
    sz := font.MeasureText(numLabel);
    ren.DrawText(font, numLabel,
                 cx - sz.x div 2,
                 cy + hr + 3,
                 IfThen(active, col, $445566));
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Main HUD assembly
// ─────────────────────────────────────────────────────────────
procedure DrawCyberpunkHUD(ren: IRenderer;
                           fontBig, fontMid, fontSmall: IFont;
                           tick: Single);
var
  px, py, i: Integer;
  sz: TPoint;
  glowA: Byte;
  armW, ctrW: Integer;
  ctrRight: Integer;
  slY: Integer;
  sxA, sxB, sxC: Integer;  // slot X positions
begin
  px := PNL_X;  py := PNL_Y;
  ctrRight := CTR_R;
  ctrW     := ctrRight - CTR_X;

  // ══════════════════════════════════════════════════════════
  //  1. PANEL BACKGROUND
  // ══════════════════════════════════════════════════════════
  if imgPanelBg <> nil then
  begin
    // Direct stretch — кольца встроены в спрайт, 9-slice деформирует их
    ren.DrawImage(imgPanelBg,
                  R(0, 0, imgPanelBg.GetWidth, imgPanelBg.GetHeight),
                  R(px, py, PNL_W, PNL_H));
  end
  else
  begin
    // Fallback procedural panel
    ren.DrawRoundRect(R(px, py, PNL_W, PNL_H), 3, C_PANEL, True);
    for i := 0 to ANG do
    begin
      ren.DrawLine(px, py+i,               px+ANG-i, py,          C_BG);
      ren.DrawLine(px+PNL_W-ANG+i, py,     px+PNL_W, py+i,        C_BG);
      ren.DrawLine(px, py+PNL_H-i,         px+ANG-i, py+PNL_H,    C_BG);
      ren.DrawLine(px+PNL_W-ANG+i, py+PNL_H, px+PNL_W, py+PNL_H-i, C_BG);
    end;
  end;

  // ══════════════════════════════════════════════════════════
  //  2. ADDITIVE GLOW — лёгкий ореол по краям панели
  //     (кольца уже нарисованы в спрайте, их дополнительные
  //      DrawCircle были убраны — они боролись со спрайтом)
  // ══════════════════════════════════════════════════════════
  ren.PushBlendAdd;
  for i := 5 downto 1 do
  begin
    glowA := Trunc(20.0 * i / 5);
    ren.DrawLine(px+ANG, py-i, px+PNL_W div 2, py-i, A(C_PINK, glowA));
    ren.DrawLine(px+PNL_W div 2, py-i, px+PNL_W-ANG, py-i, A(C_CYAN, glowA));
    ren.DrawLine(px-i, py+ANG, px-i, py+PNL_H-ANG, A(C_PINK, glowA));
    ren.DrawLine(px+PNL_W+i, py+ANG, px+PNL_W+i, py+PNL_H-ANG, A(C_CYAN, glowA));
  end;
  ren.PopBlend;

  // ══════════════════════════════════════════════════════════
  //  3. HEALTH DIAL
  // ══════════════════════════════════════════════════════════
  DrawHealthDial(ren, H_CX, H_CY, 100, fontBig, fontSmall, tick);

  // ══════════════════════════════════════════════════════════
  //  4. CENTER SECTION
  // ══════════════════════════════════════════════════════════

  // ── ARMOR bar (top of center, compact) ──────────────────
  armW := ctrW - 6;
  if fontSmall <> nil then
  begin
    sz := fontSmall.MeasureText('ARMOR');
    ren.DrawText(fontSmall, 'ARMOR',
                 CTR_X + ctrW div 2 - sz.x div 2, py + 9, C_CYAN);
  end;
  ren.DrawRoundRect(R(CTR_X+3, py+22, armW, 6), 2, $0A001E, True);
  ren.DrawRoundRect(R(CTR_X+3, py+22, Round(armW * 0.75), 6), 2, C_CYAN2, True);
  ren.PushBlendAdd;
  ren.DrawRoundRect(R(CTR_X+2, py+21, Round(armW * 0.75)+2, 8), 2, A(C_CYAN, 28), True);
  ren.PopBlend;

  // ── OBJECTIVE box ────────────────────────────────────────
  if imgObjectivePanel <> nil then
    ren.DrawImage(imgObjectivePanel,
                  R(0, 0, imgObjectivePanel.GetWidth, imgObjectivePanel.GetHeight),
                  R(CTR_X, py+36, ctrW, 57))
  else
  begin
    ren.DrawRoundRect(R(CTR_X, py+36, ctrW, 57), 3, $060018, True);
    ren.PushBlendAdd;
    for i := 3 downto 1 do
      ren.DrawRoundRect(R(CTR_X-i, py+36-i, ctrW+i*2, 57+i*2), 3,
                        A(C_PINK, Byte(i * 16)), False);
    ren.PopBlend;
    ren.DrawRoundRect(R(CTR_X, py+36, ctrW, 57), 3, C_PINK2, False);
  end;
  if fontSmall <> nil then
  begin
    ren.DrawText(fontSmall, 'OBJECTIVE', CTR_X+6, py+42, C_PINK);
    ren.DrawText(fontSmall, 'Find the server', CTR_X+6, py+54, C_LGRAY);
    ren.DrawText(fontSmall, 'in sector 7',     CTR_X+6, py+66, C_LGRAY);
  end;

  // ── WEAPON SLOTS ─────────────────────────────────────────
  // X positions: sprite-derived × 0.718
  //   315×0.718=226 → PNL_X+226=456
  //   467×0.718=335 → PNL_X+335=565
  //   615×0.718=442 → PNL_X+442=672
  slY  := py + PNL_H - 45;
  sxA  := PNL_X + 226;   // = 456
  sxB  := PNL_X + 335;   // = 565
  sxC  := PNL_X + 442;   // = 672

  DrawWeaponSlot(ren, sxA, slY, 26, '2', 0, False, C_CYAN2, fontSmall, tick);
  DrawWeaponSlot(ren, sxB, slY, 26, '3', 1, False, C_CYAN2, fontSmall, tick);
  DrawWeaponSlot(ren, sxC, slY, 26, '1', 2, True,  C_CYAN,  fontSmall, tick);

  // ══════════════════════════════════════════════════════════
  //  6. AMMO DIAL
  // ══════════════════════════════════════════════════════════
  DrawAmmoDial(ren, A_CX, A_CY, 180, fontBig, fontSmall, tick);

  // ══════════════════════════════════════════════════════════
  //  7. WEAPON PANEL
  // ══════════════════════════════════════════════════════════
  DrawWeaponImage(ren, WPN_X, WPN_Y, WPN_W, WPN_H, tick);

  // ══════════════════════════════════════════════════════════
  //  8. DECORATIVE DETAILS
  // ══════════════════════════════════════════════════════════

  // Top-edge small tick marks
  for i := 1 to 6 do
  begin
    ren.DrawLine(px + PNL_W div 7 * i, py,       px + PNL_W div 7 * i, py + 4,       $334455);
    ren.DrawLine(px + PNL_W div 7 * i, py+PNL_H, px + PNL_W div 7 * i, py+PNL_H - 4, $334455);
  end;

  // Inner horizontal section separators
  ren.DrawLine(px+ANG, py+16, CTR_X-4, py+16, $222233);
  ren.DrawLine(ctrRight+4, py+16, px+PNL_W-ANG, py+16, $222233);

  // ── Corner brackets (sprite 239×239, scaled ×0.718 → 79×79) ─
  if imgCornerBrackets <> nil then
    ren.DrawImage(imgCornerBrackets,
                  R(0, 0, imgCornerBrackets.GetWidth, imgCornerBrackets.GetHeight),
                  R(px + PNL_W - 79, py - 11, 79, 79));

  // LABEL (top-left)
  if fontSmall <> nil then
  begin
    ren.DrawText(fontSmall, 'CYBERPUNK NEON', px + 10, py + 6, C_CYAN);
    ren.PushBlendAdd;
    ren.DrawText(fontSmall, 'CYBERPUNK NEON', px + 10, py + 6, A(C_CYAN, 80));
    ren.PopBlend;
  end;
end;

// ─────────────────────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────────────────────
var
  ren:      TSDL2Renderer;
  rm:       TResourceManager;
  loader:   TSDL2ImageLoader;
  floader:  TSDL2FontLoader;
  fontBig, fontMid, fontSmall: IFont;
  fontPath: String;
  event:    TSDL_Event;
  running:  Boolean;
  lastT, nowT: UInt32;
  dt, tick: Single;
  yy, vi:   Integer;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);

  if SDL_Init(SDL_INIT_VIDEO) <> 0 then
    raise Exception.Create('SDL_Init: ' + SDL_GetError);
  if TTF_Init <> 0 then
    raise Exception.Create('TTF_Init: ' + SDL_GetError);
  try
    ren := TSDL2Renderer.CreateWithWindow(
             'Cyberpunk Neon HUD — WidgetLib', WIN_W, WIN_H);
    try
      loader  := TSDL2ImageLoader.Create(ren.GetRenderer);
      floader := TSDL2FontLoader.Create;
      rm      := TResourceManager.Create(loader, floader);
      try
        fontPath := '../../assets/fonts/DoomFont.ttf';
        {$IFDEF DARWIN}
        if not FileExists(fontPath) then
          fontPath := '/System/Library/Fonts/Helvetica.ttc';
        {$ENDIF}
        {$IFDEF LINUX}
        if not FileExists(fontPath) then
          fontPath := '/usr/share/fonts/truetype/freefont/FreeSans.ttf';
        {$ENDIF}

        fontBig   := rm.GetFont(fontPath, 36);   // was 52  (52×0.718≈37)
        fontMid   := rm.GetFont(fontPath, 16);   // was 22
        fontSmall := rm.GetFont(fontPath, 10);   // was 13

        // ── Load sprite assets from real spritesheet extracts ──
        if FileExists('../../assets/hud/panel_bg.png') then
          imgPanelBg        := rm.GetImage('../../assets/hud/panel_bg.png');
        if FileExists('../../assets/hud/slot_hex_1.png') then
          imgSlotHex        := rm.GetImage('../../assets/hud/slot_hex_1.png');
        if FileExists('../../assets/hud/slot_hex_active.png') then
          imgSlotHexActive  := rm.GetImage('../../assets/hud/slot_hex_active.png');
        if FileExists('../../assets/hud/weapon_panel.png') then
          imgWeaponPanel    := rm.GetImage('../../assets/hud/weapon_panel.png');
        if FileExists('../../assets/hud/objective_panel.png') then
          imgObjectivePanel := rm.GetImage('../../assets/hud/objective_panel.png');
        if FileExists('../../assets/hud/corner_brackets.png') then
          imgCornerBrackets := rm.GetImage('../../assets/hud/corner_brackets.png');

        running := True;
        lastT   := SDL_GetTicks;
        tick    := 0.0;

        while running do
        begin
          while SDL_PollEvent(@event) = 1 do
          begin
            case event.type_ of
              SDL_QUITEV: running := False;
              SDL_KEYDOWN:
                case event.key.keysym.sym of
                  27:                    running := False;  // Esc
                  Ord('q'), Ord('Q'):   running := False;
                end;
            end;
          end;

          nowT  := SDL_GetTicks;
          dt    := (nowT - lastT) / 1000.0;
          lastT := nowT;
          if dt > 0.1 then dt := 0.1;
          tick  := tick + dt;

          ren.BeginFrame;

          // Dark background
          ren.DrawFilledRect(R(0, 0, WIN_W, WIN_H), C_BG);

          // Subtle horizontal scanlines (atmospheric effect)
          ren.PushBlendAdd;
          for yy := 0 to WIN_H div 4 do
            ren.DrawLine(0, yy*4, WIN_W, yy*4, A($0000BB, 4));
          ren.PopBlend;

          // Subtle vignette (darker at edges)
          ren.PushBlendAdd;
          for vi := 1 to 8 do
            ren.DrawRoundRect(R(vi*4, vi*4, WIN_W-vi*8, WIN_H-vi*8), vi*3,
                              A($000008, Byte(8-vi)), False);
          ren.PopBlend;

          DrawCyberpunkHUD(ren, fontBig, fontMid, fontSmall, tick);

          ren.EndFrame;
          SDL_Delay(1);
        end;

      finally
        rm.Free;  loader.Free;  floader.Free;
      end;
    finally
      ren.Free;
    end;
  finally
    TTF_Quit;  SDL_Quit;
  end;
end.
