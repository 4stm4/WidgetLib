unit DoomSkins;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Core.Contracts, SkinSystem, ResourceManager;

procedure LoadDoomSkins(sm: TSkinManager; rm: TResourceManager);
function GetDoomTextColor(state: TWidgetState): LongWord;

implementation

procedure LoadDoomSkins(sm: TSkinManager; rm: TResourceManager);
var
  skin: ISkin;
begin
  // Doom brown - основной коричневый металл
  skin := TColorSkin.Create(
    $2a1a08,  // normal fill
    $3a2a10,  // hover fill
    $1a0d04,  // active fill
    $1a1208,  // disabled fill
    $8B4513   // border
  );
  sm.RegisterSkin('doom_brown', skin);

  // Doom gray - стальной серый
  skin := TColorSkin.Create(
    $1a1a1a,  // normal
    $2a2a2a,  // hover
    $0d0d0d,  // active
    $111111,  // disabled
    $5a5a5a   // border
  );
  sm.RegisterSkin('doom_gray', skin);

  // Doom red - адский красный
  skin := TColorSkin.Create(
    $1a0000,  // normal
    $2a0500,  // hover
    $3a0800,  // active
    $0d0000,  // disabled
    $8B2500   // border
  );
  sm.RegisterSkin('doom_red', skin);

  // Doom green - токсичный зелёный
  skin := TColorSkin.Create(
    $001a00,  // normal
    $002a00,  // hover
    $003a00,  // active
    $000d00,  // disabled
    $2a8B00   // border
  );
  sm.RegisterSkin('doom_green', skin);

  // Doom HUD background
  skin := TColorSkin.Create(
    $1a0a00,  // normal fill
    $1a0a00,  // hover
    $1a0a00,  // active
    $1a0a00,  // disabled
    $8B2500   // border
  );
  sm.RegisterSkin('doom_hud_bg', skin);
end;

function GetDoomTextColor(state: TWidgetState): LongWord;
begin
  case state of
    wsNormal:   Result := $D44000;  // оранжевый
    wsHover:    Result := $FF6600;  // яркий оранжевый
    wsActive:   Result := $FF8C00;  // тёмный оранжевый
    wsDisabled: Result := $5a3a18;  // коричневый
  else
    Result := $D44000;
  end;
end;

end.
