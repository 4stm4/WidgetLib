unit SkinSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Core.Contracts, ResourceManager;

type
  TImageSkin = class(ISkin)
  private
    FImages: array[TWidgetState] of IImage;
    FTextColors: array[TWidgetState] of LongWord;
  public
    constructor Create(rm: TResourceManager; const normalPath, hoverPath, activePath, disabledPath: String);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function GetTextColor(state: TWidgetState): LongWord; override;
  end;

  TColorSkin = class(ISkin)
  private
    FColors: array[TWidgetState] of LongWord;
    FBorderColor: LongWord;
  public
    constructor Create(
      normalColor, hoverColor, activeColor, disabledColor, borderColor: LongWord);
    procedure Draw(r: IRenderer; bounds: TRect; state: TWidgetState); override;
    function GetTextColor(state: TWidgetState): LongWord; override;
  end;

  TSkinManager = class
  private
    FSkinsMap: TFPHashMap;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RegisterSkin(const name: String; skin: ISkin);
    function GetSkin(const name: String): ISkin;
    procedure LoadDefaultSkins(rm: TResourceManager);
  end;

var
  GlobalSkinManager: TSkinManager = nil;

implementation

{ TImageSkin }

constructor TImageSkin.Create(rm: TResourceManager; 
  const normalPath, hoverPath, activePath, disabledPath: String);
var
  i: Integer;
begin
  inherited Create;
    if rm <> nil then
  begin
    FImages[wsNormal] := rm.GetImage(normalPath);
    FImages[wsHover] := rm.GetImage(hoverPath);
    FImages[wsActive] := rm.GetImage(activePath);
    FImages[wsDisabled] := rm.GetImage(disabledPath);
  end;
  
  for i := 0 to 3 do
    FTextColors[TWidgetState(i)] := $000000;
end;

procedure TImageSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
var
  img: IImage;
  srcRect: TRect;
begin
  if r = nil then Exit;
  img := FImages[state];
  if img = nil then Exit;
  
  srcRect.x := 0;
  srcRect.y := 0;
  srcRect.w := img.GetWidth;
  srcRect.h := img.GetHeight;
  
  r.DrawImage(img, srcRect, bounds);
end;

function TImageSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  Result := FTextColors[state];
end;

{ TColorSkin }

constructor TColorSkin.Create(
  normalColor, hoverColor, activeColor, disabledColor, borderColor: LongWord);
begin
  inherited Create;
  FColors[wsNormal] := normalColor;
  FColors[wsHover] := hoverColor;
  FColors[wsActive] := activeColor;
  FColors[wsDisabled] := disabledColor;
  FBorderColor := borderColor;
end;

procedure TColorSkin.Draw(r: IRenderer; bounds: TRect; state: TWidgetState);
begin
  if r = nil then Exit;
  
  // Colors are in 0xRRGGBB format
  r.DrawFilledRect(bounds, FColors[state]);
  
  if FBorderColor <> 0 then
    r.DrawRect(bounds, FBorderColor);
end;

function TColorSkin.GetTextColor(state: TWidgetState): LongWord;
begin
  // White text for all states
  case state of
    wsNormal: Result := $FFFFFF;
    wsHover: Result := $FFFF00;  // Yellow on hover
    wsActive: Result := $FF8800;  // Orange when pressed
    wsDisabled: Result := $888888;
  else
    Result := $FFFFFF;
  end;
end;

{ TSkinManager }

constructor TSkinManager.Create;
begin
  inherited Create;
  FSkinsMap := TFPHashMap.Create;
end;

destructor TSkinManager.Destroy;
begin
  FSkinsMap.Free;
  inherited Destroy;
end;

procedure TSkinManager.RegisterSkin(const name: String; skin: ISkin);
begin
  if skin = nil then Exit;
  FSkinsMap.Add(LowerCase(name), TObject(skin));
end;

function TSkinManager.GetSkin(const name: String): ISkin;
var
  obj: TObject;
  skin: ISkin absolute obj;
begin
  Result := nil;
  obj := TObject(FSkinsMap.Find(LowerCase(name)));
  if obj = nil then
    Exit;
  
  Result := skin;
end;

procedure TSkinManager.LoadDefaultSkins(rm: TResourceManager);
var
  defaultSkin, blueSkin, greenSkin, redSkin, darkSkin: TColorSkin;
begin
  // Default gray skin
  defaultSkin := TColorSkin.Create(
    $E0E0E0,  // normal: light gray
    $D0D0D0,  // hover: slightly darker
    $A0A0A0,  // active: darker
    $C0C0C0,  // disabled: light gray
    $000000   // border: black
  );
  RegisterSkin('default', defaultSkin);

  // Blue skin
  blueSkin := TColorSkin.Create(
    $4A90D9,  // normal: blue
    $5AA0E9,  // hover: lighter blue
    $3A80C9,  // active: darker blue
    $7AB0F9,  // disabled: light blue
    $2A70B9   // border: dark blue
  );
  RegisterSkin('blue', blueSkin);

  // Green skin
  greenSkin := TColorSkin.Create(
    $4CAF50,  // normal: green
    $5CBF60,  // hover: lighter green
    $3C9F40,  // active: darker green
    $7CDF80,  // disabled: light green
    $2C8F30   // border: dark green
  );
  RegisterSkin('green', greenSkin);

  // Red skin
  redSkin := TColorSkin.Create(
    $F44336,  // normal: red
    $F45346,  // hover: lighter red
    $D43326,  // active: darker red
    $F47376,  // disabled: light red
    $C42316   // border: dark red
  );
  RegisterSkin('red', redSkin);

  // Dark skin
  darkSkin := TColorSkin.Create(
    $333333,  // normal: dark gray
    $444444,  // hover: slightly lighter
    $222222,  // active: darker
    $555555,  // disabled: medium gray
    $666666   // border: gray
  );
  RegisterSkin('dark', darkSkin);
end;

initialization
  GlobalSkinManager := TSkinManager.Create;

finalization
  GlobalSkinManager.Free;

end.
