unit DoomAssets;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Core.Contracts, ResourceManager;

type
  TDoomAssets = record
    Imp, Demon, Cacodemon, Baron: IImage;
    Gun: IImage;
    Bullet, Blood: IImage;
    FaceFine, FaceHurt, FaceBad, FaceDead, FaceOuch: IImage;
    HudBg, SceneBg: IImage;
  end;

procedure LoadDoomAssets(rmSprites, rmBackgrounds: TResourceManager;
                         out assets: TDoomAssets; const dir: String);

implementation

function TryLoad(rm: TResourceManager; const path: String): IImage;
begin
  Result := nil;
  if rm = nil then Exit;
  try
    Result := rm.GetImage(path);
  except
    Result := nil;
  end;
end;

procedure LoadDoomAssets(rmSprites, rmBackgrounds: TResourceManager;
                         out assets: TDoomAssets; const dir: String);
begin
  FillChar(assets, SizeOf(assets), 0);

  assets.Imp       := TryLoad(rmSprites, dir + '/sprites/imp.bmp');
  assets.Demon     := TryLoad(rmSprites, dir + '/sprites/demon.bmp');
  assets.Cacodemon := TryLoad(rmSprites, dir + '/sprites/cacodemon.bmp');
  assets.Baron     := TryLoad(rmSprites, dir + '/sprites/baron.bmp');
  assets.Gun       := TryLoad(rmSprites, dir + '/sprites/gun.bmp');
  assets.Bullet    := TryLoad(rmSprites, dir + '/sprites/bullet.bmp');
  assets.Blood     := TryLoad(rmSprites, dir + '/sprites/blood.bmp');

  assets.FaceFine  := TryLoad(rmSprites, dir + '/hud/face_fine.bmp');
  assets.FaceHurt  := TryLoad(rmSprites, dir + '/hud/face_hurt.bmp');
  assets.FaceBad   := TryLoad(rmSprites, dir + '/hud/face_bad.bmp');
  assets.FaceDead  := TryLoad(rmSprites, dir + '/hud/face_dead.bmp');
  assets.FaceOuch  := TryLoad(rmSprites, dir + '/hud/face_ouch.bmp');

  assets.HudBg     := TryLoad(rmBackgrounds, dir + '/backgrounds/hud_bg.bmp');
  assets.SceneBg   := TryLoad(rmBackgrounds, dir + '/backgrounds/scene_bg.bmp');
end;

end.
