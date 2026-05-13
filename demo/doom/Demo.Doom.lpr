program DemoDoom;

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
  DoomSkins,
  DoomAssets,
  DoomHUD,
  DoomScene,
  DoomGame;

var
  renderer:      TSDL2Renderer;
  loaderSprites: TSDL2ImageLoader;
  loaderBgs:     TSDL2ImageLoader;
  rmSprites:     TResourceManager;
  rmBgs:         TResourceManager;
  assets:        TDoomAssets;
  font:          IFont;
  api:           TSDL2WidgetAPI;
  game:          TDoomGame;
  lastTicks, nowTicks: UInt32;
  dt:            Single;
  fontPath:      String;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  if SDL_Init(SDL_INIT_VIDEO) <> 0 then
    raise Exception.Create('SDL_Init failed: ' + SDL_GetError);

  if TTF_Init <> 0 then
    raise Exception.Create('TTF_Init failed: ' + SDL_GetError);

  try
    renderer := TSDL2Renderer.CreateWithWindow('DOOM WidgetLib Demo', 800, 600);

    try
      loaderSprites := TSDL2ImageLoader.Create(renderer.GetRenderer);
      loaderSprites.EnableColorKey(0, 0, 0);
      rmSprites := TResourceManager.Create(loaderSprites, TSDL2FontLoader.Create);

      loaderBgs := TSDL2ImageLoader.Create(renderer.GetRenderer);
      rmBgs := TResourceManager.Create(loaderBgs, nil);

      try
        fontPath := 'assets/fonts/DoomFont.ttf';
        {$IFDEF DARWIN}
        if not FileExists(fontPath) then
          fontPath := '/System/Library/Fonts/Helvetica.ttc';
        {$ENDIF}
        {$IFDEF LINUX}
        if not FileExists(fontPath) then
          fontPath := '/usr/share/fonts/truetype/freefont/FreeMono.ttf';
        {$ENDIF}

        font := rmSprites.GetFont(fontPath, 14);

        LoadDoomAssets(rmSprites, rmBgs, assets, 'assets');
        LoadDoomSkins(GlobalSkinManager, rmSprites);

        api := TSDL2WidgetAPI.Create(renderer, rmSprites, GlobalSkinManager, True);

        try
          game := TDoomGame.Create(api, font, assets);

          try
            lastTicks := SDL_GetTicks;

            while game.IsRunning do
            begin
              nowTicks  := SDL_GetTicks;
              dt        := (nowTicks - lastTicks) / 1000.0;
              lastTicks := nowTicks;
              if dt > 0.1 then dt := 0.1;

              game.ProcessInput;
              game.Update(dt);
              game.Render;

              SDL_Delay(1);
            end;

          finally
            game.Free;
          end;

        finally
          api.Free;
        end;

      finally
        rmSprites.Free;
        rmBgs.Free;
        loaderSprites.Free;
        loaderBgs.Free;
      end;

    finally
      renderer.Free;
    end;

  finally
    TTF_Quit;
    SDL_Quit;
  end;
end.
