program HUDShowcase;

{$mode objfpc}{$H+}

{ ═══════════════════════════════════════════════════════════════════════════════
  FPS HUD Skin Showcase — 6 themed panels in a 2×3 grid
  Keys 1-6 : toggle theme highlight
  Q / Esc  : quit
  ═══════════════════════════════════════════════════════════════════════════════ }

uses
  SysUtils, Math,
  SDL2, SDL2_ttf,
  Core.Contracts,
  SDL2Renderer,
  SDL2FontLoader,
  SDL2ImageLoader,
  ResourceManager,
  SkinSystem,
  GameWidgets,
  BaseWidget;

const
  WIN_W = 1360;
  WIN_H = 900;

  PANEL_W = 620;
  PANEL_H = 230;
  GAP_X   = 40;
  GAP_Y   = 36;
  MARGIN_X = 30;
  MARGIN_Y = 26;

  FONT_SIZE_BIG   = 28;
  FONT_SIZE_MID   = 16;
  FONT_SIZE_SMALL = 11;

// ─────────────────────────────────────────────────────────────────────────────
//  Theme descriptor
// ─────────────────────────────────────────────────────────────────────────────
type
  TTheme = record
    name:        String;
    bgColor:     LongWord;   // panel background
    borderColor: LongWord;
    glowColor:   LongWord;
    arcColor:    LongWord;   // health/ammo arc fill
    bgArcColor:  LongWord;   // arc background
    accentColor: LongWord;   // title / key text
    bodyColor:   LongWord;   // body text
    slotActive:  LongWord;
    slotBorder:  LongWord;
    statColor:   LongWord;
    pulse:       Boolean;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  Six themes from the reference image
// ─────────────────────────────────────────────────────────────────────────────
function MakeTheme(const nm: String;
                   bg, border, glow,
                   arc, bgArc, accent, body,
                   slotAct, slotBrd, stat: LongWord;
                   pulse: Boolean): TTheme;
begin
  Result.name        := nm;
  Result.bgColor     := bg;
  Result.borderColor := border;
  Result.glowColor   := glow;
  Result.arcColor    := arc;
  Result.bgArcColor  := bgArc;
  Result.accentColor := accent;
  Result.bodyColor   := body;
  Result.slotActive  := slotAct;
  Result.slotBorder  := slotBrd;
  Result.statColor   := stat;
  Result.pulse       := pulse;
end;

const
  THEME_COUNT = 6;

var
  Themes: array[0..THEME_COUNT-1] of TTheme;

procedure InitThemes;
begin
  // 1 – Cyberpunk Neon
  Themes[0] := MakeTheme('CYBERPUNK NEON',
    $050010, $CC00AA, $FF00CC,
    $FF00CC, $1A0030, $FF44EE, $CC99DD,
    $220033, $CC00AA, $BB00AA, True);

  // 2 – Alien Organic
  Themes[1] := MakeTheme('ALIEN ORGANIC',
    $020D02, $00AA33, $00FF44,
    $00FF44, $011201, $44FF88, $88CC99,
    $011501, $00AA33, $00CC33, True);

  // 3 – Military Tactical
  Themes[2] := MakeTheme('MILITARY TACTICAL',
    $0C0C06, $667722, $AAAA00,
    $CCCC00, $151508, $DDDD44, $AABB66,
    $1A1A08, $667722, $888800, False);

  // 4 – Steampunk Retro
  Themes[3] := MakeTheme('STEAMPUNK RETRO',
    $110900, $AA6600, $FFAA00,
    $FFAA22, $1A0E00, $FFCC66, $DDAA77,
    $221000, $AA6600, $CC8800, False);

  // 5 – Frostbite
  Themes[4] := MakeTheme('FROSTBITE',
    $010C18, $2266AA, $44AAFF,
    $88DDFF, $011020, $88CCFF, $AACCEE,
    $061828, $2266AA, $2288CC, True);

  // 6 – Demonic Inferno
  Themes[5] := MakeTheme('DEMONIC INFERNO',
    $0F0000, $AA2200, $FF3300,
    $FF4400, $180400, $FF6644, $CC6644,
    $1A0400, $AA2200, $CC2200, True);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Panel origin helper
// ─────────────────────────────────────────────────────────────────────────────
procedure PanelPos(idx: Integer; out px, py: Integer);
begin
  px := MARGIN_X + (idx mod 2) * (PANEL_W + GAP_X);
  py := MARGIN_Y + (idx div 2) * (PANEL_H + GAP_Y);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Draw one HUD panel for theme t at pixel pos (px, py)
// ─────────────────────────────────────────────────────────────────────────────
procedure DrawHUDPanel(r: IRenderer; const t: TTheme;
                       px, py: Integer; dt: Single;
                       font_big, font_mid, font_small: IFont;
                       tick: Single);
const
  RING_R   = 82;    // outer radius of health/ammo rings
  RING_THK = 13;    // ring thickness
  RING_PAD = 4;     // padding between ring and panel edge
  CIRC_DIA = (RING_R + RING_THK + RING_PAD) * 2;

var
  panelR: TRect;
  i, gi:  Integer;
  gA:     Byte;
  gR:     TRect;
  pulseK: Single;

  // --- sub-rects ---
  leftCX, leftCY:  Integer;
  rightCX, rightCY: Integer;
  centerX, centerY: Integer;
  centerW, centerH: Integer;

  // text helpers
  sz:     TPoint;
  tx, ty: Integer;

  // arc helpers
  ratio:   Single;
  fillEnd: Integer;
  startD, endD: Integer;

  // weapon slots
  slotW, slotH, slotGap: Integer;
  slotTotalW, slotSX, slotSY: Integer;
  slotR: TRect;
  keyStr: String;
  isAct:  Boolean;
  bgC, brdC: LongWord;
  glowByte: Byte;

  // stat bars
  barX, barY, barW, barH: Integer;
  fillW: Integer;
  fillR: TRect;

  // header
  hdrStr: String;
begin
  panelR := MakeRect(px, py, PANEL_W, PANEL_H);

  // ── Panel glow halo ──────────────────────────────────────────────────────
  if t.glowColor <> 0 then
  begin
    pulseK := 1.0;
    if t.pulse then
      pulseK := 0.5 + 0.5 * ((Sin(tick * 3.0) + 1.0) * 0.5);
    r.PushBlendAdd;
    for i := 8 downto 1 do
    begin
      gA := Trunc(35.0 * pulseK * i / 8);
      gR := MakeRect(px - i, py - i, PANEL_W + 2*i, PANEL_H + 2*i);
      r.DrawRoundRect(gR, 14 + i,
                      (LongWord(gA) shl 24) or (t.glowColor and $FFFFFF), True);
    end;
    r.PopBlend;
  end;

  // ── Panel background ─────────────────────────────────────────────────────
  r.DrawRoundRect(panelR, 12, t.bgColor, True);
  r.DrawRoundRect(panelR, 12, t.borderColor, False);

  // ── Left ring (HEALTH) ───────────────────────────────────────────────────
  leftCX := px + CIRC_DIA div 2 + RING_PAD;
  leftCY := py + PANEL_H div 2;

  // Background arc
  startD := 130; endD := 410;  // 280° sweep, opening at bottom
  r.DrawArc(leftCX, leftCY, RING_R, startD, endD, t.bgArcColor, RING_THK);

  // Filled arc (health = 75%)
  ratio   := 0.75;
  fillEnd := startD + Round((endD - startD) * ratio);

  if t.glowColor <> 0 then
  begin
    r.PushBlendAdd;
    for gi := 3 downto 1 do
    begin
      gA := Trunc(30.0 * gi / 3 *
                  (0.7 + 0.3 * ((Sin(tick * 4.0)+1.0)*0.5)));
      r.DrawArc(leftCX, leftCY, RING_R, startD, fillEnd,
                (LongWord(gA) shl 24) or (t.arcColor and $FFFFFF),
                RING_THK + gi * 2);
    end;
    r.PopBlend;
  end;
  r.DrawArc(leftCX, leftCY, RING_R, startD, fillEnd, t.arcColor, RING_THK);

  // End cap
  r.DrawFilledCircle(
    leftCX + Round(RING_R * Cos(fillEnd * Pi / 180)),
    leftCY + Round(RING_R * Sin(fillEnd * Pi / 180)),
    RING_THK div 2 + 1, t.arcColor);

  // Inner fill (dark)
  r.DrawFilledCircle(leftCX, leftCY, RING_R - RING_THK div 2 - 2, $080808);

  // Health value
  if font_big <> nil then
  begin
    sz := font_big.MeasureText('100');
    r.DrawText(font_big, '100', leftCX - sz.x div 2, leftCY - sz.y div 2 - 4, t.accentColor);
  end;
  if font_small <> nil then
  begin
    sz := font_small.MeasureText('HEALTH');
    r.DrawText(font_small, 'HEALTH', leftCX - sz.x div 2, leftCY + 10, t.bodyColor);
  end;

  // ── Right ring (AMMO) ────────────────────────────────────────────────────
  rightCX := px + PANEL_W - CIRC_DIA div 2 - RING_PAD;
  rightCY := leftCY;

  r.DrawArc(rightCX, rightCY, RING_R, startD, endD, t.bgArcColor, RING_THK);

  ratio   := 0.60;
  fillEnd := startD + Round((endD - startD) * ratio);

  if t.glowColor <> 0 then
  begin
    r.PushBlendAdd;
    for gi := 3 downto 1 do
    begin
      gA := Trunc(30.0 * gi / 3 *
                  (0.7 + 0.3 * ((Sin(tick * 3.7)+1.0)*0.5)));
      r.DrawArc(rightCX, rightCY, RING_R, startD, fillEnd,
                (LongWord(gA) shl 24) or (t.arcColor and $FFFFFF),
                RING_THK + gi * 2);
    end;
    r.PopBlend;
  end;
  r.DrawArc(rightCX, rightCY, RING_R, startD, fillEnd, t.arcColor, RING_THK);
  r.DrawFilledCircle(
    rightCX + Round(RING_R * Cos(fillEnd * Pi / 180)),
    rightCY + Round(RING_R * Sin(fillEnd * Pi / 180)),
    RING_THK div 2 + 1, t.arcColor);
  r.DrawFilledCircle(rightCX, rightCY, RING_R - RING_THK div 2 - 2, $080808);

  if font_big <> nil then
  begin
    sz := font_big.MeasureText('45');
    r.DrawText(font_big, '45', rightCX - sz.x div 2, rightCY - sz.y div 2 - 4, t.accentColor);
  end;
  if font_small <> nil then
  begin
    sz := font_small.MeasureText('AMMO');
    r.DrawText(font_small, 'AMMO', rightCX - sz.x div 2, rightCY + 10, t.bodyColor);
  end;

  // ── Center column ────────────────────────────────────────────────────────
  centerX := px + CIRC_DIA + RING_PAD * 2 + 4;
  centerW := PANEL_W - CIRC_DIA * 2 - RING_PAD * 4 - 8;
  centerY := py + 10;
  centerH := PANEL_H - 20;

  // Armor bar
  barX := centerX + 4;
  barY := centerY + 4;
  barW := centerW - 8;
  barH := 14;
  r.DrawRoundRect(MakeRect(barX, barY, barW, barH), 3, $0D0D0D, True);
  fillW := Round((barW - 2) * 0.90);
  fillR := MakeRect(barX + 1, barY + 1, fillW, barH - 2);
  if t.glowColor <> 0 then
  begin
    r.PushBlendAdd;
    r.DrawRoundRect(MakeRect(fillR.x - 1, fillR.y - 1, fillR.w + 2, fillR.h + 2),
                    3, (LongWord(25) shl 24) or (t.accentColor and $FFFFFF), True);
    r.PopBlend;
  end;
  r.DrawRoundRect(fillR, 3, t.statColor, True);
  r.DrawRoundRect(MakeRect(barX, barY, barW, barH), 3, t.borderColor, False);
  if font_small <> nil then
  begin
    sz := font_small.MeasureText('ARMOR  75');
    r.DrawText(font_small, 'ARMOR  75', barX + 4, barY + (barH - sz.y) div 2, t.bodyColor);
  end;

  // Objective box
  ty := barY + barH + 6;
  r.DrawRoundRect(MakeRect(centerX, ty, centerW, 60), 5, $0C0C0C, True);
  r.DrawRoundRect(MakeRect(centerX, ty, centerW, 60), 5,
                  (t.borderColor and $FFFFFF) or $44000000, False);
  if font_small <> nil then
  begin
    r.DrawText(font_small, 'OBJECTIVE',
               centerX + 6, ty + 5, t.accentColor);
    r.DrawText(font_small, 'Find the main server',
               centerX + 6, ty + 22, t.bodyColor);
    r.DrawText(font_small, 'in sector 7',
               centerX + 6, ty + 37, t.bodyColor);
  end;

  // Weapon slot bar
  slotW := 42; slotH := 42; slotGap := 5;
  slotTotalW := 5 * slotW + 4 * slotGap;
  slotSX := centerX + (centerW - slotTotalW) div 2;
  slotSY := py + PANEL_H - slotH - 10;

  for i := 0 to 4 do
  begin
    slotR := MakeRect(slotSX + i * (slotW + slotGap), slotSY, slotW, slotH);
    isAct := (i = 1);
    bgC  := IfThen(isAct, t.slotActive,  t.bgColor);
    brdC := IfThen(isAct, t.glowColor,   t.slotBorder);
    if brdC = 0 then brdC := t.slotBorder;

    // glow on active
    if isAct and (t.glowColor <> 0) then
    begin
      glowByte := 30 + Round(25 * ((Sin(tick * 5.0)+1.0)*0.5));
      r.PushBlendAdd;
      r.DrawRoundRect(MakeRect(slotR.x - 3, slotR.y - 3, slotW + 6, slotH + 6),
                      6, (LongWord(glowByte) shl 24) or (t.glowColor and $FFFFFF), True);
      r.PopBlend;
    end;

    r.DrawRoundRect(slotR, 4, bgC, True);
    r.DrawRoundRect(slotR, 4, brdC, False);

    // slot number
    keyStr := IntToStr(i + 1);
    if i = 0 then keyStr := '1';
    if font_small <> nil then
    begin
      sz := font_small.MeasureText(keyStr);
      r.DrawText(font_small, keyStr,
                 slotR.x + (slotW - sz.x) div 2,
                 slotR.y + slotH - sz.y - 3,
                 IfThen(isAct, t.accentColor, t.bodyColor));
    end;

    // small icon placeholder (X-shape)
    if not isAct then
    begin
      r.DrawLine(slotR.x + 8,  slotR.y + 8,
                 slotR.x + slotW - 8, slotR.y + slotH - 18,
                 (t.borderColor or $22000000));
      r.DrawLine(slotR.x + slotW - 8, slotR.y + 8,
                 slotR.x + 8, slotR.y + slotH - 18,
                 (t.borderColor or $22000000));
    end
    else
    begin
      // active weapon — simple crosshair icon
      tx := slotR.x + slotW div 2;
      ty := slotR.y + (slotH - 14) div 2;
      r.DrawLine(tx - 8, ty + 6, tx + 8, ty + 6, t.accentColor);
      r.DrawLine(tx, ty, tx, ty + 12, t.accentColor);
    end;
  end;

  // ── Theme name (top-left corner) ────────────────────────────────────────
  if font_mid <> nil then
  begin
    hdrStr := t.name;
    r.DrawText(font_mid, hdrStr, px + 10, py + 4, t.accentColor);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────────────────────────────────────
var
  renderer:  TSDL2Renderer;
  rm:        TResourceManager;
  loader:    TSDL2ImageLoader;
  floader:   TSDL2FontLoader;
  fontBig:   IFont;
  fontMid:   IFont;
  fontSmall: IFont;
  fontPath:  String;
  event:     TSDL_Event;
  running:   Boolean;
  lastTicks, nowTicks: UInt32;
  dt, tick:  Single;
  i:         Integer;
  px, py:    Integer;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);

  if SDL_Init(SDL_INIT_VIDEO) <> 0 then
    raise Exception.Create('SDL_Init: ' + SDL_GetError);
  if TTF_Init <> 0 then
    raise Exception.Create('TTF_Init: ' + SDL_GetError);

  InitThemes;

  try
    renderer := TSDL2Renderer.CreateWithWindow(
      'FPS HUD Skin Showcase — WidgetLib', WIN_W, WIN_H);
    try
      loader  := TSDL2ImageLoader.Create(renderer.GetRenderer);
      floader := TSDL2FontLoader.Create;
      rm      := TResourceManager.Create(loader, floader);
      try
        // Font — use bundled Doom font or system fallback
        fontPath := '../../demo/doom/assets/fonts/DoomFont.ttf';
        {$IFDEF DARWIN}
        if not FileExists(fontPath) then
          fontPath := '/System/Library/Fonts/Helvetica.ttc';
        {$ENDIF}
        {$IFDEF LINUX}
        if not FileExists(fontPath) then
          fontPath := '/usr/share/fonts/truetype/freefont/FreeMono.ttf';
        {$ENDIF}

        fontBig   := rm.GetFont(fontPath, FONT_SIZE_BIG);
        fontMid   := rm.GetFont(fontPath, FONT_SIZE_MID);
        fontSmall := rm.GetFont(fontPath, FONT_SIZE_SMALL);

        running   := True;
        tick      := 0;
        lastTicks := SDL_GetTicks;

        while running do
        begin
          // ── Events ───────────────────────────────────────────────────────
          while SDL_PollEvent(@event) = 1 do
          begin
            case event.type_ of
              SDL_QUITEV:     running := False;
              SDL_KEYDOWN:
                case event.key.keysym.sym of
                  27:          running := False;  // Esc
                  Ord('q'), Ord('Q'): running := False;
                end;
            end;
          end;

          // ── Timing ───────────────────────────────────────────────────────
          nowTicks  := SDL_GetTicks;
          dt        := (nowTicks - lastTicks) / 1000.0;
          lastTicks := nowTicks;
          if dt > 0.1 then dt := 0.1;
          tick := tick + dt;

          // ── Render ───────────────────────────────────────────────────────
          renderer.BeginFrame;

          // Grid background
          renderer.DrawFilledRect(MakeRect(0, 0, WIN_W, WIN_H), $070710);

          // Subtle grid lines
          for i := 0 to WIN_W div 40 do
            renderer.DrawLine(i*40, 0, i*40, WIN_H,
                              $0A0A18 or $FF000000);

          // Draw all 6 panels
          for i := 0 to THEME_COUNT - 1 do
          begin
            PanelPos(i, px, py);
            DrawHUDPanel(renderer, Themes[i], px, py, dt,
                         fontBig, fontMid, fontSmall, tick);
          end;

          // Title bar
          if fontMid <> nil then
            renderer.DrawText(fontMid,
              'FPS GAME UI SKINS — WidgetLib / Pascal  [Q=Quit]',
              16, WIN_H - 24, $446688);

          renderer.EndFrame;
          SDL_Delay(1);
        end;

      finally
        rm.Free;
        loader.Free;
        floader.Free;
      end;
    finally
      renderer.Free;
    end;
  finally
    TTF_Quit;
    SDL_Quit;
  end;
end.
