unit SkinSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Contnrs,
  Core.Contracts, ResourceManager;

// ─────────────────────────────────────────────────────────────────────────────
//  TColorSkin  — flat colored panel (original, updated for new TWidgetState)
// ─────────────────────────────────────────────────────────────────────────────
type
  TColorSkin = class(ISkin)
  private
    FColors:      array[TWidgetState] of LongWord;
    FBorderColor: LongWord;
  public
    constructor Create(normalColor, hoverColor, activeColor, disabledColor,
                       borderColor: LongWord);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function  GetTextColor(state: TWidgetState): LongWord; override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TImageSkin  — per-state image (original)
// ─────────────────────────────────────────────────────────────────────────────
  TImageSkin = class(ISkin)
  private
    FImages:     array[TWidgetState] of IImage;
    FTextColors: array[TWidgetState] of LongWord;
  public
    constructor Create(rm: TResourceManager;
                       const normalPath, hoverPath, activePath, disabledPath: String);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function  GetTextColor(state: TWidgetState): LongWord; override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TSkinLayer  — one rendering pass inside TLayeredSkin
// ─────────────────────────────────────────────────────────────────────────────
  TSkinLayer = record
    image:     IImage;       // nil = solid color
    color:     LongWord;     // used when image = nil
    blendMode: TBlendMode;
    alpha:     Byte;         // 0..255
    expand:    Integer;      // pixels to expand bounds (glow bloat)
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TLayeredSkin  — multiple draw passes, blend modes, glow
// ─────────────────────────────────────────────────────────────────────────────
  TLayeredSkin = class(ISkin)
  private
    FLayers:    array of TSkinLayer;
    FTextColor: LongWord;
    FCornerRad: Integer;
  public
    constructor Create(textColor: LongWord = $FFFFFF; cornerRadius: Integer = 0);
    // Add a solid-color layer (image=nil)
    procedure AddColorLayer(color: LongWord; blendMode: TBlendMode = bmNormal;
                            alpha: Byte = 255; expand: Integer = 0);
    // Add an image layer
    procedure AddImageLayer(img: IImage; blendMode: TBlendMode = bmNormal;
                            alpha: Byte = 255; expand: Integer = 0);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function  GetTextColor(state: TWidgetState): LongWord; override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TGlowColorSkin  — colored panel with animated additive glow halo
// ─────────────────────────────────────────────────────────────────────────────
  TGlowColorSkin = class(ISkin)
  private
    FBaseColor:   LongWord;
    FGlowColor:   LongWord;
    FBorderColor: LongWord;
    FTextColor:   LongWord;
    FGlowRadius:  Integer;
    FCornerRad:   Integer;
    FPulse:       Boolean;
    FTick:        Single;   // accumulated seconds
  public
    constructor Create(baseColor, glowColor, borderColor, textColor: LongWord;
                       glowRadius: Integer = 6; cornerRadius: Integer = 8;
                       pulse: Boolean = False);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function  GetTextColor(state: TWidgetState): LongWord; override;
    procedure Tick(dt: Single); override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TAnimatedBorderSkin  — dark panel + animated glowing border scanline
// ─────────────────────────────────────────────────────────────────────────────
  TAnimatedBorderSkin = class(ISkin)
  private
    FBgColor:    LongWord;
    FLineColor:  LongWord;
    FTextColor:  LongWord;
    FTick:       Single;
    FSpeed:      Single;
    FThickness:  Integer;
    FCornerRad:  Integer;
  public
    constructor Create(bgColor, lineColor, textColor: LongWord;
                       thickness: Integer = 2; cornerRadius: Integer = 8;
                       speed: Single = 2.0);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function  GetTextColor(state: TWidgetState): LongWord; override;
    procedure Tick(dt: Single); override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
//  TSkinManager
// ─────────────────────────────────────────────────────────────────────────────
  TSkinManager = class
  private
    FSkinsMap: TFPHashMap;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure RegisterSkin(const name: String; skin: ISkin);
    function  GetSkin(const name: String): ISkin;
    procedure LoadDefaultSkins(rm: TResourceManager);
  end;

var
  GlobalSkinManager: TSkinManager = nil;

implementation

// ─────────────────────────────────────────────────────────────────────────────
//  TColorSkin
// ─────────────────────────────────────────────────────────────────────────────

constructor TColorSkin.Create(normalColor, hoverColor, activeColor,
                               disabledColor, borderColor: LongWord);
begin
  inherited Create;
  FColors[wsNormal]   := normalColor;
  FColors[wsHover]    := hoverColor;
  FColors[wsActive]   := activeColor;
  FColors[wsDisabled] := disabledColor;
  // Extended states — sensible defaults
  FColors[wsWarning]  := $AAAA00;
  FColors[wsCritical] := $CC0000;
  FColors[wsLocked]   := disabledColor;
  FColors[wsCooldown] := $334455;
  FColors[wsSelected] := activeColor;
  FBorderColor := borderColor;
end;

procedure TColorSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
begin
  if r = nil then Exit;
  r.DrawFilledRect(bounds, FColors[state]);
  if FBorderColor <> 0 then
    r.DrawRect(bounds, FBorderColor);
end;

function TColorSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  case state of
    wsNormal:   Result := $FFFFFF;
    wsHover:    Result := $FFFF00;
    wsActive:   Result := $FF8800;
    wsDisabled: Result := $888888;
    wsWarning:  Result := $FFEE00;
    wsCritical: Result := $FF4444;
    wsLocked:   Result := $666666;
    wsCooldown: Result := $8899AA;
    wsSelected: Result := $FFFFFF;
  else
    Result := $FFFFFF;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TImageSkin
// ─────────────────────────────────────────────────────────────────────────────

constructor TImageSkin.Create(rm: TResourceManager;
                               const normalPath, hoverPath, activePath, disabledPath: String);
var
  s: TWidgetState;
begin
  inherited Create;
  for s := Low(TWidgetState) to High(TWidgetState) do
    FTextColors[s] := $FFFFFF;
  if rm = nil then Exit;
  FImages[wsNormal]   := rm.GetImage(normalPath);
  FImages[wsHover]    := rm.GetImage(hoverPath);
  FImages[wsActive]   := rm.GetImage(activePath);
  FImages[wsDisabled] := rm.GetImage(disabledPath);
  // Extended states — reuse normal
  FImages[wsWarning]  := FImages[wsNormal];
  FImages[wsCritical] := FImages[wsNormal];
  FImages[wsLocked]   := FImages[wsDisabled];
  FImages[wsCooldown] := FImages[wsNormal];
  FImages[wsSelected] := FImages[wsActive];
end;

procedure TImageSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
var
  img: IImage;
  sR:  TRect;
begin
  if r = nil then Exit;
  img := FImages[state];
  if img = nil then Exit;
  sR.x := 0; sR.y := 0;
  sR.w := img.GetWidth; sR.h := img.GetHeight;
  r.DrawImage(img, sR, bounds);
end;

function TImageSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  Result := FTextColors[state];
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TLayeredSkin
// ─────────────────────────────────────────────────────────────────────────────

constructor TLayeredSkin.Create(textColor: LongWord; cornerRadius: Integer);
begin
  inherited Create;
  FTextColor := textColor;
  FCornerRad := cornerRadius;
end;

procedure TLayeredSkin.AddColorLayer(color: LongWord; blendMode: TBlendMode;
                                     alpha: Byte; expand: Integer);
var
  lay: TSkinLayer;
begin
  lay.image     := nil;
  lay.color     := color;
  lay.blendMode := blendMode;
  lay.alpha     := alpha;
  lay.expand    := expand;
  SetLength(FLayers, Length(FLayers) + 1);
  FLayers[High(FLayers)] := lay;
end;

procedure TLayeredSkin.AddImageLayer(img: IImage; blendMode: TBlendMode;
                                     alpha: Byte; expand: Integer);
var
  lay: TSkinLayer;
begin
  lay.image     := img;
  lay.color     := 0;
  lay.blendMode := blendMode;
  lay.alpha     := alpha;
  lay.expand    := expand;
  SetLength(FLayers, Length(FLayers) + 1);
  FLayers[High(FLayers)] := lay;
end;

procedure TLayeredSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
var
  i:    Integer;
  lay:  TSkinLayer;
  bnd:  TRect;
  sR:   TRect;
  col:  LongWord;
begin
  if r = nil then Exit;
  for i := 0 to High(FLayers) do
  begin
    lay := FLayers[i];
    bnd.x := bounds.x - lay.expand;
    bnd.y := bounds.y - lay.expand;
    bnd.w := bounds.w + 2 * lay.expand;
    bnd.h := bounds.h + 2 * lay.expand;

    if lay.blendMode = bmAdd then
      r.PushBlendAdd;

    if lay.image <> nil then
    begin
      if (lay.alpha = 255) and (lay.blendMode = bmNormal) then
      begin
        sR.x := 0; sR.y := 0;
        sR.w := lay.image.GetWidth; sR.h := lay.image.GetHeight;
        r.DrawImage(lay.image, sR, bnd);
      end
      else
        r.DrawImageBlended(lay.image,
          MakeRect(0,0, lay.image.GetWidth, lay.image.GetHeight),
          bnd, lay.alpha, lay.blendMode);
    end
    else
    begin
      // solid color — encode alpha into high byte
      col := (LongWord(lay.alpha) shl 24) or (lay.color and $00FFFFFF);
      if FCornerRad > 0 then
        r.DrawRoundRect(bnd, FCornerRad, col, True)
      else
        r.DrawFilledRect(bnd, col);
    end;

    if lay.blendMode = bmAdd then
      r.PopBlend;
  end;
end;

function TLayeredSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  Result := FTextColor;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TGlowColorSkin
// ─────────────────────────────────────────────────────────────────────────────

constructor TGlowColorSkin.Create(baseColor, glowColor, borderColor,
                                   textColor: LongWord;
                                   glowRadius, cornerRadius: Integer;
                                   pulse: Boolean);
begin
  inherited Create;
  FBaseColor   := baseColor;
  FGlowColor   := glowColor;
  FBorderColor := borderColor;
  FTextColor   := textColor;
  FGlowRadius  := glowRadius;
  FCornerRad   := cornerRadius;
  FPulse       := pulse;
  FTick        := 0;
end;

procedure TGlowColorSkin.Tick(dt: Single);
begin
  FTick := FTick + dt;
  if FTick > 1000 then FTick := FTick - 1000; // prevent overflow
end;

procedure TGlowColorSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
var
  i:       Integer;
  gBnd:    TRect;
  pulseK:  Single;
  glowA:   Byte;
  gCol:    LongWord;
begin
  if r = nil then Exit;

  // Additive glow halo: concentric rounded rects decreasing alpha outward
  if FGlowRadius > 0 then
  begin
    pulseK := 1.0;
    if FPulse then
      pulseK := 0.6 + 0.4 * ((Sin(FTick * 4.0) + 1.0) * 0.5);

    r.PushBlendAdd;
    for i := FGlowRadius downto 1 do
    begin
      glowA := Trunc(50.0 * pulseK * (i / FGlowRadius));
      if glowA < 1 then Continue;
      gBnd.x := bounds.x - i;  gBnd.y := bounds.y - i;
      gBnd.w := bounds.w + 2*i; gBnd.h := bounds.h + 2*i;
      gCol := (LongWord(glowA) shl 24) or (FGlowColor and $00FFFFFF);
      if FCornerRad > 0 then
        r.DrawRoundRect(gBnd, FCornerRad + i, gCol, True)
      else
        r.DrawFilledRect(gBnd, gCol);
    end;
    r.PopBlend;
  end;

  // Base panel
  if FCornerRad > 0 then
    r.DrawRoundRect(bounds, FCornerRad, FBaseColor, True)
  else
    r.DrawFilledRect(bounds, FBaseColor);

  // Border
  if FBorderColor <> 0 then
  begin
    if FCornerRad > 0 then
      r.DrawRoundRect(bounds, FCornerRad, FBorderColor, False)
    else
      r.DrawRect(bounds, FBorderColor);
  end;
end;

function TGlowColorSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  Result := FTextColor;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TAnimatedBorderSkin
// ─────────────────────────────────────────────────────────────────────────────

constructor TAnimatedBorderSkin.Create(bgColor, lineColor, textColor: LongWord;
                                       thickness, cornerRadius: Integer;
                                       speed: Single);
begin
  inherited Create;
  FBgColor   := bgColor;
  FLineColor := lineColor;
  FTextColor := textColor;
  FTick      := 0;
  FSpeed     := speed;
  FThickness := thickness;
  FCornerRad := cornerRadius;
end;

procedure TAnimatedBorderSkin.Tick(dt: Single);
begin
  FTick := FTick + dt * FSpeed;
  if FTick > 1000 then FTick := FTick - 1000;
end;

procedure TAnimatedBorderSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
var
  i:      Integer;
  alpha:  Byte;
  bnd:    TRect;
  phase:  Single;
begin
  if r = nil then Exit;
  // Background
  if FCornerRad > 0 then
    r.DrawRoundRect(bounds, FCornerRad, FBgColor, True)
  else
    r.DrawFilledRect(bounds, FBgColor);

  // Animated glowing border — multiple thickness passes + pulsing alpha
  phase := (Sin(FTick * 2.0) + 1.0) * 0.5;   // 0..1
  r.PushBlendAdd;
  for i := FThickness downto 1 do
  begin
    alpha := Trunc(120.0 * phase * i / FThickness);
    bnd.x := bounds.x - i + 1;  bnd.y := bounds.y - i + 1;
    bnd.w := bounds.w + 2*(i-1); bnd.h := bounds.h + 2*(i-1);
    if FCornerRad > 0 then
      r.DrawRoundRect(bnd, FCornerRad + i - 1,
                      (LongWord(alpha) shl 24) or (FLineColor and $FFFFFF), False)
    else
      r.DrawRect(bnd, (LongWord(alpha) shl 24) or (FLineColor and $FFFFFF));
  end;
  r.PopBlend;
end;

function TAnimatedBorderSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  Result := FTextColor;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TSkinManager
// ─────────────────────────────────────────────────────────────────────────────

constructor TSkinManager.Create;
begin
  inherited Create;
  FSkinsMap := TFPHashMap.Create;
end;

destructor TSkinManager.Destroy;
begin
  FSkinsMap.Free;
  inherited Destroy;
end;

procedure TSkinManager.RegisterSkin(const name: String; skin: ISkin);
begin
  if skin = nil then Exit;
  FSkinsMap.Add(LowerCase(name), TObject(skin));
end;

function TSkinManager.GetSkin(const name: String): ISkin;
var
  obj: TObject;
begin
  Result := nil;
  obj := TObject(FSkinsMap.Find(LowerCase(name)));
  if obj <> nil then Result := ISkin(obj);
end;

procedure TSkinManager.LoadDefaultSkins(rm: TResourceManager);
begin
  RegisterSkin('default', TColorSkin.Create($2A2A2A, $3A3A3A, $555555, $1A1A1A, $555555));
  RegisterSkin('dark',    TColorSkin.Create($1A1A1A, $252525, $333333, $111111, $444444));
  RegisterSkin('blue',    TColorSkin.Create($1A2A4A, $2A3A5A, $3A5A8A, $0A1A2A, $3A6AAA));
  RegisterSkin('red',     TColorSkin.Create($3A0A0A, $4A1A1A, $6A2A2A, $1A0000, $AA3333));
  RegisterSkin('green',   TColorSkin.Create($0A2A0A, $1A3A1A, $2A5A2A, $001A00, $33AA33));

  // Neon/glow skins
  RegisterSkin('neon_pink',
    TGlowColorSkin.Create($0A0018, $FF00BB, $FF00BB, $FF88EE, 8, 10, True));
  RegisterSkin('neon_cyan',
    TGlowColorSkin.Create($001018, $00FFEE, $00FFEE, $88FFEE, 8, 10, True));
  RegisterSkin('alien',
    TGlowColorSkin.Create($021202, $00FF44, $00CC33, $88FFAA, 8, 6, True));
  RegisterSkin('amber',
    TGlowColorSkin.Create($180A00, $FFAA00, $CC8800, $FFDDAA, 6, 8, False));
  RegisterSkin('ice',
    TGlowColorSkin.Create($001828, $44BBFF, $2299DD, $AADDFF, 8, 10, True));
  RegisterSkin('inferno',
    TGlowColorSkin.Create($180000, $FF3300, $CC2200, $FF8866, 8, 6, True));

  RegisterSkin('tactical',
    TColorSkin.Create($141408, $1E1E10, $2A2A14, $0A0A04, $445500));
end;

initialization
  GlobalSkinManager := TSkinManager.Create;

finalization
  GlobalSkinManager.Free;

end.
