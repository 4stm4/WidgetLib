unit SDL2ImageLoader;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  SDL2,
  Core.Contracts;

type
  TSDL2Image = class(IImage)
  private
    FTexture: PSDL_Texture;
    FWidth: Integer;
    FHeight: Integer;
  public
    constructor Create(texture: PSDL_Texture; width, height: Integer);
    destructor Destroy; override;

    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    function GetHandle: Pointer; override;
  end;

  TSDL2ImageLoader = class(IImageLoader)
  private
    FRenderer: PSDL_Renderer;
    FColorKeyEnabled: Boolean;
    FColorKeyR: Byte;
    FColorKeyG: Byte;
    FColorKeyB: Byte;
  public
    constructor Create(renderer: PSDL_Renderer);
    function Load(path: String): IImage; override;
    procedure EnableColorKey(r, g, b: Byte);
    procedure DisableColorKey;
  end;

implementation

uses
  Logger;

{ TSDL2Image }

constructor TSDL2Image.Create(texture: PSDL_Texture; width, height: Integer);
begin
  inherited Create;
  FTexture := texture;
  FWidth := width;
  FHeight := height;
end;

destructor TSDL2Image.Destroy;
begin
  if FTexture <> nil then
    SDL_DestroyTexture(FTexture);
  inherited Destroy;
end;

function TSDL2Image.GetWidth: Integer;
begin
  Result := FWidth;
end;

function TSDL2Image.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TSDL2Image.GetHandle: Pointer;
begin
  Result := FTexture;
end;

{ TSDL2ImageLoader }

constructor TSDL2ImageLoader.Create(renderer: PSDL_Renderer);
begin
  inherited Create;
  FRenderer := renderer;
  FColorKeyEnabled := False;
  FColorKeyR := 0;
  FColorKeyG := 0;
  FColorKeyB := 0;
end;

procedure TSDL2ImageLoader.EnableColorKey(r, g, b: Byte);
begin
  FColorKeyEnabled := True;
  FColorKeyR := r;
  FColorKeyG := g;
  FColorKeyB := b;
end;

procedure TSDL2ImageLoader.DisableColorKey;
begin
  FColorKeyEnabled := False;
end;

function TSDL2ImageLoader.Load(path: String): IImage;
var
  surface: PSDL_Surface;
  surfaceRec: ^TSDL_Surface;
  texture: PSDL_Texture;
  width, height: Integer;
  colorKey: UInt32;
  rw: Pointer;
begin
  Result := nil;

  if FRenderer = nil then
    raise Exception.Create('SDL2ImageLoader: renderer is nil');

  rw := SDL_RWFromFile(PChar(path), PChar('rb'));
  if rw = nil then
    raise Exception.Create('Cannot open "' + path + '": ' + SDL_GetError);
  surface := SDL_LoadBMP_RW(rw, 1);
  if surface = nil then
    raise Exception.Create('Failed to load image "' + path + '": ' + SDL_GetError);

  try
    surfaceRec := surface;

    if FColorKeyEnabled then
    begin
      colorKey := SDL_MapRGBA(surfaceRec^.format, FColorKeyR, FColorKeyG, FColorKeyB, 255);
      SDL_SetColorKey(surface, 1, colorKey);
    end;

    texture := SDL_CreateTextureFromSurface(FRenderer, surface);
    if texture = nil then
      raise Exception.Create('Failed to create texture from "' + path + '": ' + SDL_GetError);

    width  := surfaceRec^.w;
    height := surfaceRec^.h;

    Result := TSDL2Image.Create(texture, width, height);
  finally
    SDL_FreeSurface(surface);
  end;
end;

end.
