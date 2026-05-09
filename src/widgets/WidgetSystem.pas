unit WidgetSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Core.Contracts,
  EventSystem,
  BaseWidget;

type
  TWidgetCallback = procedure(w: IWidget) of object;

  TWidgetSystem = class
  private
    FRoot: IWidget;
    FWidgets: TFPList;
    FEvents: TEventSystem;
    FFocusedWidget: IWidget;
    FHoveredWidget: IWidget;
  public
    property EventSystem: TEventSystem read FEvents;

    procedure RegisterWidget(w: IWidget);
    procedure UnregisterWidget(w: IWidget);
    procedure TraverseWidget(w: IWidget; callback: TWidgetCallback);
    function FindWidgetAtNode(w: IWidget; x, y: Integer): IWidget;
    function WidgetContainsPoint(w: IWidget; x, y: Integer): Boolean;
    function WidgetIsVisible(w: IWidget): Boolean;
    function WidgetShouldRender(w: IWidget): Boolean;
    procedure UpdateWidget(w: IWidget; dt: Single);
    procedure RenderWidget(w: IWidget; r: IRenderer);
    procedure RegisterEventHandlers;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetRoot(w: IWidget);
    function GetRoot: IWidget;
    function GetWidgetCount: Integer;

    procedure AddWidget(parent: IWidget; child: IWidget);
    procedure RemoveWidget(w: IWidget);
    procedure TraverseDepthFirst(callback: TWidgetCallback);
    function FindWidgetAt(x, y: Integer): IWidget;
    procedure DispatchEvent(e: TWidgetEvent);
    procedure PostRawEvent(e: TWidgetEvent);
    function PendingEventCount: Integer;
    procedure Update(dt: Single);
    procedure Render(r: IRenderer);
    procedure DestroyAll;

    procedure SetFocus(w: IWidget);
    function GetFocus: IWidget;
    procedure UpdateHover(x, y: Integer);
  end;

implementation

procedure TWidgetSystem.SetFocus(w: IWidget);
var
  oldFocus: IWidget;
  ev: TWidgetEvent;
begin
  if (w = FFocusedWidget) or (w = nil) then Exit;
  if (w is TBaseWidget) and (TBaseWidget(w).State = wsDisabled) then Exit;
  oldFocus := FFocusedWidget;
  if oldFocus <> nil then
  begin
    if oldFocus is TBaseWidget then TBaseWidget(oldFocus).OnFocusLost;
    ev.kind := evFocusLost;
    ev.x := 0; ev.y := 0; ev.key := 0; ev.handled := False;
    oldFocus.HandleEvent(ev);
  end;
  FFocusedWidget := w;
  if w <> nil then
  begin
    if w is TBaseWidget then TBaseWidget(w).OnFocusGained;
    ev.kind := evFocusGained;
    ev.x := 0; ev.y := 0; ev.key := 0; ev.handled := False;
    w.HandleEvent(ev);
  end;
end;

function TWidgetSystem.GetFocus: IWidget;
begin
  Result := FFocusedWidget;
end;

procedure TWidgetSystem.UpdateHover(x, y: Integer);
var
  newHovered, oldHovered: IWidget;
  ev: TWidgetEvent;
begin
  newHovered := FindWidgetAt(x, y);
  if (newHovered = FHoveredWidget) or (newHovered = nil) then Exit;
  if (newHovered is TBaseWidget) and (TBaseWidget(newHovered).State = wsDisabled) then Exit;
  oldHovered := FHoveredWidget;
  if oldHovered <> nil then
  begin
    if oldHovered is TBaseWidget then TBaseWidget(oldHovered).OnHoverLeave;
    ev.kind := evHoverLeave;
    ev.x := x; ev.y := y; ev.key := 0; ev.handled := False;
    oldHovered.HandleEvent(ev);
  end;
  FHoveredWidget := newHovered;
  if newHovered <> nil then
  begin
    if newHovered is TBaseWidget then TBaseWidget(newHovered).OnHoverEnter;
    ev.kind := evHoverEnter;
    ev.x := x; ev.y := y; ev.key := 0; ev.handled := False;
    newHovered.HandleEvent(ev);
  end;
end;

constructor TWidgetSystem.Create;
begin
  inherited Create;
  FWidgets := TFPList.Create;
  FEvents := TEventSystem.Create;
  FRoot := nil;
  RegisterEventHandlers;
end;

destructor TWidgetSystem.Destroy;
begin
  DestroyAll;

  FEvents.Free;
  FWidgets.Free;
  inherited Destroy;
end;

procedure TWidgetSystem.RegisterWidget(w: IWidget);
begin
  if w = nil then
    Exit;

  if FWidgets.IndexOf(Pointer(w)) < 0 then
    FWidgets.Add(Pointer(w));
end;

procedure TWidgetSystem.UnregisterWidget(w: IWidget);
begin
  if w = nil then
    Exit;

  FWidgets.Remove(Pointer(w));
end;

procedure TWidgetSystem.TraverseWidget(w: IWidget; callback: TWidgetCallback);
var
  children: TWidgetArray;
  i: Integer;
begin
  if w = nil then
    Exit;

  callback(w);

  children := w.GetChildren;
  for i := Low(children) to High(children) do
    TraverseWidget(children[i], callback);
end;

function TWidgetSystem.WidgetContainsPoint(w: IWidget; x, y: Integer): Boolean;
var
  bounds: TRect;
begin
  if w = nil then
    Exit(False);

  bounds := w.GetBounds;
  Result :=
    (x >= bounds.x) and
    (x < bounds.x + bounds.w) and
    (y >= bounds.y) and
    (y < bounds.y + bounds.h);
end;

function TWidgetSystem.WidgetIsVisible(w: IWidget): Boolean;
begin
  if w is TBaseWidget then
    Result := TBaseWidget(w).IsVisible
  else
    Result := True;
end;

function TWidgetSystem.WidgetShouldRender(w: IWidget): Boolean;
begin
  // Always render visible widgets (BeginFrame clears screen each frame)
  Result := WidgetIsVisible(w);
end;

function TWidgetSystem.FindWidgetAtNode(w: IWidget; x, y: Integer): IWidget;
var
  children: TWidgetArray;
  i: Integer;
begin
  Result := nil;

  if (w = nil) or not WidgetContainsPoint(w, x, y) then
    Exit;

  children := w.GetChildren;
  for i := High(children) downto Low(children) do
  begin
    Result := FindWidgetAtNode(children[i], x, y);
    if Result <> nil then
      Exit;
  end;

  Result := w;
end;

procedure TWidgetSystem.RegisterEventHandlers;
var
  kind: TEventKind;
begin
  for kind := Low(TEventKind) to High(TEventKind) do
    FEvents.RegisterHandler(kind, @DispatchEvent);
end;

procedure TWidgetSystem.SetRoot(w: IWidget);
begin
  FRoot := w;
  RegisterWidget(w);
end;

function TWidgetSystem.GetRoot: IWidget;
begin
  Result := FRoot;
end;

function TWidgetSystem.GetWidgetCount: Integer;
begin
  Result := FWidgets.Count;
end;

procedure TWidgetSystem.AddWidget(parent: IWidget; child: IWidget);
begin
  if child = nil then
    Exit;

  if parent <> nil then
    parent.AddChild(child)
  else if FRoot = nil then
    FRoot := child;

  RegisterWidget(child);
end;

procedure TWidgetSystem.RemoveWidget(w: IWidget);
var
  parent: IWidget;
begin
  if w = nil then
    Exit;

  parent := w.GetParent;
  if parent <> nil then
    parent.RemoveChild(w);

  if FRoot = w then
    FRoot := nil;

  UnregisterWidget(w);
end;

procedure TWidgetSystem.TraverseDepthFirst(callback: TWidgetCallback);
begin
  if Assigned(callback) then
    TraverseWidget(FRoot, callback);
end;

function TWidgetSystem.FindWidgetAt(x, y: Integer): IWidget;
begin
  Result := FindWidgetAtNode(FRoot, x, y);
end;

procedure TWidgetSystem.DispatchEvent(e: TWidgetEvent);
var
  current: IWidget;
begin
  case e.kind of
    evMouseMove,
    evMouseDown,
    evMouseUp:
      current := FindWidgetAt(e.x, e.y);
  else
    current := FRoot;
  end;

  while current <> nil do
  begin
    if current.HandleEvent(e) then
      Exit;

    current := current.GetParent;
  end;
end;

procedure TWidgetSystem.PostRawEvent(e: TWidgetEvent);
begin
  FEvents.PostEvent(e);
end;

function TWidgetSystem.PendingEventCount: Integer;
begin
  Result := FEvents.PendingCount;
end;

procedure TWidgetSystem.Update(dt: Single);
begin
  UpdateWidget(FRoot, dt);
end;

procedure TWidgetSystem.Render(r: IRenderer);
begin
  if r <> nil then
    r.BeginFrame;

  RenderWidget(FRoot, r);

  if r <> nil then
    r.EndFrame;
end;

procedure TWidgetSystem.UpdateWidget(w: IWidget; dt: Single);
var
  children: TWidgetArray;
  i: Integer;
begin
  if w = nil then
    Exit;

  if WidgetIsVisible(w) then
    w.Update(dt);

  children := w.GetChildren;
  for i := Low(children) to High(children) do
    UpdateWidget(children[i], dt);
end;

procedure TWidgetSystem.RenderWidget(w: IWidget; r: IRenderer);
var
  children: TWidgetArray;
  i: Integer;
begin
  if w = nil then
    Exit;

  if WidgetShouldRender(w) then
    w.Render(r);

  children := w.GetChildren;
  for i := Low(children) to High(children) do
    RenderWidget(children[i], r);
end;

procedure TWidgetSystem.DestroyAll;
begin
  FRoot.Free;
  FRoot := nil;
  FWidgets.Clear;
end;

end.
