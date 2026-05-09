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


  IWidget = class; // forward declaration for TWidgetEvent.dragSource

  TEventKind = (
    evMouseMove,
    evMouseDown,
    evMouseUp,
    evMouseWheel,
    evKeyDown,
    evKeyUp,
    evCommand,
    evHoverEnter,
    evHoverLeave,
    evFocusGained,
    evFocusLost,
    evDragStart,
    evDragMove,
    evDragEnd,
    evTimer
  );

  TWidgetState = (wsNormal, wsHover, wsActive, wsDisabled);

  TWidgetEvent = record
    kind: TEventKind;
    x: Integer;
    y: Integer;
    button: Byte;         // mouse button (1=left,2=mid,3=right)
    key: Integer;         // SDL keysym
    wheelDelta: Integer;  // для scroll
    dragSource: IWidget;  // для drag
    commandName: String;  // для evCommand
    commandData: Pointer; // payload команды
    handled: Boolean;
  end;

  IRenderer = class;
  IImage = class;
  IFont = class;
  IImageLoader = class;
  IFontLoader = class;
  IWidgetLoader = class;

  TWidgetArray = array of IWidget;

  IWidget = class abstract
  public
    function GetID: String; virtual; abstract;
    function GetParent: IWidget; virtual; abstract;
    function GetChildren: TWidgetArray; virtual; abstract;
    procedure AddChild(child: IWidget); virtual; abstract;
    procedure RemoveChild(child: IWidget); virtual; abstract;
    function GetBounds: TRect; virtual; abstract;
    procedure SetBounds(const bounds: TRect); virtual; abstract;
    procedure Update(dt: Single); virtual; abstract;
    procedure Render(r: IRenderer); virtual; abstract;
    function HandleEvent(e: TWidgetEvent): Boolean; virtual; abstract;
    destructor Destroy; override; abstract;
  end;

  IRenderer = class abstract
  public
    procedure DrawRect(r: TRect; color: LongWord); virtual; abstract;
    procedure DrawFilledRect(r: TRect; color: LongWord); virtual; abstract;
    procedure DrawImage(img: IImage; src, dst: TRect); virtual; abstract;
    procedure DrawText(font: IFont; const text: String; x, y: Integer; color: LongWord); virtual; abstract;
    procedure SetClipRect(r: TRect); virtual; abstract;
    procedure ClearClipRect; virtual; abstract;
    procedure BeginFrame; virtual; abstract;
    procedure EndFrame; virtual; abstract;
  end;

  IImage = class abstract
  public
    function GetWidth: Integer; virtual; abstract;
    function GetHeight: Integer; virtual; abstract;
    function GetHandle: Pointer; virtual; abstract;
  end;

  IFont = class abstract
  public
    function GetHandle: Pointer; virtual; abstract;
    function MeasureText(s: String): TPoint; virtual; abstract;
  end;

  IImageLoader = class abstract
  public
    function Load(path: String): IImage; virtual; abstract;
  end;

  IFontLoader = class abstract
  public
    function Load(path: String; size: Integer): IFont; virtual; abstract;
  end;

  ISkin = class abstract
  public
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); virtual; abstract;
    function GetTextColor(state: TWidgetState): LongWord; virtual; abstract;
  end;

  IWidgetLoader = class abstract
  public
    function LoadFromJSON(json: String): IWidget; virtual; abstract;
  end;

implementation

end.
