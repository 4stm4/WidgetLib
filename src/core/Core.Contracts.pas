unit Core.Contracts;

{$mode objfpc}{$H+}

interface

type
  TPoint = record
    x: Integer;
    y: Integer;
  end;

  TRect = record
    x: Integer;
    y: Integer;
    w: Integer;
    h: Integer;
  end;

  // ── 9-slice panel margins ──────────────────────────────────────────────────
  T9SliceMargins = record
    top, right, bottom, left: Integer;
  end;

  // ── Blend modes for layered rendering ─────────────────────────────────────
  TBlendMode = (
    bmNormal,    // standard alpha blend
    bmAdd,       // additive (glow, neon, fire)
    bmMultiply,  // multiply (shadow, tint)
    bmAlpha      // explicit alpha blend (same as Normal, explicit param)
  );

  // ── Anchor system ─────────────────────────────────────────────────────────
  TAnchorSide = (asNone, asLeft, asRight, asTop, asBottom, asCenter, asFill);

  TAnchor = record
    horizontal:  TAnchorSide;
    vertical:    TAnchorSide;
    marginLeft, marginTop, marginRight, marginBottom: Integer;
  end;

  // ── Widget states (extended for game UI) ──────────────────────────────────
  TWidgetState = (
    wsNormal,    // default
    wsHover,     // mouse over
    wsActive,    // pressed / toggled on
    wsDisabled,  // greyed out
    wsWarning,   // yellow alert
    wsCritical,  // red alert (blinking)
    wsLocked,    // locked / unavailable
    wsCooldown,  // ability on cooldown
    wsSelected   // slot selected / active weapon
  );

  // ── Forward declarations ───────────────────────────────────────────────────
  IWidget = class;

  TEventKind = (
    evMouseMove, evMouseDown, evMouseUp, evMouseWheel,
    evKeyDown, evKeyUp,
    evCommand,
    evHoverEnter, evHoverLeave,
    evFocusGained, evFocusLost,
    evDragStart, evDragMove, evDragEnd,
    evTimer
  );

  TWidgetEvent = record
    kind:        TEventKind;
    x, y:        Integer;
    button:      Byte;
    key:         Integer;
    wheelDelta:  Integer;
    dragSource:  IWidget;
    commandName: String;
    commandData: Pointer;
    handled:     Boolean;
  end;

  IRenderer  = class;
  IImage     = class;
  IFont      = class;
  IImageLoader  = class;
  IFontLoader   = class;
  IWidgetLoader = class;

  TWidgetArray = array of IWidget;

  // ── IWidget ────────────────────────────────────────────────────────────────
  IWidget = class abstract
  public
    function  GetID: String; virtual; abstract;
    function  GetParent: IWidget; virtual; abstract;
    function  GetChildren: TWidgetArray; virtual; abstract;
    procedure AddChild(child: IWidget); virtual; abstract;
    procedure RemoveChild(child: IWidget); virtual; abstract;
    function  GetBounds: TRect; virtual; abstract;
    procedure SetBounds(const bounds: TRect); virtual; abstract;
    procedure Update(dt: Single); virtual; abstract;
    procedure Render(r: IRenderer); virtual; abstract;
    function  HandleEvent(e: TWidgetEvent): Boolean; virtual; abstract;
    destructor Destroy; override; abstract;
  end;

  // ── IRenderer ─────────────────────────────────────────────────────────────
  IRenderer = class abstract
  public
    // ── Blend control ────────────────────────────────────────────────────────
    procedure PushBlendAdd;    virtual; abstract;   // switch to additive
    procedure PopBlend;        virtual; abstract;   // restore alpha blend

    // ── Primitives ───────────────────────────────────────────────────────────
    procedure DrawRect(r: TRect; color: LongWord); virtual; abstract;
    procedure DrawFilledRect(r: TRect; color: LongWord); virtual; abstract;
    procedure DrawLine(x1, y1, x2, y2: Integer; color: LongWord); virtual; abstract;

    // ── Circles & arcs ───────────────────────────────────────────────────────
    procedure DrawCircle(cx, cy, radius: Integer; color: LongWord); virtual; abstract;
    procedure DrawFilledCircle(cx, cy, radius: Integer; color: LongWord); virtual; abstract;
    // startDeg/endDeg in degrees, 0=right, 90=down; thickness in pixels
    procedure DrawArc(cx, cy, radius, startDeg, endDeg: Integer;
                      color: LongWord; thickness: Integer = 1); virtual; abstract;

    // ── Rounded rectangles ───────────────────────────────────────────────────
    procedure DrawRoundRect(r: TRect; radius: Integer; color: LongWord;
                            filled: Boolean = False); virtual; abstract;

    // ── Images ───────────────────────────────────────────────────────────────
    procedure DrawImage(img: IImage; src, dst: TRect); virtual; abstract;
    procedure DrawImageBlended(img: IImage; src, dst: TRect;
                               alpha: Byte; blendMode: TBlendMode = bmNormal); virtual; abstract;
    procedure Draw9Slice(img: IImage; src, dst: TRect;
                         margins: T9SliceMargins); virtual; abstract;

    // ── Text ─────────────────────────────────────────────────────────────────
    procedure DrawText(font: IFont; const text: String;
                       x, y: Integer; color: LongWord); virtual; abstract;

    // ── Clip ─────────────────────────────────────────────────────────────────
    procedure SetClipRect(r: TRect); virtual; abstract;
    procedure ClearClipRect; virtual; abstract;

    // ── Frame ────────────────────────────────────────────────────────────────
    procedure BeginFrame; virtual; abstract;
    procedure EndFrame;   virtual; abstract;
  end;

  // ── IImage ────────────────────────────────────────────────────────────────
  IImage = class abstract
  public
    function GetWidth:  Integer; virtual; abstract;
    function GetHeight: Integer; virtual; abstract;
    function GetHandle: Pointer; virtual; abstract;
  end;

  // ── IFont ─────────────────────────────────────────────────────────────────
  IFont = class abstract
  public
    function GetHandle: Pointer; virtual; abstract;
    function MeasureText(s: String): TPoint; virtual; abstract;
  end;

  // ── Loaders ───────────────────────────────────────────────────────────────
  IImageLoader = class abstract
  public
    function Load(path: String): IImage; virtual; abstract;
  end;

  IFontLoader = class abstract
  public
    function Load(path: String; size: Integer): IFont; virtual; abstract;
  end;

  // ── ISkin ─────────────────────────────────────────────────────────────────
  ISkin = class abstract
  public
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); virtual; abstract;
    function  GetTextColor(state: TWidgetState): LongWord; virtual; abstract;
    procedure Tick(dt: Single); virtual;   // animated skins override this
  end;

  // ── IWidgetLoader ─────────────────────────────────────────────────────────
  IWidgetLoader = class abstract
  public
    function LoadFromJSON(json: String): IWidget; virtual; abstract;
  end;

// ── Helpers ───────────────────────────────────────────────────────────────────
function MakeRect(x, y, w, h: Integer): TRect;
function MakeAnchor(h, v: TAnchorSide;
                    ml: Integer = 0; mt: Integer = 0;
                    mr: Integer = 0; mb: Integer = 0): TAnchor;
function Make9Slice(t, r, b, l: Integer): T9SliceMargins;

implementation

procedure ISkin.Tick(dt: Single);
begin
  // default: no animation
end;

function MakeRect(x, y, w, h: Integer): TRect;
begin
  Result.x := x; Result.y := y; Result.w := w; Result.h := h;
end;

function MakeAnchor(h, v: TAnchorSide; ml, mt, mr, mb: Integer): TAnchor;
begin
  Result.horizontal   := h;
  Result.vertical     := v;
  Result.marginLeft   := ml;
  Result.marginTop    := mt;
  Result.marginRight  := mr;
  Result.marginBottom := mb;
end;

function Make9Slice(t, r, b, l: Integer): T9SliceMargins;
begin
  Result.top := t; Result.right := r; Result.bottom := b; Result.left := l;
end;

end.
