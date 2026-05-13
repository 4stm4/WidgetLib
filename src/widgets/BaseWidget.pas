unit BaseWidget;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Core.Contracts;

type
  TBaseWidget = class(IWidget)
  private
    FID:       String;
    FBounds:   TRect;
    FVisible:  Boolean;
    FEnabled:  Boolean;
    FDirty:    Boolean;
    FParent:   IWidget;
    FChildren: TFPList;
    FState:    TWidgetState;
    FSkin:     ISkin;
    FAnchor:   TAnchor;
  public
    constructor Create(const aID: String);
    destructor  Destroy; override;

    function  GetID: String; override;
    procedure SetID(const aID: String);
    function  GetParent: IWidget; override;
    function  GetChildren: TWidgetArray; override;
    procedure AddChild(w: IWidget); override;
    procedure RemoveChild(w: IWidget); override;
    function  GetBounds: TRect; override;
    procedure SetBounds(const bounds: TRect); override;

    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
    function  HandleEvent(e: TWidgetEvent): Boolean; override;

    function  ContainsPoint(x, y: Integer): Boolean;
    procedure Invalidate;
    function  IsDirty: Boolean;
    function  IsVisible: Boolean;
    procedure SetVisible(value: Boolean);

    procedure OnHoverEnter; virtual;
    procedure OnHoverLeave; virtual;
    procedure OnFocusGained; virtual;
    procedure OnFocusLost; virtual;

    // Anchor — used by layout managers on resize
    function  GetAnchor: TAnchor;
    procedure SetAnchor(const a: TAnchor);

    property State:  TWidgetState read FState write FState;
    property Skin:   ISkin        read FSkin  write FSkin;
    property Anchor: TAnchor      read FAnchor write FAnchor;
  end;

implementation

constructor TBaseWidget.Create(const aID: String);
begin
  FID      := aID;
  FBounds  := MakeRect(0, 0, 0, 0);
  FVisible := True;
  FEnabled := True;
  FDirty   := True;
  FParent  := nil;
  FChildren := TFPList.Create;
  FState   := wsNormal;
  FSkin    := nil;
  FAnchor  := MakeAnchor(asNone, asNone);
end;

destructor TBaseWidget.Destroy;
var
  i: Integer;
begin
  for i := FChildren.Count - 1 downto 0 do
    IWidget(FChildren[i]).Free;
  FChildren.Free;
end;

function TBaseWidget.GetID: String;
begin Result := FID; end;

procedure TBaseWidget.SetID(const aID: String);
begin FID := aID; end;

function TBaseWidget.GetParent: IWidget;
begin Result := FParent; end;

function TBaseWidget.GetChildren: TWidgetArray;
var i: Integer;
begin
  Result := nil;
  SetLength(Result, FChildren.Count);
  for i := 0 to FChildren.Count - 1 do
    Result[i] := IWidget(FChildren[i]);
end;

procedure TBaseWidget.AddChild(w: IWidget);
begin
  if w = nil then Exit;
  if FChildren.IndexOf(Pointer(w)) < 0 then
    FChildren.Add(Pointer(w));
  if w is TBaseWidget then
    TBaseWidget(w).FParent := Self;
end;

procedure TBaseWidget.RemoveChild(w: IWidget);
begin
  if w = nil then Exit;
  FChildren.Remove(Pointer(w));
  if w is TBaseWidget then
    TBaseWidget(w).FParent := nil;
end;

function TBaseWidget.GetBounds: TRect;
begin Result := FBounds; end;

procedure TBaseWidget.SetBounds(const bounds: TRect);
begin FBounds := bounds; end;

procedure TBaseWidget.Update(dt: Single);
begin
  // Propagate animation tick to skin
  if FSkin <> nil then FSkin.Tick(dt);
end;

procedure TBaseWidget.Render(r: IRenderer);
begin
  if FSkin <> nil then
    FSkin.Draw(r, FBounds, FState);
  FDirty := False;
end;

function TBaseWidget.HandleEvent(e: TWidgetEvent): Boolean;
begin
  Result := False;
end;

function TBaseWidget.ContainsPoint(x, y: Integer): Boolean;
begin
  Result :=
    (x >= FBounds.x) and (x < FBounds.x + FBounds.w) and
    (y >= FBounds.y) and (y < FBounds.y + FBounds.h);
end;

procedure TBaseWidget.Invalidate; begin FDirty := True; end;
function  TBaseWidget.IsDirty: Boolean; begin Result := FDirty; end;
function  TBaseWidget.IsVisible: Boolean; begin Result := FVisible; end;
procedure TBaseWidget.SetVisible(value: Boolean); begin FVisible := value; end;

procedure TBaseWidget.OnHoverEnter;
begin if FState <> wsDisabled then FState := wsHover; end;

procedure TBaseWidget.OnHoverLeave;
begin if FState = wsHover then FState := wsNormal; end;

procedure TBaseWidget.OnFocusGained; begin end;
procedure TBaseWidget.OnFocusLost;   begin end;

function  TBaseWidget.GetAnchor: TAnchor; begin Result := FAnchor; end;
procedure TBaseWidget.SetAnchor(const a: TAnchor); begin FAnchor := a; end;

end.
