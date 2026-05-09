unit SDL2_ttf;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  ctypes, SDL2;

const
  TTF_STYLE_NORMAL = $00;
  TTF_STYLE_BOLD = $01;
  TTF_STYLE_ITALIC = $02;
  TTF_STYLE_UNDERLINE = $04;
  TTF_STYLE_STRIKETHROUGH = $08;

type
  PTTF_Font = Pointer;

function TTF_Init: Int32; cdecl; external 'SDL2_ttf' name 'TTF_Init';
procedure TTF_Quit; cdecl; external 'SDL2_ttf' name 'TTF_Quit';
function TTF_WasInit: Int32; cdecl; external 'SDL2_ttf' name 'TTF_WasInit';

function TTF_OpenFont(file_: PChar; ptsize: Int32): PTTF_Font; cdecl; external 'SDL2_ttf' name 'TTF_OpenFont';
function TTF_OpenFontIndex(file_: PChar; ptsize: Int32; index: LongInt): PTTF_Font; cdecl; external 'SDL2_ttf' name 'TTF_OpenFontIndex';
procedure TTF_CloseFont(font: PTTF_Font); cdecl; external 'SDL2_ttf' name 'TTF_CloseFont';

function TTF_RenderText_Solid(font: PTTF_Font; text: PChar; fg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderText_Solid';
function TTF_RenderText_Shaded(font: PTTF_Font; text: PChar; fg, bg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderText_Shaded';
function TTF_RenderText_Blended(font: PTTF_Font; text: PChar; fg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderText_Blended';

function TTF_RenderUTF8_Solid(font: PTTF_Font; text: PChar; fg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderUTF8_Solid';
function TTF_RenderUTF8_Shaded(font: PTTF_Font; text: PChar; fg, bg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderUTF8_Shaded';
function TTF_RenderUTF8_Blended(font: PTTF_Font; text: PChar; fg: TSDL_Color): PSDL_Surface; cdecl; external 'SDL2_ttf' name 'TTF_RenderUTF8_Blended';

function TTF_SizeText(font: PTTF_Font; text: PChar; w, h: PInt32): Int32; cdecl; external 'SDL2_ttf' name 'TTF_SizeText';
function TTF_SizeUTF8(font: PTTF_Font; text: PChar; w, h: PInt32): Int32; cdecl; external 'SDL2_ttf' name 'TTF_SizeUTF8';

function TTF_FontHeight(font: PTTF_Font): Int32; cdecl; external 'SDL2_ttf' name 'TTF_FontHeight';
function TTF_FontAscent(font: PTTF_Font): Int32; cdecl; external 'SDL2_ttf' name 'TTF_FontAscent';
function TTF_FontDescent(font: PTTF_Font): Int32; cdecl; external 'SDL2_ttf' name 'TTF_FontDescent';
function TTF_FontLineSkip(font: PTTF_Font): Int32; cdecl; external 'SDL2_ttf' name 'TTF_FontLineSkip';

implementation

{$linklib SDL2_ttf}

end.
