unit DoomScene;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, Core.Contracts, BaseWidget, DoomEnemy, DoomAssets;

type
  TEnemyReachedEvent = procedure(dmg: Integer) of object;
  TEnemyKilledEvent = procedure(score: Integer) of object;

  TDoomScene = class(TBaseWidget)
  private
    FEnemies:    array of TDoomEnemy;
    FBullets:    array of TBullet;
    FParticles:  array of TParticle;
    FSpawnTimer: Single;
    FSpawnInterval: Single;
    FScore:      Integer;
    FPlayerDead: Boolean;
    FFrameN:     Integer;

    FImpImg:      IImage;
    FDemonImg:    IImage;
    FCacoImg:     IImage;
    FBaronImg:    IImage;
    FGunImg:      IImage;
    FBulletImg:   IImage;
    FBloodImg:    IImage;
    FSceneBgImg:  IImage;

    procedure SpawnEnemy;
    procedure UpdateEnemies(dt: Single);
    procedure UpdateBullets(dt: Single);
    procedure UpdateParticles(dt: Single);
    procedure DrawEnemySprite(r: IRenderer; const e: TDoomEnemy);
    procedure DrawBackground(r: IRenderer);
    procedure DrawGun(r: IRenderer);
    procedure SpawnBlood(x, y: Single; count: Integer);
  public
    OnEnemyReached: TEnemyReachedEvent;
    OnEnemyKilled: TEnemyKilledEvent;

    constructor Create(const aID: String; const assets: TDoomAssets);
    procedure Update(dt: Single); override;
    procedure Render(r: IRenderer); override;
    procedure Fire(fromX, fromY: Integer);
    function GetScore: Integer;
  end;

implementation

function MakeRect(x, y, w, h: Integer): TRect;
begin
  Result.x := x;
  Result.y := y;
  Result.w := w;
  Result.h := h;
end;

constructor TDoomScene.Create(const aID: String; const assets: TDoomAssets);
begin
  inherited Create(aID);
  FSpawnTimer := 3.0;
  FSpawnInterval := 3.0;
  FScore := 0;
  FPlayerDead := False;
  FFrameN := 0;

  FImpImg     := assets.Imp;
  FDemonImg   := assets.Demon;
  FCacoImg    := assets.Cacodemon;
  FBaronImg   := assets.Baron;
  FGunImg     := assets.Gun;
  FBulletImg  := assets.Bullet;
  FBloodImg   := assets.Blood;
  FSceneBgImg := assets.SceneBg;
end;

procedure TDoomScene.SpawnEnemy;
var
  kind: TEnemyKind;
  roll: Single;
begin
  // Выбор типа врага с весами
  roll := Random;
  if roll < 0.60 then
    kind := ekImp
  else if roll < 0.85 then
    kind := ekDemon
  else if roll < 0.97 then
    kind := ekCacodemon
  else
    kind := ekBaron;
  
  SetLength(FEnemies, Length(FEnemies) + 1);
  FEnemies[High(FEnemies)] := CreateEnemy(kind);
end;

procedure TDoomScene.UpdateEnemies(dt: Single);
var
  i: Integer;
begin
  for i := High(FEnemies) downto 0 do
  begin
    if not FEnemies[i].Alive then
    begin
      // Удаляем мёртвых врагов
      if i < High(FEnemies) then
        FEnemies[i] := FEnemies[High(FEnemies)];
      SetLength(FEnemies, Length(FEnemies) - 1);
      Continue;
    end;
    
    UpdateEnemy(FEnemies[i], dt);
    
    // Враг дошёл до игрока
    if FEnemies[i].Depth >= 1.0 then
    begin
      if Assigned(OnEnemyReached) then
        OnEnemyReached(EnemyStats[FEnemies[i].Kind].Damage);
      
      FEnemies[i].Alive := False;
    end;
  end;
end;

procedure TDoomScene.UpdateBullets(dt: Single);
var
  i, j: Integer;
  bx, by: Integer;
  hit: Boolean;
  bounds: TRect;
begin
  bounds := GetBounds;
  
  for i := High(FBullets) downto 0 do
  begin
    if not FBullets[i].Alive then
    begin
      if i < High(FBullets) then
        FBullets[i] := FBullets[High(FBullets)];
      SetLength(FBullets, Length(FBullets) - 1);
      Continue;
    end;
    
    // Движение пули
    FBullets[i].X := FBullets[i].X + FBullets[i].VX * dt * 600;
    FBullets[i].Y := FBullets[i].Y + FBullets[i].VY * dt * 600;
    
    bx := Round(FBullets[i].X);
    by := Round(FBullets[i].Y);
    
    // Проверка столкновения с врагами
    hit := False;
    for j := 0 to High(FEnemies) do
    begin
      if not FEnemies[j].Alive then Continue;
      
      if HitTestBullet(FEnemies[j], bx, by, bounds.w, bounds.h) then
      begin
        // Попадание
        Dec(FEnemies[j].HP);
        FEnemies[j].HitTimer := 8;
        
        // Кровь
        SpawnBlood(bx, by, 5);
        
        if FEnemies[j].HP <= 0 then
        begin
          // Убит
          FEnemies[j].Alive := False;
          SpawnBlood(bx, by, 15);
          
          if Assigned(OnEnemyKilled) then
            OnEnemyKilled(EnemyStats[FEnemies[j].Kind].ScoreValue);
        end;
        
        hit := True;
        Break;
      end;
    end;
    
    if hit or (by < 0) or (bx < 0) or (bx > bounds.w) then
      FBullets[i].Alive := False;
  end;
end;

procedure TDoomScene.UpdateParticles(dt: Single);
var
  i: Integer;
begin
  for i := High(FParticles) downto 0 do
  begin
    FParticles[i].X := FParticles[i].X + FParticles[i].VX * dt * 60;
    FParticles[i].Y := FParticles[i].Y + FParticles[i].VY * dt * 60;
    FParticles[i].VY := FParticles[i].VY + 0.5 * dt;  // Гравитация
    FParticles[i].Life := FParticles[i].Life - dt;
    
    if FParticles[i].Life <= 0 then
    begin
      if i < High(FParticles) then
        FParticles[i] := FParticles[High(FParticles)];
      SetLength(FParticles, Length(FParticles) - 1);
    end;
  end;
end;

procedure TDoomScene.SpawnBlood(x, y: Single; count: Integer);
var
  i: Integer;
begin
  for i := 1 to count do
  begin
    SetLength(FParticles, Length(FParticles) + 1);
    with FParticles[High(FParticles)] do
    begin
      X := x;
      Y := y;
      VX := (Random - 0.5) * 4;
      VY := -Random * 3;
      Life := 0.3 + Random * 0.3;
      MaxLife := Life;
      if Random < 0.5 then
        Color := $D44000
      else
        Color := $8B2500;
    end;
  end;
end;

procedure TDoomScene.DrawEnemySprite(r: IRenderer; const e: TDoomEnemy);
var
  rect: TRect;
  baseColor, eyeColor: LongWord;
  bounds: TRect;
  img: IImage;
  srcRect: TRect;
begin
  bounds := GetBounds;
  rect := EnemyScreenRect(e, bounds.w, bounds.h);

  case e.Kind of
    ekImp:      img := FImpImg;
    ekDemon:    img := FDemonImg;
    ekCacodemon:img := FCacoImg;
    ekBaron:    img := FBaronImg;
  else
    img := nil;
  end;

  if (img <> nil) and (img.GetHandle <> nil) then
  begin
    srcRect.x := 0; srcRect.y := 0;
    srcRect.w := img.GetWidth; srcRect.h := img.GetHeight;
    r.DrawImage(img, srcRect, rect);
  end
  else
  begin
    case e.Kind of
      ekImp:
        begin
          baseColor := $8B4513; eyeColor := $FF4400;
          r.DrawFilledRect(rect, baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 4, rect.y + rect.h div 4, 4, 4), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 2 + rect.w div 4 - 4, rect.y + rect.h div 4, 4, 4), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + 2, rect.y - 4, 4, 6), baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w - 6, rect.y - 4, 4, 6), baseColor);
        end;
      ekDemon:
        begin
          baseColor := $8B2500; eyeColor := $FF0000;
          r.DrawFilledRect(rect, baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 5, rect.y + rect.h div 3, 6, 6), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w - rect.w div 5 - 6, rect.y + rect.h div 3, 6, 6), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 4, rect.y + rect.h - 8, rect.w div 2, 4), $FFFFFF);
        end;
      ekCacodemon:
        begin
          baseColor := $6B0000; eyeColor := $00FF00;
          r.DrawFilledRect(rect, baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 3, rect.y + rect.h div 3, rect.w div 3, rect.h div 4), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 4, rect.y + rect.h * 2 div 3, rect.w div 2, rect.h div 5), $000000);
        end;
      ekBaron:
        begin
          baseColor := $4B2000; eyeColor := $FFFF00;
          r.DrawFilledRect(rect, baseColor);
          r.DrawFilledRect(MakeRect(rect.x + 2, rect.y - 12, 6, 14), baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w - 8, rect.y - 12, 6, 14), baseColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w div 4, rect.y + rect.h div 4, 8, 8), eyeColor);
          r.DrawFilledRect(MakeRect(rect.x + rect.w - rect.w div 4 - 8, rect.y + rect.h div 4, 8, 8), eyeColor);
        end;
    end;
  end;

  if e.HitTimer > 0 then
    r.DrawFilledRect(MakeRect(rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4), $40FF0000);

  r.DrawFilledRect(MakeRect(rect.x, rect.y - 6, rect.w, 4), $330000);
  r.DrawFilledRect(MakeRect(rect.x, rect.y - 6, rect.w * e.HP div e.MaxHP, 4), $D44000);
end;

procedure TDoomScene.DrawBackground(r: IRenderer);
var
  horizonY, cx: Integer;
  i: Integer;
  t: Single;
  yFloor: Integer;
  spread: Single;
  bounds: TRect;
  srcRect: TRect;
begin
  bounds := GetBounds;

  if (FSceneBgImg <> nil) and (FSceneBgImg.GetHandle <> nil) then
  begin
    srcRect.x := 0; srcRect.y := 0;
    srcRect.w := FSceneBgImg.GetWidth; srcRect.h := FSceneBgImg.GetHeight;
    r.DrawImage(FSceneBgImg, srcRect, MakeRect(bounds.x, bounds.y, bounds.w, bounds.h));
    Exit;
  end;

  r.DrawFilledRect(MakeRect(0, 0, bounds.w, bounds.h * 4 div 10), $0d1a0d);
  r.DrawFilledRect(MakeRect(0, bounds.h * 4 div 10, bounds.w, bounds.h * 6 div 10), $1a1000);

  horizonY := Round(bounds.h * 0.42);
  cx := bounds.w div 2;

  for i := 0 to 7 do
  begin
    t := i / 7;
    yFloor := horizonY + Round((bounds.h - horizonY) * t * t);
    spread := bounds.w * (0.05 + 0.45 * t);
    r.DrawRect(MakeRect(cx - Round(spread), yFloor, Round(spread * 2), 1), $2a1a04);
    if i > 0 then
    begin
      r.DrawRect(MakeRect(cx - Round(spread * 0.7) - 1, horizonY, 1, yFloor - horizonY), $1a1000);
      r.DrawRect(MakeRect(cx + Round(spread * 0.7), horizonY, 1, yFloor - horizonY), $1a1000);
    end;
  end;
end;

procedure TDoomScene.DrawGun(r: IRenderer);
var
  gunX, gunY, sway: Integer;
  bounds: TRect;
  srcRect, dstRect: TRect;
begin
  bounds := GetBounds;
  sway := Round(Sin(FFrameN * 0.1) * 3);

  if (FGunImg <> nil) and (FGunImg.GetHandle <> nil) then
  begin
    gunX := bounds.w div 2 - FGunImg.GetWidth div 2;
    gunY := bounds.h - FGunImg.GetHeight + sway;
    srcRect.x := 0; srcRect.y := 0;
    srcRect.w := FGunImg.GetWidth; srcRect.h := FGunImg.GetHeight;
    dstRect := MakeRect(gunX, gunY, FGunImg.GetWidth, FGunImg.GetHeight);
    r.DrawImage(FGunImg, srcRect, dstRect);
    Exit;
  end;

  gunX := bounds.w div 2 - 12;
  gunY := bounds.h - 50 + sway;
  r.DrawFilledRect(MakeRect(gunX + 8, gunY, 8, 40), $666666);
  r.DrawFilledRect(MakeRect(gunX, gunY - 16, 24, 16), $555555);
  r.DrawFilledRect(MakeRect(gunX + 4, gunY - 12, 16, 4), $777777);
end;

procedure TDoomScene.Update(dt: Single);
begin
  inherited Update(dt);
  
  if FPlayerDead then Exit;
  
  Inc(FFrameN);
  
  // Спавн врагов
  FSpawnTimer := FSpawnTimer - dt;
  if FSpawnTimer <= 0 then
  begin
    SpawnEnemy;
    FSpawnTimer := FSpawnInterval;
    FSpawnInterval := Max(0.8, FSpawnInterval - 0.05);
  end;
  
  UpdateEnemies(dt);
  UpdateBullets(dt);
  UpdateParticles(dt);
end;

procedure TDoomScene.Render(r: IRenderer);
var
  i: Integer;
  crossX, crossY: Integer;
  bounds, srcRect: TRect;
begin
  if r = nil then Exit;
  WriteLn('Scene.Render begin');

  bounds := GetBounds;

  // Фон
  WriteLn('Scene.DrawBg');
  DrawBackground(r);
  WriteLn('Scene.DrawBg done');
  
  // Враги (сортировка по глубине - дальние первыми)
  for i := High(FEnemies) downto 0 do
    if FEnemies[i].Alive then
      DrawEnemySprite(r, FEnemies[i]);
  
  // Пули
  for i := 0 to High(FBullets) do
    if FBullets[i].Alive then
    begin
      if (FBulletImg <> nil) and (FBulletImg.GetHandle <> nil) then
      begin
        srcRect.x := 0; srcRect.y := 0;
        srcRect.w := FBulletImg.GetWidth; srcRect.h := FBulletImg.GetHeight;
        r.DrawImage(FBulletImg, srcRect,
          MakeRect(Round(FBullets[i].X) - FBulletImg.GetWidth div 2,
                   Round(FBullets[i].Y) - FBulletImg.GetHeight div 2,
                   FBulletImg.GetWidth, FBulletImg.GetHeight));
      end
      else
        r.DrawFilledRect(MakeRect(Round(FBullets[i].X) - 2, Round(FBullets[i].Y) - 2, 4, 4), $FFFF00);
    end;

  // Частицы крови
  for i := 0 to High(FParticles) do
  begin
    if (FBloodImg <> nil) and (FBloodImg.GetHandle <> nil) then
    begin
      srcRect.x := 0; srcRect.y := 0;
      srcRect.w := FBloodImg.GetWidth; srcRect.h := FBloodImg.GetHeight;
      r.DrawImage(FBloodImg, srcRect,
        MakeRect(Round(FParticles[i].X), Round(FParticles[i].Y),
                 FBloodImg.GetWidth, FBloodImg.GetHeight));
    end
    else
      r.DrawFilledRect(
        MakeRect(Round(FParticles[i].X), Round(FParticles[i].Y), 3, 3),
        FParticles[i].Color
      );
  end;
  
  // Прицел
  crossX := bounds.w div 2;
  crossY := bounds.h div 2;
  r.DrawRect(MakeRect(crossX - 8, crossY, 16, 1), $00FF00);
  r.DrawRect(MakeRect(crossX, crossY - 8, 1, 16), $00FF00);

  // Пушка
  WriteLn('Scene.DrawGun');
  DrawGun(r);
  WriteLn('Scene.Render done');
end;

procedure TDoomScene.Fire(fromX, fromY: Integer);
var
  bullet: TBullet;
  bounds: TRect;
begin
  bounds := GetBounds;
  
  bullet.X := fromX;
  bullet.Y := fromY;
  bullet.VX := (fromX - bounds.w / 2) / bounds.w * 0.3;
  bullet.VY := -0.9;
  bullet.Alive := True;
  
  SetLength(FBullets, Length(FBullets) + 1);
  FBullets[High(FBullets)] := bullet;
end;

function TDoomScene.GetScore: Integer;
begin
  Result := FScore;
end;

end.
