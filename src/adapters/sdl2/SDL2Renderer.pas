unit SDL2Renderer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math,
  SDL2, SDL2_ttf,
  Core.Contracts;

type
  TSDL2Renderer = class(IRenderer)
  private
    FWindow:   PSDL_Window;
    FRenderer: PSDL_Renderer;
    FHasClip:  Boolean;
    FClipRect: TRect;
    FWidth, FHeight: Integer;

    procedure SetColor(color: LongWord);
    procedure SetColorBlend(color: LongWord; blendMode: SDL_BlendMode);
    function  ToSDLRect(r: TRect): TSDL_Rect;

    // Internal primitives
    procedure InternalDrawCirclePoints(cx, cy, x, y: Integer);
    procedure InternalFillCircleSpans(cx, cy, x, y: Integer);

    // Private unused
    function MapColor(color: LongWord): UInt32;
  public
    constructor Create(window: PSDL_Window; renderer: PSDL_Renderer);
    constructor CreateWithWindow(const title: String; width, height: Integer);
    destructor  Destroy; override;

    // ── Blend ─────────────────────────────────────────────────────────────
    procedure PushBlendAdd; override;
    procedure PopBlend;     override;

    // ── Primitives ────────────────────────────────────────────────────────
    procedure DrawRect(r: TRect; color: LongWord); override;
    procedure DrawFilledRect(r: TRect; color: LongWord); override;
    procedure DrawLine(x1, y1, x2, y2: Integer; color: LongWord); override;

    // ── Circles & arcs ────────────────────────────────────────────────────
    procedure DrawCircle(cx, cy, radius: Integer; color: LongWord); override;
    procedure DrawFilledCircle(cx, cy, radius: Integer; color: LongWord); override;
    procedure DrawArc(cx, cy, radius, startDeg, endDeg: Integer;
                      color: LongWord; thickness: Integer = 1); override;

    // ── Rounded rect ──────────────────────────────────────────────────────
    procedure DrawRoundRect(r: TRect; radius: Integer; color: LongWord;
                            filled: Boolean = False); override;

    // ── Images ────────────────────────────────────────────────────────────
    procedure DrawImage(img: IImage; src, dst: TRect); override;
    procedure DrawImageBlended(img: IImage; src, dst: TRect;
                               alpha: Byte; blendMode: TBlendMode = bmNormal); override;
    procedure Draw9Slice(img: IImage; src, dst: TRect;
                         margins: T9SliceMargins); override;

    // ── Text ──────────────────────────────────────────────────────────────
    procedure DrawText(font: IFont; const text: String;
                       x, y: Integer; color: LongWord); override;

    // ── Clip ──────────────────────────────────────────────────────────────
    procedure SetClipRect(r: TRect); override;
    procedure ClearClipRect; override;

    // ── Frame ─────────────────────────────────────────────────────────────
    procedure BeginFrame; override;
    procedure EndFrame;   override;

    function GetWindow:   PSDL_Window;
    function GetRenderer: PSDL_Renderer;
    function GetWidth:    Integer;
    function GetHeight:   Integer;
  end;

implementation

uses Logger;

// ─────────────────────────────────────────────────────────────────────────────
//  Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.SetColor(color: LongWord);
var
  r, g, b, a: UInt8;
begin
  r := (color shr 16) and $FF;
  g := (color shr 8)  and $FF;
  b :=  color         and $FF;
  a := (color shr 24) and $FF;
  if a = 0 then a := 255;
  SDL_SetRenderDrawColor(FRenderer, r, g, b, a);
end;

procedure TSDL2Renderer.SetColorBlend(color: LongWord; blendMode: SDL_BlendMode);
begin
  SDL_SetRenderDrawBlendMode(FRenderer, blendMode);
  SetColor(color);
end;

function TSDL2Renderer.ToSDLRect(r: TRect): TSDL_Rect;
begin
  Result.x := r.x; Result.y := r.y; Result.w := r.w; Result.h := r.h;
end;

function TSDL2Renderer.MapColor(color: LongWord): UInt32;
begin
  Result := color; // unused
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Constructor / Destructor
// ─────────────────────────────────────────────────────────────────────────────

constructor TSDL2Renderer.Create(window: PSDL_Window; renderer: PSDL_Renderer);
begin
  inherited Create;
  FWindow   := window;
  FRenderer := renderer;
  FHasClip  := False;
  if FWindow <> nil then
    SDL_GetWindowSize(FWindow, @FWidth, @FHeight);
  SDL_SetRenderDrawBlendMode(FRenderer, SDL_BLENDMODE_BLEND);
end;

constructor TSDL2Renderer.CreateWithWindow(const title: String; width, height: Integer);
begin
  FWidth  := width;
  FHeight := height;

  FWindow := SDL_CreateWindow(PChar(title),
    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
    width, height, SDL_WINDOW_SHOWN);
  if FWindow = nil then
    raise Exception.Create('SDL_CreateWindow: ' + SDL_GetError);

  FRenderer := SDL_CreateRenderer(FWindow, -1,
    SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
  if FRenderer = nil then
  begin
    FRenderer := SDL_CreateRenderer(FWindow, -1, SDL_RENDERER_SOFTWARE);
    if FRenderer = nil then
    begin
      SDL_DestroyWindow(FWindow); FWindow := nil;
      raise Exception.Create('SDL_CreateRenderer: ' + SDL_GetError);
    end;
  end;

  FHasClip := False;
  SDL_SetRenderDrawBlendMode(FRenderer, SDL_BLENDMODE_BLEND);
end;

destructor TSDL2Renderer.Destroy;
begin
  if FRenderer <> nil then SDL_DestroyRenderer(FRenderer);
  if FWindow   <> nil then SDL_DestroyWindow(FWindow);
  inherited Destroy;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Blend control
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.PushBlendAdd;
begin
  SDL_SetRenderDrawBlendMode(FRenderer, SDL_BLENDMODE_ADD);
end;

procedure TSDL2Renderer.PopBlend;
begin
  SDL_SetRenderDrawBlendMode(FRenderer, SDL_BLENDMODE_BLEND);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Primitives
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.DrawRect(r: TRect; color: LongWord);
var
  sdlR: TSDL_Rect;
begin
  if (FRenderer = nil) or (r.w <= 0) or (r.h <= 0) then Exit;
  SetColorBlend(color, SDL_BLENDMODE_BLEND);
  sdlR := ToSDLRect(r);
  SDL_RenderDrawRect(FRenderer, @sdlR);
end;

procedure TSDL2Renderer.DrawFilledRect(r: TRect; color: LongWord);
var
  sdlR: TSDL_Rect;
  a: UInt8;
begin
  if (FRenderer = nil) or (r.w <= 0) or (r.h <= 0) then Exit;
  a := (color shr 24) and $FF;
  if a = 0 then
    SetColorBlend(color, SDL_BLENDMODE_NONE)
  else
    SetColorBlend(color, SDL_BLENDMODE_BLEND);
  SetColor(color);
  sdlR := ToSDLRect(r);
  SDL_RenderFillRect(FRenderer, @sdlR);
end;

procedure TSDL2Renderer.DrawLine(x1, y1, x2, y2: Integer; color: LongWord);
begin
  if FRenderer = nil then Exit;
  SetColorBlend(color, SDL_BLENDMODE_BLEND);
  SDL_RenderDrawLine(FRenderer, x1, y1, x2, y2);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Circles (Bresenham midpoint)
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.InternalDrawCirclePoints(cx, cy, x, y: Integer);
begin
  SDL_RenderDrawPoint(FRenderer, cx + x, cy + y);
  SDL_RenderDrawPoint(FRenderer, cx - x, cy + y);
  SDL_RenderDrawPoint(FRenderer, cx + x, cy - y);
  SDL_RenderDrawPoint(FRenderer, cx - x, cy - y);
  SDL_RenderDrawPoint(FRenderer, cx + y, cy + x);
  SDL_RenderDrawPoint(FRenderer, cx - y, cy + x);
  SDL_RenderDrawPoint(FRenderer, cx + y, cy - x);
  SDL_RenderDrawPoint(FRenderer, cx - y, cy - x);
end;

procedure TSDL2Renderer.InternalFillCircleSpans(cx, cy, x, y: Integer);
var
  sdlR: TSDL_Rect;
begin
  sdlR.x := cx - y; sdlR.y := cy - x; sdlR.w := 2*y + 1; sdlR.h := 1;
  SDL_RenderFillRect(FRenderer, @sdlR);
  sdlR.y := cy + x;
  SDL_RenderFillRect(FRenderer, @sdlR);
  if x <> 0 then
  begin
    sdlR.x := cx - x; sdlR.y := cy - y; sdlR.w := 2*x + 1; sdlR.h := 1;
    SDL_RenderFillRect(FRenderer, @sdlR);
    sdlR.y := cy + y;
    SDL_RenderFillRect(FRenderer, @sdlR);
  end;
end;

procedure TSDL2Renderer.DrawCircle(cx, cy, radius: Integer; color: LongWord);
var
  x, y, d: Integer;
begin
  if FRenderer = nil then Exit;
  SetColorBlend(color, SDL_BLENDMODE_BLEND);
  x := 0; y := radius; d := 3 - 2*radius;
  while x <= y do
  begin
    InternalDrawCirclePoints(cx, cy, x, y);
    if d < 0 then Inc(d, 4*x + 6)
    else begin Inc(d, 4*(x-y) + 10); Dec(y); end;
    Inc(x);
  end;
end;

procedure TSDL2Renderer.DrawFilledCircle(cx, cy, radius: Integer; color: LongWord);
var
  x, y, d: Integer;
begin
  if FRenderer = nil then Exit;
  SetColorBlend(color, SDL_BLENDMODE_BLEND);
  x := 0; y := radius; d := 1 - radius;
  while x <= y do
  begin
    InternalFillCircleSpans(cx, cy, x, y);
    if d < 0 then Inc(d, 2*x + 3)
    else begin Inc(d, 2*(x-y) + 5); Dec(y); end;
    Inc(x);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Arc  (trigonometric, ~1px angular steps)
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.DrawArc(cx, cy, radius, startDeg, endDeg: Integer;
                                color: LongWord; thickness: Integer);
const
  DEG2RAD = Pi / 180.0;
var
  t, r2: Integer;
  ang, step: Double;
  px, py: Int32;
begin
  if (FRenderer = nil) or (radius <= 0) then Exit;
  SetColorBlend(color, SDL_BLENDMODE_BLEND);

  // Wrap so start <= end
  if endDeg < startDeg then endDeg := endDeg + 360;

  // angular step = 1 pixel ≈ 360 / circumference
  step := 360.0 / Max(1, 2 * Pi * radius);
  if step > 1.0 then step := 1.0;

  for t := 0 to thickness - 1 do
  begin
    r2 := radius - (thickness div 2) + t;
    if r2 <= 0 then Continue;
    ang := startDeg;
    while ang <= endDeg + step * 0.5 do
    begin
      px := cx + Round(r2 * Cos(ang * DEG2RAD));
      py := cy + Round(r2 * Sin(ang * DEG2RAD));
      SDL_RenderDrawPoint(FRenderer, px, py);
      ang := ang + step;
    end;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Rounded rectangle
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.DrawRoundRect(r: TRect; radius: Integer;
                                      color: LongWord; filled: Boolean);
var
  sdlR: TSDL_Rect;
  rad: Integer;
  x, y, d: Integer;
  spanR: TSDL_Rect;

  procedure FillSpans(cx, cy, sx, sy: Integer);
  begin
    // horizontal spans for filled variant
    spanR.x := cx - sy; spanR.y := cy - sx; spanR.w := 2*sy; spanR.h := 1;
    SDL_RenderFillRect(FRenderer, @spanR);
    spanR.y := cy + sx;
    SDL_RenderFillRect(FRenderer, @spanR);
    if sx <> 0 then
    begin
      spanR.x := cx - sx; spanR.y := cy - sy; spanR.w := 2*sx; spanR.h := 1;
      SDL_RenderFillRect(FRenderer, @spanR);
      spanR.y := cy + sy;
      SDL_RenderFillRect(FRenderer, @spanR);
    end;
  end;

begin
  if FRenderer = nil then Exit;
  if radius < 1 then radius := 1;
  rad := Min(radius, Min(r.w, r.h) div 2);

  SetColorBlend(color, SDL_BLENDMODE_BLEND);

  if filled then
  begin
    // Center column
    sdlR.x := r.x + rad; sdlR.y := r.y; sdlR.w := r.w - 2*rad; sdlR.h := r.h;
    SDL_RenderFillRect(FRenderer, @sdlR);
    // Left/right strips (corners filled by circle)
    sdlR.x := r.x; sdlR.y := r.y + rad; sdlR.w := rad; sdlR.h := r.h - 2*rad;
    SDL_RenderFillRect(FRenderer, @sdlR);
    sdlR.x := r.x + r.w - rad;
    SDL_RenderFillRect(FRenderer, @sdlR);

    // Four corner circles (filled, only quarter used via span clipping)
    x := 0; y := rad; d := 1 - rad;
    while x <= y do
    begin
      FillSpans(r.x + rad,         r.y + rad,         x, y);
      FillSpans(r.x + r.w - rad,   r.y + rad,         x, y);
      FillSpans(r.x + rad,         r.y + r.h - rad,   x, y);
      FillSpans(r.x + r.w - rad,   r.y + r.h - rad,   x, y);
      if d < 0 then Inc(d, 2*x + 3)
      else begin Inc(d, 2*(x-y) + 5); Dec(y); end;
      Inc(x);
    end;
  end
  else
  begin
    // Outline: 4 arcs + 4 lines
    DrawArc(r.x + rad,       r.y + rad,       rad, 180, 270, color, 1);
    DrawArc(r.x + r.w - rad, r.y + rad,       rad, 270, 360, color, 1);
    DrawArc(r.x + r.w - rad, r.y + r.h - rad, rad,   0,  90, color, 1);
    DrawArc(r.x + rad,       r.y + r.h - rad, rad,  90, 180, color, 1);
    SDL_RenderDrawLine(FRenderer, r.x + rad,       r.y,           r.x + r.w - rad, r.y);
    SDL_RenderDrawLine(FRenderer, r.x + rad,       r.y + r.h,     r.x + r.w - rad, r.y + r.h);
    SDL_RenderDrawLine(FRenderer, r.x,             r.y + rad,     r.x,             r.y + r.h - rad);
    SDL_RenderDrawLine(FRenderer, r.x + r.w,       r.y + rad,     r.x + r.w,       r.y + r.h - rad);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Images
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.DrawImage(img: IImage; src, dst: TRect);
var
  tex: PSDL_Texture;
  sR, dR: TSDL_Rect;
begin
  if FRenderer = nil then Exit;
  if (img = nil) or (img.GetHandle = nil) then
  begin
    DrawFilledRect(dst, $FFFF00FF);
    Exit;
  end;
  tex := PSDL_Texture(img.GetHandle);
  sR := ToSDLRect(src); dR := ToSDLRect(dst);
  SDL_RenderCopy(FRenderer, tex, @sR, @dR);
end;

procedure TSDL2Renderer.DrawImageBlended(img: IImage; src, dst: TRect;
                                          alpha: Byte; blendMode: TBlendMode);
var
  tex: PSDL_Texture;
  sR, dR: TSDL_Rect;
  sdlBlend: SDL_BlendMode;
begin
  if (FRenderer = nil) or (img = nil) or (img.GetHandle = nil) then Exit;
  tex := PSDL_Texture(img.GetHandle);
  case blendMode of
    bmAdd:      sdlBlend := SDL_BLENDMODE_ADD;
    bmMultiply: sdlBlend := SDL_BLENDMODE_MOD;
  else
    sdlBlend := SDL_BLENDMODE_BLEND;
  end;
  SDL_SetTextureBlendMode(tex, sdlBlend);
  SDL_SetTextureAlphaMod(tex, alpha);
  sR := ToSDLRect(src); dR := ToSDLRect(dst);
  SDL_RenderCopy(FRenderer, tex, @sR, @dR);
  // restore
  SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
  SDL_SetTextureAlphaMod(tex, 255);
end;

procedure TSDL2Renderer.Draw9Slice(img: IImage; src, dst: TRect;
                                    margins: T9SliceMargins);
var
  tex: PSDL_Texture;

  procedure Patch(sx, sy, sw, sh, dx, dy, dw, dh: Integer);
  var
    sR, dR: TSDL_Rect;
  begin
    if (sw <= 0) or (sh <= 0) or (dw <= 0) or (dh <= 0) then Exit;
    sR.x := sx; sR.y := sy; sR.w := sw; sR.h := sh;
    dR.x := dx; dR.y := dy; dR.w := dw; dR.h := dh;
    SDL_RenderCopy(FRenderer, tex, @sR, @dR);
  end;

var
  sl, st, sr, sb: Integer;
  cws, chs, cwd, chd: Integer;
begin
  if (FRenderer = nil) or (img = nil) or (img.GetHandle = nil) then Exit;
  tex := PSDL_Texture(img.GetHandle);

  sl := margins.left;  st := margins.top;
  sr := margins.right; sb := margins.bottom;
  cws := src.w - sl - sr;  chs := src.h - st - sb;
  cwd := dst.w - sl - sr;  chd := dst.h - st - sb;

  // Row 0
  Patch(src.x,          src.y,          sl,  st,  dst.x,          dst.y,          sl,  st);
  Patch(src.x+sl,       src.y,          cws, st,  dst.x+sl,       dst.y,          cwd, st);
  Patch(src.x+src.w-sr, src.y,          sr,  st,  dst.x+dst.w-sr, dst.y,          sr,  st);
  // Row 1
  Patch(src.x,          src.y+st,       sl,  chs, dst.x,          dst.y+st,       sl,  chd);
  Patch(src.x+sl,       src.y+st,       cws, chs, dst.x+sl,       dst.y+st,       cwd, chd);
  Patch(src.x+src.w-sr, src.y+st,       sr,  chs, dst.x+dst.w-sr, dst.y+st,       sr,  chd);
  // Row 2
  Patch(src.x,          src.y+src.h-sb, sl,  sb,  dst.x,          dst.y+dst.h-sb, sl,  sb);
  Patch(src.x+sl,       src.y+src.h-sb, cws, sb,  dst.x+sl,       dst.y+dst.h-sb, cwd, sb);
  Patch(src.x+src.w-sr, src.y+src.h-sb, sr,  sb,  dst.x+dst.w-sr, dst.y+dst.h-sb, sr,  sb);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Text
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.DrawText(font: IFont; const text: String;
                                  x, y: Integer; color: LongWord);
var
  ttfFont: PTTF_Font;
  sdlColor: TSDL_Color;
  surf: PSDL_Surface;
  tex:  PSDL_Texture;
  dR:   TSDL_Rect;
begin
  if (FRenderer = nil) or (text = '') then Exit;
  if (font = nil) or (font.GetHandle = nil) then Exit;

  ttfFont := PTTF_Font(font.GetHandle);
  sdlColor.r := (color shr 16) and $FF;
  sdlColor.g := (color shr 8)  and $FF;
  sdlColor.b :=  color         and $FF;
  sdlColor.a := (color shr 24) and $FF;
  if sdlColor.a = 0 then sdlColor.a := 255;

  surf := TTF_RenderText_Blended(ttfFont, PChar(text), sdlColor);
  if surf = nil then Exit;

  tex := SDL_CreateTextureFromSurface(FRenderer, surf);
  SDL_FreeSurface(surf);
  if tex = nil then Exit;

  dR.x := x; dR.y := y;
  SDL_QueryTexture(tex, nil, nil, @dR.w, @dR.h);
  SDL_RenderCopy(FRenderer, tex, nil, @dR);
  SDL_DestroyTexture(tex);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  Clip / Frame
// ─────────────────────────────────────────────────────────────────────────────

procedure TSDL2Renderer.SetClipRect(r: TRect);
var sdlR: TSDL_Rect;
begin
  if FRenderer = nil then Exit;
  FClipRect := r; FHasClip := True;
  sdlR := ToSDLRect(r);
  SDL_RenderSetClipRect(FRenderer, @sdlR);
end;

procedure TSDL2Renderer.ClearClipRect;
begin
  if FRenderer = nil then Exit;
  FHasClip := False;
  SDL_RenderSetClipRect(FRenderer, nil);
end;

procedure TSDL2Renderer.BeginFrame;
begin
  if FRenderer = nil then Exit;
  SDL_SetRenderDrawColor(FRenderer, 0, 0, 0, 255);
  SDL_RenderClear(FRenderer);
  SDL_SetRenderDrawBlendMode(FRenderer, SDL_BLENDMODE_BLEND);
end;

procedure TSDL2Renderer.EndFrame;
begin
  if FRenderer = nil then Exit;
  SDL_RenderPresent(FRenderer);
end;

function TSDL2Renderer.GetWindow:   PSDL_Window;  begin Result := FWindow;   end;
function TSDL2Renderer.GetRenderer: PSDL_Renderer; begin Result := FRenderer; end;
function TSDL2Renderer.GetWidth:    Integer;        begin Result := FWidth;    end;
function TSDL2Renderer.GetHeight:   Integer;        begin Result := FHeight;   end;

end.
