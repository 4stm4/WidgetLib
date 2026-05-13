unit GameWidgets;

{$mode objfpc}{$H+}

{ Game-specific widgets:
    TCircularGauge   — thick arc gauge (health / ammo rings)
    TWeaponSlotBar   — row of weapon-slot buttons
    TObjectivePanel  — objective title + body text box
    THUDFrame        — outer panel with background + optional glow border
    TStatBar         — horizontal progress bar with label
}

interface

uses
  SysUtils, Math,
  Core.Contracts, BaseWidget;

// ═════════════════════════════════════════════════════════════════════════════
//  TCircularGauge — arc gauge (Doom health ring style)
// ═════════════════════════════════════════════════════════════════════════════
type
  TCircularGauge = class(TBaseWidget)
  private
    FValue:      Single;   // current value
    FMaxValue:   Single;   // max value
    FArcColor:   LongWord; // filled arc
    FBgArcColor: LongWord; // empty arc
    FGlowColor:  LongWord; // additive glow on filled arc (0 = none)
    FThickness:  Integer;  // arc ring thickness in pixels
    FStartDeg:   Integer;  // arc start angle (135 = bottom-left)
    FEndDeg:     Integer;  // arc end angle   (405 = bottom-right, 270° span)
    FFont:       IFont;
    FLabel:      String;   // e.g. 'HEALTH'
    FShowValue:  Boolean;
    FValueColor: LongWord;
    FLabelColor: LongWord;
    FTick:       Single;
  public
    constructor Create(const aID: String);
    procedure SetValue(value, maxValue: Single);
    procedure SetArcColors(arcColor, bgArcColor, glowColor: LongWord);
    procedure SetArcGeometry(startDeg, endDeg, thickness: Integer);
    procedure SetFont(f: IFont; const lbl: String = '');
    procedure ShowValueText(show: Boolean; valueColor: LongWord = $FFFFFF;
                            labelColor: LongWord = $AAAAAA);
    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
  end;

// ═════════════════════════════════════════════════════════════════════════════
//  TWeaponSlotBar — a row of weapon-slot indicators
// ═════════════════════════════════════════════════════════════════════════════
  TWeaponSlotBar = class(TBaseWidget)
  private
    FSlotCount:       Integer;
    FActiveSlot:      Integer;
    FSlotIcons:       array of IImage;
    FSlotKeys:        array of String;   // key label e.g. '1','2'
    FActiveColor:     LongWord;
    FInactiveColor:   LongWord;
    FBorderColor:     LongWord;
    FActiveTextColor: LongWord;
    FInactiveTextColor: LongWord;
    FFont:            IFont;
    FSlotW:           Integer;
    FSlotH:           Integer;
    FGlowColor:       LongWord;
    FTick:            Single;
  public
    constructor Create(const aID: String; slotCount: Integer);
    procedure SetActiveSlot(slot: Integer);
    procedure SetSlotIcon(slot: Integer; img: IImage);
    procedure SetSlotKey(slot: Integer; const key: String);
    procedure SetColors(active, inactive, border, glowColor: LongWord;
                        activeText: LongWord = $FFFFFF;
                        inactiveText: LongWord = $666666);
    procedure SetFont(f: IFont);
    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
  end;

// ═════════════════════════════════════════════════════════════════════════════
//  TObjectivePanel — info panel with title + body text
// ═════════════════════════════════════════════════════════════════════════════
  TObjectivePanel = class(TBaseWidget)
  private
    FTitle:       String;
    FBody:        String;
    FTitleColor:  LongWord;
    FBodyColor:   LongWord;
    FBgColor:     LongWord;
    FBorderColor: LongWord;
    FCornerRad:   Integer;
    FTitleFont:   IFont;
    FBodyFont:    IFont;
  public
    constructor Create(const aID: String);
    procedure SetText(const title, body: String);
    procedure SetColors(bg, border, titleColor, bodyColor: LongWord);
    procedure SetFonts(titleFont, bodyFont: IFont);
    procedure SetCornerRadius(rad: Integer);
    procedure Render(r: IRenderer); override;
  end;

// ═════════════════════════════════════════════════════════════════════════════
//  THUDFrame — themed panel background (rounded + optional 9-slice)
// ═════════════════════════════════════════════════════════════════════════════
  THUDFrame = class(TBaseWidget)
  private
    FBgColor:    LongWord;
    FBorderColor: LongWord;
    FGlowColor:  LongWord;
    FGlowRadius: Integer;
    FCornerRad:  Integer;
    FBgImage:    IImage;
    FBgMargins:  T9SliceMargins;
    FUse9Slice:  Boolean;
    FTick:       Single;
    FPulse:      Boolean;
  public
    constructor Create(const aID: String);
    procedure SetColors(bg, border, glowColor: LongWord; glowRadius: Integer = 6);
    procedure SetCornerRadius(r: Integer);
    procedure SetBgImage(img: IImage; margins: T9SliceMargins);
    procedure EnablePulse(on: Boolean);
    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
  end;

// ═════════════════════════════════════════════════════════════════════════════
//  TStatBar — horizontal labeled progress bar
// ═════════════════════════════════════════════════════════════════════════════
  TStatBar = class(TBaseWidget)
  private
    FValue:       Single;   // 0..1
    FColor:       LongWord;
    FBgColor:     LongWord;
    FBorderColor: LongWord;
    FGlowColor:   LongWord;
    FLabel:       String;
    FLabelColor:  LongWord;
    FFont:        IFont;
    FCornerRad:   Integer;
    FTick:        Single;
    FPulse:       Boolean;
  public
    constructor Create(const aID: String);
    procedure SetValue(v: Single);
    procedure SetColors(fillColor, bgColor, borderColor, glowColor: LongWord);
    procedure SetLabel(const s: String; f: IFont; labelColor: LongWord = $AAAAAA);
    procedure SetCornerRadius(r: Integer);
    procedure EnablePulse(on: Boolean);
    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
  end;

implementation

// ─────────────────────────────────────────────────────────────────────────────
//  TCircularGauge
// ─────────────────────────────────────────────────────────────────────────────

constructor TCircularGauge.Create(const aID: String);
begin
  inherited Create(aID);
  FValue      := 100;
  FMaxValue   := 100;
  FArcColor   := $00FF44;
  FBgArcColor := $222222;
  FGlowColor  := 0;
  FThickness  := 10;
  FStartDeg   := 135;
  FEndDeg     := 405;   // 270° sweep
  FShowValue  := True;
  FValueColor := $FFFFFF;
  FLabelColor := $888888;
  FTick       := 0;
end;

procedure TCircularGauge.SetValue(value, maxValue: Single);
begin
  FValue    := value;
  FMaxValue := maxValue;
end;

procedure TCircularGauge.SetArcColors(arcColor, bgArcColor, glowColor: LongWord);
begin
  FArcColor   := arcColor;
  FBgArcColor := bgArcColor;
  FGlowColor  := glowColor;
end;

procedure TCircularGauge.SetArcGeometry(startDeg, endDeg, thickness: Integer);
begin
  FStartDeg  := startDeg;
  FEndDeg    := endDeg;
  FThickness := thickness;
end;

procedure TCircularGauge.SetFont(f: IFont; const lbl: String);
begin
  FFont  := f;
  FLabel := lbl;
end;

procedure TCircularGauge.ShowValueText(show: Boolean;
                                       valueColor, labelColor: LongWord);
begin
  FShowValue  := show;
  FValueColor := valueColor;
  FLabelColor := labelColor;
end;

procedure TCircularGauge.Update(dt: Single);
begin
  inherited Update(dt);
  FTick := FTick + dt;
  if FTick > 1000 then FTick := FTick - 1000;
end;

procedure TCircularGauge.Render(r: IRenderer);
var
  b:       TRect;
  cx, cy:  Integer;
  radius:  Integer;
  ratio:   Single;
  fillEnd: Integer;
  totalDeg: Integer;
  sz:      TPoint;
  vStr:    String;
  vx, vy:  Integer;
  lx, ly:  Integer;
  gi:      Integer;
  pulseK:  Single;
begin
  if r = nil then Exit;
  b  := GetBounds;
  cx := b.x + b.w div 2;
  cy := b.y + b.h div 2;
  radius := Min(b.w, b.h) div 2 - FThickness div 2 - 2;
  if radius < 4 then Exit;

  totalDeg := FEndDeg - FStartDeg;  // e.g. 270
  ratio    := FValue / Max(1, FMaxValue);
  if ratio < 0 then ratio := 0;
  if ratio > 1 then ratio := 1;
  fillEnd  := FStartDeg + Round(totalDeg * ratio);

  // ── Background arc (full sweep) ──────────────────────────────────────────
  r.DrawArc(cx, cy, radius, FStartDeg, FEndDeg, FBgArcColor, FThickness);

  // ── Additive glow under filled arc ──────────────────────────────────────
  if (FGlowColor <> 0) and (fillEnd > FStartDeg) then
  begin
    pulseK := 0.7 + 0.3 * ((Sin(FTick * 4.0) + 1.0) * 0.5);
    r.PushBlendAdd;
    for gi := 3 downto 1 do
    begin
      r.DrawArc(cx, cy, radius,
                FStartDeg, fillEnd,
                (LongWord(Round(40 * pulseK * gi / 3)) shl 24) or
                (FGlowColor and $FFFFFF),
                FThickness + gi * 2);
    end;
    r.PopBlend;
  end;

  // ── Filled arc ───────────────────────────────────────────────────────────
  if fillEnd > FStartDeg then
    r.DrawArc(cx, cy, radius, FStartDeg, fillEnd, FArcColor, FThickness);

  // ── End-cap dot ─────────────────────────────────────────────────────────
  if (ratio > 0.02) and (fillEnd > FStartDeg) then
  begin
    r.DrawFilledCircle(
      cx + Round(radius * Cos(fillEnd * Pi / 180.0)),
      cy + Round(radius * Sin(fillEnd * Pi / 180.0)),
      FThickness div 2 + 1, FArcColor);
  end;

  // ── Inner dark fill ──────────────────────────────────────────────────────
  r.DrawFilledCircle(cx, cy, radius - FThickness div 2 - 1, $0A0A0A);

  // ── Value text ───────────────────────────────────────────────────────────
  if FShowValue and (FFont <> nil) then
  begin
    vStr := IntToStr(Round(FValue));
    sz   := FFont.MeasureText(vStr);
    vx   := cx - sz.x div 2;
    vy   := cy - sz.y div 2;
    if FLabel <> '' then vy := vy - sz.y div 3;
    r.DrawText(FFont, vStr, vx, vy, FValueColor);

    if FLabel <> '' then
    begin
      sz := FFont.MeasureText(FLabel);
      lx := cx - sz.x div 2;
      ly := vy + FFont.MeasureText(IntToStr(Round(FValue))).y + 1;
      r.DrawText(FFont, FLabel, lx, ly, FLabelColor);
    end;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TWeaponSlotBar
// ─────────────────────────────────────────────────────────────────────────────

constructor TWeaponSlotBar.Create(const aID: String; slotCount: Integer);
var
  i: Integer;
begin
  inherited Create(aID);
  FSlotCount       := slotCount;
  FActiveSlot      := 0;
  FActiveColor     := $223344;
  FInactiveColor   := $111111;
  FBorderColor     := $445566;
  FActiveTextColor := $FFFFFF;
  FInactiveTextColor := $555566;
  FGlowColor       := 0;
  FTick            := 0;
  SetLength(FSlotIcons, slotCount);
  SetLength(FSlotKeys,  slotCount);
  for i := 0 to slotCount - 1 do
  begin
    FSlotIcons[i] := nil;
    FSlotKeys[i]  := IntToStr(i + 1);
  end;
  FSlotW := 48;
  FSlotH := 48;
end;

procedure TWeaponSlotBar.SetActiveSlot(slot: Integer);
begin
  if (slot >= 0) and (slot < FSlotCount) then
    FActiveSlot := slot;
end;

procedure TWeaponSlotBar.SetSlotIcon(slot: Integer; img: IImage);
begin
  if (slot >= 0) and (slot < FSlotCount) then
    FSlotIcons[slot] := img;
end;

procedure TWeaponSlotBar.SetSlotKey(slot: Integer; const key: String);
begin
  if (slot >= 0) and (slot < FSlotCount) then
    FSlotKeys[slot] := key;
end;

procedure TWeaponSlotBar.SetColors(active, inactive, border, glowColor: LongWord;
                                    activeText, inactiveText: LongWord);
begin
  FActiveColor       := active;
  FInactiveColor     := inactive;
  FBorderColor       := border;
  FGlowColor         := glowColor;
  FActiveTextColor   := activeText;
  FInactiveTextColor := inactiveText;
end;

procedure TWeaponSlotBar.SetFont(f: IFont);
begin
  FFont := f;
end;

procedure TWeaponSlotBar.Update(dt: Single);
begin
  inherited Update(dt);
  FTick := FTick + dt;
  if FTick > 1000 then FTick := FTick - 1000;
end;

procedure TWeaponSlotBar.Render(r: IRenderer);
var
  b:     TRect;
  i:     Integer;
  sw, sh, gap, totalW: Integer;
  sx, sy: Integer;
  slotR:  TRect;
  isAct:  Boolean;
  bgCol, brdCol: LongWord;
  keyStr: String;
  sz:     TPoint;
  pulseA: Byte;
  imgR:   TRect;
begin
  if r = nil then Exit;
  b  := GetBounds;
  sh := b.h;
  sw := sh;   // square slots
  gap := 4;
  totalW := FSlotCount * sw + (FSlotCount - 1) * gap;
  sx := b.x + (b.w - totalW) div 2;
  sy := b.y;

  for i := 0 to FSlotCount - 1 do
  begin
    slotR := MakeRect(sx + i * (sw + gap), sy, sw, sh);
    isAct := (i = FActiveSlot);
    bgCol  := IfThen(isAct, FActiveColor,   FInactiveColor);
    brdCol := IfThen(isAct, FGlowColor,     FBorderColor);
    if brdCol = 0 then brdCol := FBorderColor;

    // Glow for active slot
    if isAct and (FGlowColor <> 0) then
    begin
      pulseA := 40 + Round(30 * ((Sin(FTick * 5.0) + 1.0) * 0.5));
      r.PushBlendAdd;
      r.DrawRoundRect(MakeRect(slotR.x - 3, slotR.y - 3, slotR.w + 6, slotR.h + 6),
                      5, (LongWord(pulseA) shl 24) or (FGlowColor and $FFFFFF), True);
      r.PopBlend;
    end;

    r.DrawRoundRect(slotR, 4, bgCol, True);
    r.DrawRoundRect(slotR, 4, brdCol, False);

    // Icon
    if FSlotIcons[i] <> nil then
    begin
      imgR := MakeRect(slotR.x + 4, slotR.y + 4, sw - 8, sh - 14);
      r.DrawImage(FSlotIcons[i],
        MakeRect(0, 0, FSlotIcons[i].GetWidth, FSlotIcons[i].GetHeight), imgR);
    end;

    // Key label
    if FFont <> nil then
    begin
      keyStr := FSlotKeys[i];
      sz := FFont.MeasureText(keyStr);
      r.DrawText(FFont, keyStr,
                 slotR.x + (sw - sz.x) div 2,
                 slotR.y + sh - sz.y - 2,
                 IfThen(isAct, FActiveTextColor, FInactiveTextColor));
    end;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TObjectivePanel
// ─────────────────────────────────────────────────────────────────────────────

constructor TObjectivePanel.Create(const aID: String);
begin
  inherited Create(aID);
  FTitle       := 'OBJECTIVE';
  FBody        := '';
  FTitleColor  := $FFAA00;
  FBodyColor   := $CCCCCC;
  FBgColor     := $0D0D0D;
  FBorderColor := $333333;
  FCornerRad   := 6;
end;

procedure TObjectivePanel.SetText(const title, body: String);
begin
  FTitle := title;
  FBody  := body;
end;

procedure TObjectivePanel.SetColors(bg, border, titleColor, bodyColor: LongWord);
begin
  FBgColor     := bg;
  FBorderColor := border;
  FTitleColor  := titleColor;
  FBodyColor   := bodyColor;
end;

procedure TObjectivePanel.SetFonts(titleFont, bodyFont: IFont);
begin
  FTitleFont := titleFont;
  FBodyFont  := bodyFont;
end;

procedure TObjectivePanel.SetCornerRadius(rad: Integer);
begin
  FCornerRad := rad;
end;

procedure TObjectivePanel.Render(r: IRenderer);
var
  b:   TRect;
  ty, by_: Integer;
  sz:  TPoint;
  pad: Integer;
begin
  if r = nil then Exit;
  b   := GetBounds;
  pad := 8;

  r.DrawRoundRect(b, FCornerRad, FBgColor, True);
  r.DrawRoundRect(b, FCornerRad, FBorderColor, False);

  ty := b.y + pad;

  if (FTitleFont <> nil) and (FTitle <> '') then
  begin
    sz := FTitleFont.MeasureText(FTitle);
    r.DrawText(FTitleFont, FTitle, b.x + pad, ty, FTitleColor);
    by_ := ty + sz.y + 3;
  end
  else
    by_ := ty;

  if (FBodyFont <> nil) and (FBody <> '') then
    r.DrawText(FBodyFont, FBody, b.x + pad, by_, FBodyColor);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  THUDFrame
// ─────────────────────────────────────────────────────────────────────────────

constructor THUDFrame.Create(const aID: String);
begin
  inherited Create(aID);
  FBgColor     := $080808;
  FBorderColor := $333333;
  FGlowColor   := 0;
  FGlowRadius  := 6;
  FCornerRad   := 12;
  FUse9Slice   := False;
  FTick        := 0;
  FPulse       := False;
end;

procedure THUDFrame.SetColors(bg, border, glowColor: LongWord; glowRadius: Integer);
begin
  FBgColor     := bg;
  FBorderColor := border;
  FGlowColor   := glowColor;
  FGlowRadius  := glowRadius;
end;

procedure THUDFrame.SetCornerRadius(r: Integer);
begin
  FCornerRad := r;
end;

procedure THUDFrame.SetBgImage(img: IImage; margins: T9SliceMargins);
begin
  FBgImage   := img;
  FBgMargins := margins;
  FUse9Slice := True;
end;

procedure THUDFrame.EnablePulse(on: Boolean);
begin
  FPulse := on;
end;

procedure THUDFrame.Update(dt: Single);
begin
  inherited Update(dt);
  FTick := FTick + dt;
  if FTick > 1000 then FTick := FTick - 1000;
end;

procedure THUDFrame.Render(r: IRenderer);
var
  b:       TRect;
  i:       Integer;
  gBnd:    TRect;
  pulseK:  Single;
  glowA:   Byte;
  gCol:    LongWord;
  sR:      TRect;
begin
  if r = nil then Exit;
  b := GetBounds;

  // Glow halo
  if (FGlowColor <> 0) and (FGlowRadius > 0) then
  begin
    pulseK := 1.0;
    if FPulse then
      pulseK := 0.5 + 0.5 * ((Sin(FTick * 3.0) + 1.0) * 0.5);
    r.PushBlendAdd;
    for i := FGlowRadius downto 1 do
    begin
      glowA := Trunc(45.0 * pulseK * i / FGlowRadius);
      if glowA < 1 then Continue;
      gBnd := MakeRect(b.x - i, b.y - i, b.w + 2*i, b.h + 2*i);
      gCol := (LongWord(glowA) shl 24) or (FGlowColor and $FFFFFF);
      r.DrawRoundRect(gBnd, FCornerRad + i, gCol, True);
    end;
    r.PopBlend;
  end;

  // Background
  if FUse9Slice and (FBgImage <> nil) then
  begin
    sR := MakeRect(0, 0, FBgImage.GetWidth, FBgImage.GetHeight);
    r.Draw9Slice(FBgImage, sR, b, FBgMargins);
  end
  else
  begin
    r.DrawRoundRect(b, FCornerRad, FBgColor, True);
  end;

  // Border
  if FBorderColor <> 0 then
    r.DrawRoundRect(b, FCornerRad, FBorderColor, False);

  // Then children are rendered by the widget system
  inherited Render(r);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TStatBar
// ─────────────────────────────────────────────────────────────────────────────

constructor TStatBar.Create(const aID: String);
begin
  inherited Create(aID);
  FValue       := 1.0;
  FColor       := $44AA44;
  FBgColor     := $111111;
  FBorderColor := $333333;
  FGlowColor   := 0;
  FLabelColor  := $888888;
  FCornerRad   := 3;
  FTick        := 0;
  FPulse       := False;
end;

procedure TStatBar.SetValue(v: Single);
begin
  if v < 0 then v := 0;
  if v > 1 then v := 1;
  FValue := v;
end;

procedure TStatBar.SetColors(fillColor, bgColor, borderColor, glowColor: LongWord);
begin
  FColor       := fillColor;
  FBgColor     := bgColor;
  FBorderColor := borderColor;
  FGlowColor   := glowColor;
end;

procedure TStatBar.SetLabel(const s: String; f: IFont; labelColor: LongWord);
begin
  FLabel      := s;
  FFont       := f;
  FLabelColor := labelColor;
end;

procedure TStatBar.SetCornerRadius(r: Integer);
begin
  FCornerRad := r;
end;

procedure TStatBar.EnablePulse(on: Boolean);
begin
  FPulse := on;
end;

procedure TStatBar.Update(dt: Single);
begin
  inherited Update(dt);
  FTick := FTick + dt;
  if FTick > 1000 then FTick := FTick - 1000;
end;

procedure TStatBar.Render(r: IRenderer);
var
  b:     TRect;
  fillW: Integer;
  fillR: TRect;
  pulseK: Single;
  glowA:  Byte;
  gR:     TRect;
  i:      Integer;
  lx, ly: Integer;
  sz:     TPoint;
begin
  if r = nil then Exit;
  b := GetBounds;

  // Background track
  r.DrawRoundRect(b, FCornerRad, FBgColor, True);

  // Fill
  fillW := Round((b.w - 2) * FValue);
  if fillW > 0 then
  begin
    fillR := MakeRect(b.x + 1, b.y + 1, fillW, b.h - 2);

    // Glow under fill
    if (FGlowColor <> 0) then
    begin
      pulseK := 1.0;
      if FPulse then
        pulseK := 0.6 + 0.4 * ((Sin(FTick * 4.0) + 1.0) * 0.5);
      r.PushBlendAdd;
      for i := 3 downto 1 do
      begin
        glowA := Trunc(50.0 * pulseK * i / 3);
        gR := MakeRect(fillR.x - i, fillR.y - i, fillR.w + 2*i, fillR.h + 2*i);
        r.DrawRoundRect(gR, FCornerRad + i,
                        (LongWord(glowA) shl 24) or (FGlowColor and $FFFFFF), True);
      end;
      r.PopBlend;
    end;

    r.DrawRoundRect(fillR, FCornerRad, FColor, True);
  end;

  // Border
  r.DrawRoundRect(b, FCornerRad, FBorderColor, False);

  // Label
  if (FFont <> nil) and (FLabel <> '') then
  begin
    sz := FFont.MeasureText(FLabel);
    lx := b.x + 4;
    ly := b.y + (b.h - sz.y) div 2;
    r.DrawText(FFont, FLabel, lx, ly, FLabelColor);
  end;
end;

end.
