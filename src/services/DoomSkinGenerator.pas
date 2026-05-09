unit DoomSkinGenerator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SDL2, Core.Contracts, ResourceManager, SkinSystem;

type
  TDoomSkinGenerator = class
  public
    constructor Create(renderer: PSDL_Renderer);
    
    procedure RegisterDoomSkins(rm: TResourceManager; sm: TSkinManager);
  end;

implementation

constructor TDoomSkinGenerator.Create(renderer: PSDL_Renderer);
begin
  inherited Create;
end;

procedure TDoomSkinGenerator.RegisterDoomSkins(rm: TResourceManager; sm: TSkinManager);
var
  skin: ISkin;
begin
  // Brown metal (Doom style) - colors in 0xRRGGBB format
  skin := TColorSkin.Create(
    $8B4513,  // Saddle brown (normal)
    $A0522D,  // Sienna (hover - lighter)
    $654321,  // Dark brown (active - pressed)
    $696969,  // Dim gray (disabled)
    $4A3728   // Dark brown border
  );
  sm.RegisterSkin('doom_brown', skin);
  
  // Gray metal
  skin := TColorSkin.Create(
    $708090,  // Slate gray (normal)
    $778899,  // Light slate gray (hover)
    $4A5568,  // Dark slate (active)
    $696969,  // Dim gray (disabled)
    $2F3640   // Dark border
  );
  sm.RegisterSkin('doom_gray', skin);
  
  // Red metal (hellish)
  skin := TColorSkin.Create(
    $8B0000,  // Dark red (normal)
    $B22222,  // Firebrick (hover)
    $660000,  // Very dark red (active)
    $696969,  // Dim gray (disabled)
    $4A0000   // Black-red border
  );
  sm.RegisterSkin('doom_red', skin);
  
  // Green tech
  skin := TColorSkin.Create(
    $2E8B57,  // Sea green (normal)
    $3CB371,  // Medium sea green (hover)
    $1C5E3A,  // Dark green (active)
    $696969,  // Dim gray (disabled)
    $0F3D26   // Dark green border
  );
  sm.RegisterSkin('doom_green', skin);
  
  // Blue tech
  skin := TColorSkin.Create(
    $4682B4,  // Steel blue (normal)
    $5F9EA0,  // Cadet blue (hover)
    $2E5A7E,  // Dark steel (active)
    $696969,  // Dim gray (disabled)
    $1C3A50   // Dark blue border
  );
  sm.RegisterSkin('doom_blue', skin);
end;

end.
