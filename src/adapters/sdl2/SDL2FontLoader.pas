unit SDL2FontLoader;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  SDL2,
  SDL2_ttf,
  Core.Contracts;

type
  TSDL2Font = class(IFont)
  private
    FFont: PTTF_Font;
  public
    constructor Create(f: PTTF_Font);
    destructor Destroy; override;

    function GetHandle: Pointer; override;
    function MeasureText(s: String): TPoint; override;
  end;

  TSDL2FontLoader = class(IFontLoader)
  public
    function Load(path: String; size: Integer): IFont; override;
  end;

implementation

var
  TTFInitializedByLoader: Boolean = False;

{ TSDL2Font }

constructor TSDL2Font.Create(f: PTTF_Font);
begin
  inherited Create;
  FFont := f;
end;

destructor TSDL2Font.Destroy;
begin
  if FFont <> nil then
    TTF_CloseFont(FFont);
  inherited Destroy;
end;

function TSDL2Font.GetHandle: Pointer;
begin
  Result := FFont;
end;

function TSDL2Font.MeasureText(s: String): TPoint;
var
  w, h: Integer;
begin
  w := 0;
  h := 0;

  if FFont <> nil then
    TTF_SizeText(FFont, PChar(s), @w, @h);

  Result.x := w;
  Result.y := h;
end;

{ TSDL2FontLoader }

function TSDL2FontLoader.Load(path: String; size: Integer): IFont;
var
  font: PTTF_Font;
begin
  // Initialize SDL_ttf if needed
  if (TTF_WasInit = 0) and not TTFInitializedByLoader then
  begin
    if TTF_Init <> 0 then
      raise Exception.Create('Failed to initialize SDL2_ttf: ' + SDL_GetError);
    TTFInitializedByLoader := True;
  end;

  font := TTF_OpenFont(PChar(path), size);
  if font = nil then
    raise Exception.Create('Failed to load TTF "' + path + '" size ' + IntToStr(size) + ': ' + SDL_GetError);

  Result := TSDL2Font.Create(font);
end;

end.
