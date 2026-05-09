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
  public
    constructor Create(renderer: PSDL_Renderer);
    function Load(path: String): IImage; override;
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
end;

function TSDL2ImageLoader.Load(path: String): IImage;
var
  surface: PSDL_Surface;
  surfaceRec: ^TSDL_Surface;
  texture: PSDL_Texture;
  width, height: Integer;
begin
  Result := nil;

  if FRenderer = nil then
    raise Exception.Create('SDL2ImageLoader: renderer is nil');

  // Load using SDL_image or SDL_LoadBMP
  // Using SDL_LoadBMP for BMP files
  surface := SDL_LoadBMP(PChar(path));
  if surface = nil then
  begin
    // Try SDL_image if available (IMG_Load)
    // For now, just fail
    raise Exception.Create('Failed to load image "' + path + '": ' + SDL_GetError);
  end;

  try
    // Create texture from surface
    texture := SDL_CreateTextureFromSurface(FRenderer, surface);
    if texture = nil then
      raise Exception.Create('Failed to create texture from "' + path + '": ' + SDL_GetError);

    surfaceRec := surface;
    width := surfaceRec^.w;
    height := surfaceRec^.h;

    Result := TSDL2Image.Create(texture, width, height);
  finally
    SDL_FreeSurface(surface);
  end;
end;

end.
