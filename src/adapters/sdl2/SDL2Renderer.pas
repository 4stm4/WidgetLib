unit SDL2Renderer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  SDL2,
  SDL2_ttf,
  Core.Contracts;

type
  TSDL2Renderer = class(IRenderer)
  private
    FWindow: PSDL_Window;
    FRenderer: PSDL_Renderer;
    FClipRect: TRect;
    FHasClip: Boolean;
    FWidth: Integer;
    FHeight: Integer;

    function ToSDLRect(r: TRect): TSDL_Rect;
    function MapColor(color: LongWord): UInt32;
  public
    constructor Create(window: PSDL_Window; renderer: PSDL_Renderer);
    constructor CreateWithWindow(const title: String; width, height: Integer);

    destructor Destroy; override;

    procedure DrawRect(r: TRect; color: LongWord); override;
    procedure DrawFilledRect(r: TRect; color: LongWord); override;
    procedure DrawImage(img: IImage; src, dst: TRect); override;
    procedure DrawText(font: IFont; const text: String; x, y: Integer; color: LongWord); override;
    procedure SetClipRect(r: TRect); override;
    procedure ClearClipRect; override;
    procedure BeginFrame; override;
    procedure EndFrame; override;

    function GetWindow: PSDL_Window;
    function GetRenderer: PSDL_Renderer;
    function GetWidth: Integer;
    function GetHeight: Integer;
  end;

implementation

uses
  Logger;

constructor TSDL2Renderer.Create(window: PSDL_Window; renderer: PSDL_Renderer);
begin
  inherited Create;
  FWindow := window;
  FRenderer := renderer;
  FHasClip := False;
  FClipRect.x := 0;
  FClipRect.y := 0;
  FClipRect.w := 0;
  FClipRect.h := 0;

  if FWindow <> nil then
    SDL_GetWindowSize(FWindow, @FWidth, @FHeight);
end;

constructor TSDL2Renderer.CreateWithWindow(const title: String; width, height: Integer);
begin
  FWidth := width;
  FHeight := height;

  FWindow := SDL_CreateWindow(
    PChar(title),
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    width,
    height,
    SDL_WINDOW_SHOWN
  );

  if FWindow = nil then
    raise Exception.Create('Failed to create SDL2 window: ' + SDL_GetError);

  FRenderer := SDL_CreateRenderer(FWindow, -1, SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);

  if FRenderer = nil then
  begin
    // Fallback to software renderer
    FRenderer := SDL_CreateRenderer(FWindow, -1, SDL_RENDERER_SOFTWARE);
    if FRenderer = nil then
    begin
      SDL_DestroyWindow(FWindow);
      FWindow := nil;
      raise Exception.Create('Failed to create SDL2 renderer: ' + SDL_GetError);
    end;
  end;

  FHasClip := False;
  FClipRect.x := 0;
  FClipRect.y := 0;
  FClipRect.w := 0;
  FClipRect.h := 0;
end;

destructor TSDL2Renderer.Destroy;
begin
  // Note: we only destroy if we created them (CreateWithWindow)
  // If passed externally, caller manages lifetime
  if FRenderer <> nil then
    SDL_DestroyRenderer(FRenderer);
  if FWindow <> nil then
    SDL_DestroyWindow(FWindow);

  inherited Destroy;
end;

function TSDL2Renderer.ToSDLRect(r: TRect): TSDL_Rect;
begin
  Result.x := r.x;
  Result.y := r.y;
  Result.w := r.w;
  Result.h := r.h;
end;

function TSDL2Renderer.MapColor(color: LongWord): UInt32;
var
  red: UInt8;
  green: UInt8;
  blue: UInt8;
  alpha: UInt8;
begin
  red := UInt8((color shr 16) and $FF);
  green := UInt8((color shr 8) and $FF);
  blue := UInt8(color and $FF);
  alpha := UInt8((color shr 24) and $FF);
  if alpha = 0 then
    alpha := 255;

  Result := SDL_MapRGBA(SDL_AllocFormat(SDL_PIXELFORMAT_RGBA8888), red, green, blue, alpha);
end;

procedure TSDL2Renderer.DrawRect(r: TRect; color: LongWord);
var
  red, green, blue, alpha: UInt8;
  sdlRect: TSDL_Rect;
begin
  if FRenderer = nil then
    Exit;

  if (r.w <= 0) or (r.h <= 0) then
    Exit;

  red := UInt8((color shr 16) and $FF);
  green := UInt8((color shr 8) and $FF);
  blue := UInt8(color and $FF);
  alpha := UInt8((color shr 24) and $FF);
  if alpha = 0 then
    alpha := 255;

  SDL_SetRenderDrawColor(FRenderer, red, green, blue, alpha);

  // Top line
  sdlRect.x := r.x;
  sdlRect.y := r.y;
  sdlRect.w := r.w;
  sdlRect.h := 1;
  SDL_RenderFillRect(FRenderer, @sdlRect);

  // Bottom line
  sdlRect.y := r.y + r.h - 1;
  SDL_RenderFillRect(FRenderer, @sdlRect);

  // Left line
  sdlRect.x := r.x;
  sdlRect.y := r.y;
  sdlRect.w := 1;
  sdlRect.h := r.h;
  SDL_RenderFillRect(FRenderer, @sdlRect);

  // Right line
  sdlRect.x := r.x + r.w - 1;
  SDL_RenderFillRect(FRenderer, @sdlRect);
end;

procedure TSDL2Renderer.DrawFilledRect(r: TRect; color: LongWord);
var
  red, green, blue, alpha: UInt8;
  sdlRect: TSDL_Rect;
begin
  if FRenderer = nil then
    Exit;

  if (r.w <= 0) or (r.h <= 0) then
    Exit;

  red := UInt8((color shr 16) and $FF);
  green := UInt8((color shr 8) and $FF);
  blue := UInt8(color and $FF);
  alpha := UInt8((color shr 24) and $FF);
  if alpha = 0 then
    alpha := 255;

  SDL_SetRenderDrawColor(FRenderer, red, green, blue, alpha);

  sdlRect := ToSDLRect(r);
  SDL_RenderFillRect(FRenderer, @sdlRect);
end;

procedure TSDL2Renderer.DrawImage(img: IImage; src, dst: TRect);
var
  texture: PSDL_Texture;
  srcRect, dstRect: TSDL_Rect;
  missRect: TRect;
begin
  if FRenderer = nil then
    Exit;

  if (img = nil) or (img.GetHandle = nil) then
  begin
    Logger.TLogger.Instance.Log(llWarn, 'DrawImage: missing image');
    // Purple fallback
    if (dst.w <= 0) or (dst.h <= 0) then
    begin
      missRect.x := dst.x;
      missRect.y := dst.y;
      missRect.w := 1;
      missRect.h := 1;
    end
    else
      missRect := dst;

    DrawFilledRect(missRect, $FF00FF);
    Exit;
  end;

  texture := PSDL_Texture(img.GetHandle);

  srcRect := ToSDLRect(src);
  dstRect := ToSDLRect(dst);

  SDL_RenderCopy(FRenderer, texture, @srcRect, @dstRect);
end;

procedure TSDL2Renderer.DrawText(font: IFont; const text: String; x, y: Integer; color: LongWord);
var
  ttfFont: PTTF_Font;
  sdlColor: TSDL_Color;
  textSurface: PSDL_Surface;
  textTexture: PSDL_Texture;
  dstRect: TSDL_Rect;
  placeholderW: Integer;
  missRect: TRect;
begin
  if (FRenderer = nil) or (text = '') then
    Exit;

  if font = nil then
  begin
    Logger.TLogger.Instance.Log(llError, 'DrawText: font=nil');
    Exit;
  end;

  ttfFont := PTTF_Font(font.GetHandle);
  if ttfFont = nil then
  begin
    Logger.TLogger.Instance.Log(llError, 'DrawText: font handle=nil');
    // Placeholder box
    placeholderW := (Length(text) * 6);
    if placeholderW > 60 then
      placeholderW := 60;

    missRect.x := x;
    missRect.y := y;
    missRect.w := placeholderW;
    missRect.h := 8;
    DrawFilledRect(missRect, $FF00FF);
    Exit;
  end;

  sdlColor.r := UInt8((color shr 16) and $FF);
  sdlColor.g := UInt8((color shr 8) and $FF);
  sdlColor.b := UInt8(color and $FF);
  sdlColor.a := UInt8((color shr 24) and $FF);
  if sdlColor.a = 0 then
    sdlColor.a := 255;

  textSurface := TTF_RenderText_Blended(ttfFont, PChar(text), sdlColor);
  if textSurface = nil then
    Exit;

  textTexture := SDL_CreateTextureFromSurface(FRenderer, textSurface);
  SDL_FreeSurface(textSurface);

  if textTexture = nil then
    Exit;

  dstRect.x := x;
  dstRect.y := y;
  SDL_QueryTexture(textTexture, nil, nil, @dstRect.w, @dstRect.h);

  SDL_RenderCopy(FRenderer, textTexture, nil, @dstRect);
  SDL_DestroyTexture(textTexture);
end;

procedure TSDL2Renderer.SetClipRect(r: TRect);
var
  sdlRect: TSDL_Rect;
begin
  if FRenderer = nil then
    Exit;

  FClipRect := r;
  FHasClip := True;
  sdlRect := ToSDLRect(r);
  SDL_RenderSetClipRect(FRenderer, @sdlRect);
end;

procedure TSDL2Renderer.ClearClipRect;
begin
  if FRenderer = nil then
    Exit;

  FHasClip := False;
  SDL_RenderSetClipRect(FRenderer, nil);
end;

procedure TSDL2Renderer.BeginFrame;
begin
  if FRenderer = nil then
    Exit;

  // Clear with transparent/black background
  SDL_SetRenderDrawColor(FRenderer, 0, 0, 0, 255);
  SDL_RenderClear(FRenderer);
end;

procedure TSDL2Renderer.EndFrame;
begin
  if FRenderer = nil then
    Exit;

  SDL_RenderPresent(FRenderer);
end;

function TSDL2Renderer.GetWindow: PSDL_Window;
begin
  Result := FWindow;
end;

function TSDL2Renderer.GetRenderer: PSDL_Renderer;
begin
  Result := FRenderer;
end;

function TSDL2Renderer.GetWidth: Integer;
begin
  Result := FWidth;
end;

function TSDL2Renderer.GetHeight: Integer;
begin
  Result := FHeight;
end;

end.
