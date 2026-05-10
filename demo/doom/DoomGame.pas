unit DoomGame;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, SDL2,
  Core.Contracts, BaseWidget, BasicWidgets,
  WidgetAPI.SDL2, ResourceManager, SkinSystem,
  DoomAssets, DoomHUD, DoomScene;

const
  // SDL Keycodes
  SDLK_ESCAPE = 27;
  SDLK_SPACE = 32;
  SDLK_LCTRL = 1073742048;
  SDLK_1 = 49;
  SDLK_2 = 50;
  SDLK_3 = 51;
  SDLK_4 = 52;
  SDLK_5 = 53;
  SDLK_6 = 54;
  SDLK_7 = 55;
  SDLK_0 = 48;
  
  SDL_SCANCODE_SPACE = 44;

type
  TDoomGame = class
  private
    FAPI: TSDL2WidgetAPI;
    FScene: TDoomScene;
    FHUD: TDoomHUD;
    FFont: IFont;
    
    FHealth: Integer;
    FArmor: Integer;
    FBullets: Integer;
    FScore: Integer;
    FWeapon: Integer;
    
    FRunning: Boolean;
    FPaused: Boolean;
    FGameOver: Boolean;
    
    FOverlayLabel: TLabel;
    
    procedure HandleEnemyReached(dmg: Integer);
    procedure HandleEnemyKilled(score: Integer);
    procedure GameOver;
  public
    constructor Create(api: TSDL2WidgetAPI; font: IFont; const assets: TDoomAssets);
    destructor Destroy; override;
    
    procedure ProcessInput;
    procedure Update(dt: Single);
    procedure Render;
    
    function IsRunning: Boolean;
  end;

implementation

function MakeRect(x, y, w, h: Integer): TRect;
begin
  Result.x := x;
  Result.y := y;
  Result.w := w;
  Result.h := h;
end;

constructor TDoomGame.Create(api: TSDL2WidgetAPI; font: IFont; const assets: TDoomAssets);
var
  root: TBaseWidget;
begin
  inherited Create;

  FAPI := api;
  FFont := font;

  root := TBaseWidget.Create('root');
  root.SetBounds(MakeRect(0, 0, 800, 600));

  FScene := TDoomScene.Create('scene', assets);
  FScene.SetBounds(MakeRect(0, 0, 800, 542));
  FScene.OnEnemyReached := @HandleEnemyReached;
  FScene.OnEnemyKilled := @HandleEnemyKilled;

  FHUD := TDoomHUD.Create('hud', font, assets);
  FHUD.SetBounds(MakeRect(0, 542, 800, 58));
  
  // Добавляем в дерево
  root.AddChild(FScene);
  root.AddChild(FHUD);
  
  // Добавляем root в систему виджетов
  FAPI.GetWidgetSystem.SetRoot(root);
  
  // Начальные значения
  FHealth := 100;
  FArmor := 50;
  FBullets := 50;
  FScore := 0;
  FWeapon := 2;
  
  FRunning := True;
  FPaused := False;
  FGameOver := False;
  
  // Обновляем HUD
  FHUD.SetHealth(FHealth);
  FHUD.SetArmor(FArmor);
  FHUD.SetAmmo(FBullets);
  FHUD.SetWeapon(FWeapon);
end;

destructor TDoomGame.Destroy;
begin
  if FOverlayLabel <> nil then
    FOverlayLabel.Free;
  
  inherited Destroy;
end;

procedure TDoomGame.HandleEnemyReached(dmg: Integer);
var
  absorbed: Integer;
begin
  if FArmor > 0 then
  begin
    absorbed := Min(FArmor, dmg * 2 div 3);
    FArmor := FArmor - absorbed;
    FHealth := FHealth - (dmg - absorbed);
  end
  else
    FHealth := FHealth - dmg;
  
  FHealth := Max(0, FHealth);
  FArmor := Max(0, FArmor);
  
  FHUD.SetHealth(FHealth);
  FHUD.SetArmor(FArmor);
  FHUD.TakeDamage;
  
  if FHealth <= 0 then
    GameOver;
end;

procedure TDoomGame.HandleEnemyKilled(score: Integer);
begin
  FScore := FScore + score;
  FBullets := Min(200, FBullets + 2);
  
  FHUD.SetAmmo(FBullets);
  FHUD.SetScore(FScore);
end;

procedure TDoomGame.GameOver;
begin
  FGameOver := True;
  FRunning := False;
  
  // Оверлей "YOU DIED"
  FOverlayLabel := TLabel.Create('overlay');
  FOverlayLabel.Text := 'YOU DIED';
  FOverlayLabel.Color := $FF0000;
  FOverlayLabel.Font := FFont;
  FOverlayLabel.Align := alCenter;
  FOverlayLabel.SetBounds(MakeRect(0, 200, 800, 80));
  
  if FAPI.GetWidget('root') <> nil then
    FAPI.GetWidget('root').AddChild(FOverlayLabel);
end;

procedure TDoomGame.ProcessInput;
var
  event: TSDL_Event;
begin
  // Обработка SDL событий
  while SDL_PollEvent(@event) = 1 do
  begin
    case event.type_ of
      SDL_QUITEV:
        FRunning := False;
        
      SDL_KEYDOWN:
        begin
          case event.key.keysym.sym of
            SDLK_ESCAPE:
              FPaused := not FPaused;
              
            SDLK_SPACE, SDLK_LCTRL:
              if not FPaused and not FGameOver then
              begin
                if FBullets > 0 then
                begin
                  Dec(FBullets);
                  FHUD.SetAmmo(FBullets);
                  FScene.Fire(400, 520);
                end;
              end;
              
            SDLK_1..SDLK_7:
              begin
                FWeapon := event.key.keysym.sym - SDLK_0;
                if FWeapon = 1 then FWeapon := 2;  // Нет слота 1
                if FWeapon >= 2 then
                  FHUD.SetWeapon(FWeapon);
              end;
          end;
        end;
    end;
  end;
end;

procedure TDoomGame.Update(dt: Single);
begin
  if FPaused or FGameOver then
    Exit;
  
  FAPI.Update(dt);
  FScene.Update(dt);
end;

procedure TDoomGame.Render;
begin
  FAPI.Render;
end;

function TDoomGame.IsRunning: Boolean;
begin
  Result := FRunning;
end;

end.
