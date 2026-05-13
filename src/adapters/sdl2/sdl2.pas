unit SDL2;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  ctypes;

const
  SDL_INIT_TIMER = $00000001;
  SDL_INIT_AUDIO = $00000010;
  SDL_INIT_VIDEO = $00000020;
  SDL_INIT_JOYSTICK = $00000200;
  SDL_INIT_HAPTIC = $00001000;
  SDL_INIT_GAMECONTROLLER = $00002000;
  SDL_INIT_EVENTS = $00004000;
  SDL_INIT_EVERYTHING = SDL_INIT_TIMER or SDL_INIT_AUDIO or SDL_INIT_VIDEO or
                        SDL_INIT_JOYSTICK or SDL_INIT_HAPTIC or
                        SDL_INIT_GAMECONTROLLER or SDL_INIT_EVENTS;

  SDL_WINDOW_SHOWN = $00000004;
  SDL_WINDOW_FULLSCREEN = $00000001;
  SDL_WINDOW_FULLSCREEN_DESKTOP = $00001001;
  SDL_WINDOW_OPENGL = $00000002;
  SDL_WINDOW_HIDDEN = $00000008;
  SDL_WINDOW_BORDERLESS = $00000010;
  SDL_WINDOW_RESIZABLE = $00000020;
  SDL_WINDOW_MINIMIZED = $00000040;
  SDL_WINDOW_MAXIMIZED = $00000080;
  SDL_WINDOW_INPUT_GRABBED = $00000100;
  SDL_WINDOW_INPUT_FOCUS = $00000200;
  SDL_WINDOW_MOUSE_FOCUS = $00000400;
  SDL_WINDOW_FOREIGN = $00000800;
  SDL_WINDOW_ALLOW_HIGHDPI = $00002000;
  SDL_WINDOWPOS_CENTERED = $2FFF0000;
  SDL_WINDOWPOS_UNDEFINED = $1FFF0000;

  SDL_RENDERER_SOFTWARE = $00000001;
  SDL_RENDERER_ACCELERATED = $00000002;
  SDL_RENDERER_PRESENTVSYNC = $00000004;
  SDL_RENDERER_TARGETTEXTURE = $00000008;

  SDL_PIXELFORMAT_RGBA8888 = 376840196;

type
  PSDL_Window = Pointer;
  PSDL_Renderer = Pointer;
  PSDL_Texture = Pointer;
  PSDL_Surface = Pointer;

  PUInt8 = ^UInt8;
  PUInt16 = ^UInt16;
  PUInt32 = ^UInt32;
  PInt32 = ^Int32;

  TSDL_Rect = record
    x: Int32;
    y: Int32;
    w: Int32;
    h: Int32;
  end;
  PSDL_Rect = ^TSDL_Rect;

  TSDL_Point = record
    x: Int32;
    y: Int32;
  end;
  PSDL_Point = ^TSDL_Point;

  TSDL_Color = record
    r: UInt8;
    g: UInt8;
    b: UInt8;
    a: UInt8;
  end;
  PSDL_Color = ^TSDL_Color;

  TSDL_PixelFormat = record
    format: UInt32;
    palette: Pointer;
    BitsPerPixel: UInt8;
    BytesPerPixel: UInt8;
    padding: array[0..1] of UInt8;
    RMask: UInt32;
    GMask: UInt32;
    BMask: UInt32;
    AMask: UInt32;
  end;
  PSDL_PixelFormat = ^TSDL_PixelFormat;

  TSDL_Surface = record
    flags: UInt32;
    format: PSDL_PixelFormat;
    w: Int32;
    h: Int32;
    pitch: Int32;
    pixels: Pointer;
    userdata: Pointer;
    locked: Int32;
    lock_data: Pointer;
    clip_rect: TSDL_Rect;
    map: Pointer;
    refcount: Int32;
  end;

  UInt8Array = array[0..255] of UInt8;

  TSDL_Keysym = record
    scancode: Int32;
    sym: Int32;
    mod_: UInt16;
    unused: UInt32;
  end;

  TSDL_KeyboardEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    state: UInt8;
    repeat_: UInt8;
    padding2: UInt8;
    padding3: UInt8;
    keysym: TSDL_Keysym;
  end;

  TSDL_MouseMotionEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    which_: UInt32;
    state: UInt32;
    x: Int32;
    y: Int32;
    xrel: Int32;
    yrel: Int32;
  end;

  TSDL_MouseButtonEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    which_: UInt32;
    button: UInt8;
    state: UInt8;
    clicks: UInt8;
    padding1: UInt8;
    x: Int32;
    y: Int32;
  end;

  TSDL_MouseWheelEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    which_: UInt32;
    x: Int32;
    y: Int32;
    direction: UInt32;
  end;

  TSDL_WindowEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    event: UInt8;
    padding1: UInt8;
    padding2: UInt8;
    padding3: UInt8;
    data1: Int32;
    data2: Int32;
  end;

  TSDL_UserEvent = record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    code: Int32;
    data1: Pointer;
    data2: Pointer;
  end;

  TSDL_CommonEvent = record
    type_: UInt32;
    timestamp: UInt32;
  end;

  TSDL_Event = record
    case Integer of
      0: (type_: UInt32);
      1: (common: TSDL_CommonEvent);
      2: (window: TSDL_WindowEvent);
      3: (key: TSDL_KeyboardEvent);
      4: (motion: TSDL_MouseMotionEvent);
      5: (button: TSDL_MouseButtonEvent);
      6: (wheel: TSDL_MouseWheelEvent);
      7: (user: TSDL_UserEvent);
      8: (padding: array[0..55] of UInt8);
  end;

const
  SDL_FIRSTEVENT = 0;
  SDL_QUITEV = $100;
  SDL_WINDOWEVENT = $200;
  SDL_SYSWMEVENT = $201;
  SDL_KEYDOWN = $300;
  SDL_KEYUP = $301;
  SDL_TEXTEDITING = $302;
  SDL_TEXTINPUT = $303;
  SDL_MOUSEMOTION = $400;
  SDL_MOUSEBUTTONDOWN = $401;
  SDL_MOUSEBUTTONUP = $402;
  SDL_MOUSEWHEEL = $403;
  SDL_JOYAXISMOTION = $600;
  SDL_JOYBALLMOTION = $601;
  SDL_JOYHATMOTION = $602;
  SDL_JOYBUTTONDOWN = $603;
  SDL_JOYBUTTONUP = $604;
  SDL_JOYDEVICEADDED = $605;
  SDL_JOYDEVICEREMOVED = $606;
  SDL_CONTROLLERAXISMOTION = $650;
  SDL_CONTROLLERBUTTONDOWN = $651;
  SDL_CONTROLLERBUTTONUP = $652;
  SDL_CONTROLLERDEVICEADDED = $653;
  SDL_CONTROLLERDEVICEREMOVED = $654;
  SDL_CONTROLLERDEVICEREMAPPED = $655;
  SDL_USEREVENT = $8000;
  SDL_LASTEVENT = $FFFF;

  SDL_WINDOWEVENT_NONE = 0;
  SDL_WINDOWEVENT_SHOWN = 1;
  SDL_WINDOWEVENT_HIDDEN = 2;
  SDL_WINDOWEVENT_EXPOSED = 3;
  SDL_WINDOWEVENT_MOVED = 4;
  SDL_WINDOWEVENT_RESIZED = 5;
  SDL_WINDOWEVENT_SIZE_CHANGED = 6;
  SDL_WINDOWEVENT_MINIMIZED = 7;
  SDL_WINDOWEVENT_MAXIMIZED = 8;
  SDL_WINDOWEVENT_RESTORED = 9;
  SDL_WINDOWEVENT_ENTER = 10;
  SDL_WINDOWEVENT_LEAVE = 11;
  SDL_WINDOWEVENT_FOCUS_GAINED = 12;
  SDL_WINDOWEVENT_FOCUS_LOST = 13;
  SDL_WINDOWEVENT_CLOSE = 14;

function SDL_Init(flags: UInt32): Int32; cdecl; external 'SDL2' name 'SDL_Init';
procedure SDL_Quit; cdecl; external 'SDL2' name 'SDL_Quit';

function SDL_CreateWindow(title: PChar; x, y, w, h: Int32; flags: UInt32): PSDL_Window; cdecl; external 'SDL2' name 'SDL_CreateWindow';
procedure SDL_DestroyWindow(window: PSDL_Window); cdecl; external 'SDL2' name 'SDL_DestroyWindow';

function SDL_CreateRenderer(window: PSDL_Window; index: Int32; flags: UInt32): PSDL_Renderer; cdecl; external 'SDL2' name 'SDL_CreateRenderer';
procedure SDL_DestroyRenderer(renderer: PSDL_Renderer); cdecl; external 'SDL2' name 'SDL_DestroyRenderer';

function SDL_CreateTexture(renderer: PSDL_Renderer; format: UInt32; access, w, h: Int32): PSDL_Texture; cdecl; external 'SDL2' name 'SDL_CreateTexture';
function SDL_CreateTextureFromSurface(renderer: PSDL_Renderer; surface: PSDL_Surface): PSDL_Texture; cdecl; external 'SDL2' name 'SDL_CreateTextureFromSurface';
procedure SDL_DestroyTexture(texture: PSDL_Texture); cdecl; external 'SDL2' name 'SDL_DestroyTexture';

function SDL_RWFromFile(file_: PChar; mode: PChar): Pointer; cdecl; external 'SDL2' name 'SDL_RWFromFile';
function SDL_LoadBMP_RW(src: Pointer; freesrc: Int32): PSDL_Surface; cdecl; external 'SDL2' name 'SDL_LoadBMP_RW';
function SDL_FreeSurface(surface: PSDL_Surface): PSDL_Surface; cdecl; external 'SDL2' name 'SDL_FreeSurface';

function SDL_RenderSetClipRect(renderer: PSDL_Renderer; rect: PSDL_Rect): Int32; cdecl; external 'SDL2' name 'SDL_RenderSetClipRect';
function SDL_SetRenderDrawColor(renderer: PSDL_Renderer; r, g, b, a: UInt8): Int32; cdecl; external 'SDL2' name 'SDL_SetRenderDrawColor';
function SDL_RenderClear(renderer: PSDL_Renderer): Int32; cdecl; external 'SDL2' name 'SDL_RenderClear';
function SDL_RenderPresent(renderer: PSDL_Renderer): Int32; cdecl; external 'SDL2' name 'SDL_RenderPresent';
function SDL_RenderCopy(renderer: PSDL_Renderer; texture: PSDL_Texture; srcrect, dstrect: PSDL_Rect): Int32; cdecl; external 'SDL2' name 'SDL_RenderCopy';
function SDL_RenderFillRect(renderer: PSDL_Renderer; rect: PSDL_Rect): Int32; cdecl; external 'SDL2' name 'SDL_RenderFillRect';
function SDL_RenderDrawRect(renderer: PSDL_Renderer; rect: PSDL_Rect): Int32; cdecl; external 'SDL2' name 'SDL_RenderDrawRect';

// Blend modes
const
  SDL_BLENDMODE_NONE    = 0;
  SDL_BLENDMODE_BLEND   = 1;
  SDL_BLENDMODE_ADD     = 2;
  SDL_BLENDMODE_MOD     = 4;
  SDL_TEXTUREACCESS_STREAMING = 1;
  SDL_TEXTUREACCESS_TARGET    = 2;

type
  SDL_BlendMode = Int32;

function SDL_SetRenderDrawBlendMode(renderer: PSDL_Renderer; blendMode: SDL_BlendMode): Int32; cdecl; external 'SDL2' name 'SDL_SetRenderDrawBlendMode';
function SDL_GetRenderDrawBlendMode(renderer: PSDL_Renderer; blendMode: PSDL_Rect): Int32; cdecl; external 'SDL2' name 'SDL_GetRenderDrawBlendMode';
function SDL_SetTextureBlendMode(texture: PSDL_Texture; blendMode: SDL_BlendMode): Int32; cdecl; external 'SDL2' name 'SDL_SetTextureBlendMode';
function SDL_SetTextureAlphaMod(texture: PSDL_Texture; alpha: UInt8): Int32; cdecl; external 'SDL2' name 'SDL_SetTextureAlphaMod';
function SDL_SetTextureColorMod(texture: PSDL_Texture; r, g, b: UInt8): Int32; cdecl; external 'SDL2' name 'SDL_SetTextureColorMod';
function SDL_RenderDrawLine(renderer: PSDL_Renderer; x1, y1, x2, y2: Int32): Int32; cdecl; external 'SDL2' name 'SDL_RenderDrawLine';
function SDL_RenderDrawPoint(renderer: PSDL_Renderer; x, y: Int32): Int32; cdecl; external 'SDL2' name 'SDL_RenderDrawPoint';
function SDL_RenderDrawLines(renderer: PSDL_Renderer; points: PSDL_Point; count: Int32): Int32; cdecl; external 'SDL2' name 'SDL_RenderDrawLines';
function SDL_RenderDrawPoints(renderer: PSDL_Renderer; points: PSDL_Point; count: Int32): Int32; cdecl; external 'SDL2' name 'SDL_RenderDrawPoints';
function SDL_RenderCopyEx(renderer: PSDL_Renderer; texture: PSDL_Texture; srcrect, dstrect: PSDL_Rect; angle: Double; center: PSDL_Point; flip: Int32): Int32; cdecl; external 'SDL2' name 'SDL_RenderCopyEx';

function SDL_GetWindowSurface(window: PSDL_Window): PSDL_Surface; cdecl; external 'SDL2' name 'SDL_GetWindowSurface';
procedure SDL_GetWindowSize(window: PSDL_Window; w, h: PInt32); cdecl; external 'SDL2' name 'SDL_GetWindowSize';

function SDL_MapRGBA(format: Pointer; r, g, b, a: UInt8): UInt32; cdecl; external 'SDL2' name 'SDL_MapRGBA';
function SDL_AllocFormat(pixel_format: UInt32): Pointer; cdecl; external 'SDL2' name 'SDL_AllocFormat';
function SDL_SetColorKey(surface: PSDL_Surface; flag: Int32; key: UInt32): Int32; cdecl; external 'SDL2' name 'SDL_SetColorKey';

function SDL_PollEvent(event: Pointer): Int32; cdecl; external 'SDL2' name 'SDL_PollEvent';

function SDL_GetTicks: UInt32; cdecl; external 'SDL2' name 'SDL_GetTicks';
function SDL_GetTicks64: UInt64; cdecl; external 'SDL2' name 'SDL_GetTicks64';
procedure SDL_Delay(ms: UInt32); cdecl; external 'SDL2' name 'SDL_Delay';

function SDL_GetError: PChar; cdecl; external 'SDL2' name 'SDL_GetError';
procedure SDL_ClearError; cdecl; external 'SDL2' name 'SDL_ClearError';

function SDL_QueryTexture(texture: PSDL_Texture; format: PUInt32; access: PInt32; w, h: PInt32): Int32; cdecl; external 'SDL2' name 'SDL_QueryTexture';

implementation

{$linklib SDL2}
{$linklib SDL2_ttf}

end.
