program DemoSDL2;

{$mode objfpc}{$H+}

uses
  SysUtils, Math,
  SDL2,
  SDL2_ttf,
  Core.Contracts,
  SDL2Renderer,
  SDL2ImageLoader,
  SDL2FontLoader,
  ResourceManager,
  SkinSystem,
  WidgetAPI.SDL2,
  Logger,
  BasicWidgets,
  EventSystem,
  DoomSkinGenerator;

type
  TApp = class
  public
    Running: Boolean;
    procedure QuitCommandHandler(const e: TWidgetEvent);
  end;

var
  renderer: TSDL2Renderer;
  res: TResourceManager;
  skins: TSkinManager;
  api: TSDL2WidgetAPI;
  app: TApp;
  lastTicks: UInt32 = 0;

procedure TApp.QuitCommandHandler(const e: TWidgetEvent);
begin
  Running := False;
end;

procedure RegisterQuitCommandHandler(w: IWidget; const quitCb: TCommandCallback);
var
  btn: TButton;
  children: TWidgetArray;
  i: Integer;
begin
  if w = nil then
    Exit;

  if w is TButton then
  begin
    btn := TButton(w);
    if SameText(btn.Command, 'app.quit') then
      btn.OnCommand := quitCb;
  end;

  children := w.GetChildren;
  for i := Low(children) to High(children) do
    RegisterQuitCommandHandler(children[i], quitCb);
end;

var
  dt: Single;
  nowTicks: UInt32;

begin
  // Disable FPU exceptions (common for SDL applications)
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  // SDL2 init
  if SDL_Init(SDL_INIT_VIDEO) <> 0 then
    raise Exception.Create('SDL_Init failed: ' + SDL_GetError);

  if TTF_Init <> 0 then
    raise Exception.Create('TTF_Init failed: ' + SDL_GetError);

  try
    // Create renderer with window (800x600)
    renderer := TSDL2Renderer.CreateWithWindow('SDL2 Widget Demo', 800, 600);

    try
      // Create resource manager with SDL2 loaders
      res := TResourceManager.Create(
        TSDL2ImageLoader.Create(renderer.GetRenderer),
        TSDL2FontLoader.Create
      );

      try
        // Use GlobalSkinManager (created in SkinSystem initialization)
        GlobalSkinManager.LoadDefaultSkins(res);
        
        // Add Doom-style skins
        with TDoomSkinGenerator.Create(renderer.GetRenderer) do
        try
          RegisterDoomSkins(res, GlobalSkinManager);
        finally
          Free;
        end;

        // Create widget API
        api := TSDL2WidgetAPI.Create(renderer, res, GlobalSkinManager, False);
        try
          api.LoadUI('demo.json');

          // Bind command handler for app.quit
          app := TApp.Create;
          app.Running := True;

          RegisterQuitCommandHandler(api.GetWidget('root'), @app.QuitCommandHandler);

          lastTicks := SDL_GetTicks;

          while app.Running do
          begin
            nowTicks := SDL_GetTicks;
            dt := (nowTicks - lastTicks) / 1000.0;
            lastTicks := nowTicks;

            api.ProcessInput;
            api.Update(dt);
            api.Render;

            // Small delay to prevent CPU spinning (SDL2 has VSync in renderer)
            SDL_Delay(1);
          end;

          app.Free;
        finally
          api.Free;
        end;

      finally
        res.Free;
      end;
    finally
      renderer.Free;
    end;
  finally
    TTF_Quit;
    SDL_Quit;
  end;
end.
