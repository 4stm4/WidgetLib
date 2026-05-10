unit DoomEnemy;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Core.Contracts;

const
  HUD_HEIGHT = 58;

type
  TEnemyKind = (
    ekImp,
    ekDemon,
    ekCacodemon,
    ekBaron
  );

  TDoomEnemy = record
    Kind:       TEnemyKind;
    X:          Single;     // 0.0..1.0 (нормализованная позиция)
    Depth:      Single;     // 0.0..1.0 (0=далеко, 1=вплотную)
    HP:         Integer;
    MaxHP:      Integer;
    Speed:      Single;     // глубина/сек
    HitTimer:   Integer;    // кадры мигания после попадания
    Alive:      Boolean;
  end;

  TBullet = record
    X, Y:       Single;
    VX, VY:     Single;
    Alive:      Boolean;
  end;

  TParticle = record
    X, Y:       Single;
    VX, VY:     Single;
    Life:       Single;
    MaxLife:    Single;
    Color:      LongWord;
  end;

const
  EnemyStats: array[TEnemyKind] of record
    HP:           Integer;
    Speed:        Single;
    ScoreValue:   Integer;
    ScreenSize:   Integer;
    Damage:       Integer;
  end = (
    (HP: 2;  Speed: 0.08; ScoreValue: 100;  ScreenSize: 32; Damage: 10),  // ekImp
    (HP: 4;  Speed: 0.05; ScoreValue: 250;  ScreenSize: 48; Damage: 15),  // ekDemon
    (HP: 6;  Speed: 0.04; ScoreValue: 500;  ScreenSize: 56; Damage: 20),  // ekCacodemon
    (HP: 12; Speed: 0.03; ScoreValue: 1000; ScreenSize: 72; Damage: 30)   // ekBaron
  );

function CreateEnemy(kind: TEnemyKind): TDoomEnemy;
procedure UpdateEnemy(var e: TDoomEnemy; dt: Single);
function EnemyScreenRect(const e: TDoomEnemy; screenW, screenH: Integer): TRect;
function HitTestBullet(const e: TDoomEnemy; bx, by: Integer; screenW, screenH: Integer): Boolean;

implementation

function CreateEnemy(kind: TEnemyKind): TDoomEnemy;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := kind;
  Result.X := 0.3 + Random * 0.4;  // 30%-70% ширины экрана
  Result.Depth := 0.0;
  Result.HP := EnemyStats[kind].HP;
  Result.MaxHP := EnemyStats[kind].HP;
  Result.Speed := EnemyStats[kind].Speed;
  Result.HitTimer := 0;
  Result.Alive := True;
end;

procedure UpdateEnemy(var e: TDoomEnemy; dt: Single);
begin
  if not e.Alive then Exit;
  
  e.Depth := e.Depth + e.Speed * dt;
  
  if e.HitTimer > 0 then
    Dec(e.HitTimer);
end;

function EnemyScreenRect(const e: TDoomEnemy; screenW, screenH: Integer): TRect;
var
  size: Single;
  centerX, centerY: Single;
  sceneH: Integer;
begin
  sceneH := screenH - HUD_HEIGHT;
  
  // Размер зависит от глубины
  size := EnemyStats[e.Kind].ScreenSize * (0.2 + e.Depth * 4.0);
  
  // Центр X
  centerX := e.X * screenW;
  
  // Центр Y (Cacodemon летит выше)
  if e.Kind = ekCacodemon then
    centerY := sceneH * 0.42
  else
    centerY := sceneH * 0.52;
  
  Result.x := Round(centerX - size / 2);
  Result.y := Round(centerY - size / 2);
  Result.w := Round(size);
  Result.h := Round(size);
end;

function HitTestBullet(const e: TDoomEnemy; bx, by: Integer; screenW, screenH: Integer): Boolean;
var
  rect: TRect;
begin
  rect := EnemyScreenRect(e, screenW, screenH);
  Result := (bx >= rect.x) and (bx < rect.x + rect.w) and
            (by >= rect.y) and (by < rect.y + rect.h);
end;

end.
