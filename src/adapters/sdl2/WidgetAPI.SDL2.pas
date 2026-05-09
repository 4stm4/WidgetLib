unit WidgetAPI.SDL2;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  SDL2,
  Core.Contracts,
  WidgetSystem,
  SDL2InputBridge,
  SDL2Renderer,
  ResourceManager,
  SkinSystem,
  JSONWidgetLoader,
  BasicWidgets;

type
  TSDL2WidgetAPI = class
  private
    FSystem: TWidgetSystem;
    FBridge: TSDL2InputBridge;
    FRenderer: TSDL2Renderer;
    FLoader: TJSONWidgetLoader;
    FResourceManager: TResourceManager;
    FOwnsRenderer: Boolean;

    function FindWidgetByIDRecursive(w: IWidget; const id: String): IWidget;
  public
    constructor Create(renderer: TSDL2Renderer; rm: TResourceManager; sm: TSkinManager; ownsRenderer: Boolean = False);
    destructor Destroy; override;

    procedure ProcessInput;
    procedure Update(dt: Single);
    procedure Render;

    procedure LoadUI(const jsonPath: String);
    function GetWidget(const id: String): IWidget;

    function GetRenderer: TSDL2Renderer;
    function GetWidgetSystem: TWidgetSystem;
  end;

implementation

function TSDL2WidgetAPI.FindWidgetByIDRecursive(w: IWidget; const id: String): IWidget;
var
  children: TWidgetArray;
  i: Integer;
begin
  Result := nil;
  if (w = nil) or (id = '') then
    Exit;

  if SameText(w.GetID, id) then
    Exit(w);

  children := w.GetChildren;
  for i := Low(children) to High(children) do
  begin
    Result := FindWidgetByIDRecursive(children[i], id);
    if Result <> nil then
      Exit;
  end;
end;

constructor TSDL2WidgetAPI.Create(renderer: TSDL2Renderer; rm: TResourceManager; sm: TSkinManager; ownsRenderer: Boolean = False);
begin
  inherited Create;

  FRenderer := renderer;
  FResourceManager := rm;
  FOwnsRenderer := ownsRenderer;

  FSystem := TWidgetSystem.Create;
  FBridge := TSDL2InputBridge.Create;

  // JSON loader needs widget system + resource manager
  FLoader := TJSONWidgetLoader.Create(FSystem, rm);

  // sm is kept for API compatibility but skin usage is handled elsewhere
  if sm = nil then
    ; // no-op
end;

destructor TSDL2WidgetAPI.Destroy;
begin
  FLoader.Free;
  FBridge.Free;
  FSystem.Free;

  if FOwnsRenderer and (FRenderer <> nil) then
    FRenderer.Free;

  inherited Destroy;
end;

procedure TSDL2WidgetAPI.ProcessInput;
begin
  // Poll SDL2 events and post into event system
  if Assigned(FBridge) and Assigned(FSystem) then
    FBridge.PollAndPost(FSystem.EventSystem);

  // Dispatch queued events through widget tree
  if Assigned(FSystem) then
    FSystem.EventSystem.Dispatch;
end;

procedure TSDL2WidgetAPI.Update(dt: Single);
var
  nowMs: LongWord;
begin
  if FSystem = nil then
    Exit;

  // Tick timers and update widget tree
  nowMs := SDL_GetTicks;
  if FSystem.EventSystem <> nil then
    FSystem.EventSystem.Tick(nowMs);

  FSystem.Update(dt);
end;

procedure TSDL2WidgetAPI.Render;
begin
  if (FSystem = nil) or (FRenderer = nil) then
    Exit;

  // WidgetSystem handles BeginFrame/EndFrame around Render calls
  FSystem.Render(FRenderer);
end;

procedure TSDL2WidgetAPI.LoadUI(const jsonPath: String);
var
  sl: TStringList;
  json: String;
  newRoot: IWidget;
begin
  if FSystem = nil then
    Exit;

  if jsonPath = '' then
    raise Exception.Create('LoadUI: jsonPath is empty');

  if not FileExists(jsonPath) then
    raise Exception.Create('LoadUI: file not found: ' + jsonPath);

  // Reset previous UI
  FSystem.DestroyAll;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(jsonPath);
    json := sl.Text;
  finally
    sl.Free;
  end;

  newRoot := FLoader.LoadFromJSON(json);
  if newRoot = nil then
    raise Exception.Create('LoadUI: JSONWidgetLoader returned nil root');

  FSystem.SetRoot(newRoot);
end;

function TSDL2WidgetAPI.GetWidget(const id: String): IWidget;
begin
  if FSystem = nil then
    Exit(nil);

  Result := FindWidgetByIDRecursive(FSystem.GetRoot, id);
end;

function TSDL2WidgetAPI.GetRenderer: TSDL2Renderer;
begin
  Result := FRenderer;
end;

function TSDL2WidgetAPI.GetWidgetSystem: TWidgetSystem;
begin
  Result := FSystem;
end;

end.
