unit DoomHUD;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Core.Contracts, BaseWidget, BasicWidgets, DoomAssets;

type
  TFaceState = (
    fsFine,
    fsHurt,
    fsBad,
    fsDead,
    fsOuch
  );

  TAmmoKind = (
    akBullet,
    akShell,
    akRocket,
    akCell
  );

  TDoomFaceWidget = class(TBaseWidget)
  private
    FHealthPct: Integer;
    FState: TFaceState;
    FBlinkTimer: Integer;
    FFaceImages: array[TFaceState] of IImage;
    procedure UpdateState;
  public
    constructor Create(const aID: String);
    procedure SetFaceImages(fine, hurt, bad, dead, ouch: IImage);
    procedure Render(r: IRenderer); override;
    procedure Update(dt: Single); override;
    procedure SetHealth(pct: Integer);
    procedure GetHit;
  end;

  TAmmoCounterWidget = class(TBaseWidget)
  private
    FBullets, FMaxBullets: Integer;
    FShells, FMaxShells: Integer;
    FRockets, FMaxRockets: Integer;
    FCells, FMaxCells: Integer;
    FFont: IFont;
  public
    constructor Create(const aID: String; font: IFont);
    procedure Render(r: IRenderer); override;
    procedure SetAmmo(kind: TAmmoKind; current, max: Integer);
  end;

  TDoomHUD = class(TBaseWidget)
  private
    FAmmoLabel: TLabel;
    FAmmoText: TLabel;
    FHealthLabel: TLabel;
    FHealthText: TLabel;
    FArmsPanel: TBaseWidget;
    FFaceWidget: TDoomFaceWidget;
    FArmorLabel: TLabel;
    FArmorText: TLabel;
    FAmmoCounter: TAmmoCounterWidget;
    FWeaponSlots: array[2..7] of TLabel;
    FActiveWeapon: Integer;
    FFont: IFont;
    FHudBgImg: IImage;
    procedure UpdateWeaponHighlight;
  public
    constructor Create(const aID: String; font: IFont; const assets: TDoomAssets);
    procedure Render(r: IRenderer); override;
    procedure SetHealth(pct: Integer);
    procedure SetArmor(pct: Integer);
    procedure SetAmmo(bullets: Integer);
    procedure SetWeapon(slot: Integer);
    procedure TakeDamage;
    procedure SetScore(score: Integer);
  end;

implementation

function MakeRect(x, y, w, h: Integer): TRect;
begin
  Result.x := x;
  Result.y := y;
  Result.w := w;
  Result.h := h;
end;

{ TDoomFaceWidget }

constructor TDoomFaceWidget.Create(const aID: String);
var
  s: TFaceState;
begin
  inherited Create(aID);
  FHealthPct := 100;
  FState := fsFine;
  FBlinkTimer := 0;
  for s := Low(TFaceState) to High(TFaceState) do
    FFaceImages[s] := nil;
end;

procedure TDoomFaceWidget.SetFaceImages(fine, hurt, bad, dead, ouch: IImage);
begin
  FFaceImages[fsFine] := fine;
  FFaceImages[fsHurt] := hurt;
  FFaceImages[fsBad]  := bad;
  FFaceImages[fsDead] := dead;
  FFaceImages[fsOuch] := ouch;
end;

procedure TDoomFaceWidget.UpdateState;
begin
  if FHealthPct <= 0 then
    FState := fsDead
  else if FHealthPct < 30 then
    FState := fsBad
  else if FHealthPct <= 60 then
    FState := fsHurt
  else
    FState := fsFine;
end;

procedure TDoomFaceWidget.Render(r: IRenderer);
var
  bounds: TRect;
  cx, cy: Integer;
  eyeColor, pupilColor: LongWord;
  img: IImage;
  srcRect: TRect;
begin
  if r = nil then Exit;

  bounds := GetBounds;

  img := FFaceImages[FState];
  if (img <> nil) and (img.GetHandle <> nil) then
  begin
    srcRect.x := 0; srcRect.y := 0;
    srcRect.w := img.GetWidth; srcRect.h := img.GetHeight;
    r.DrawImage(img, srcRect, bounds);
    if (FState = fsOuch) and (FBlinkTimer mod 4 < 2) then
      r.DrawFilledRect(MakeRect(bounds.x + 2, bounds.y + 2, bounds.w - 4, bounds.h - 4), $40FF0000);
    Exit;
  end;

  cx := bounds.x + bounds.w div 2;
  cy := bounds.y + bounds.h div 2;

  r.DrawFilledRect(bounds, $5a3a18);
  r.DrawFilledRect(
    MakeRect(bounds.x + 8, bounds.y + 8, bounds.w - 16, bounds.h - 16),
    $C87941
  );

  eyeColor := $FFFFFF;
  pupilColor := $000000;

  r.DrawFilledRect(MakeRect(cx - 12, cy - 6, 6, 4), eyeColor);
  r.DrawFilledRect(MakeRect(cx + 6, cy - 6, 6, 4), eyeColor);

  if FState = fsDead then
  begin
    r.DrawFilledRect(MakeRect(cx - 11, cy - 6, 4, 1), $FF0000);
    r.DrawFilledRect(MakeRect(cx - 10, cy - 7, 1, 3), $FF0000);
    r.DrawFilledRect(MakeRect(cx + 7, cy - 6, 4, 1), $FF0000);
    r.DrawFilledRect(MakeRect(cx + 8, cy - 7, 1, 3), $FF0000);
  end
  else
  begin
    if FState = fsBad then
    begin
      r.DrawFilledRect(MakeRect(cx - 10, cy - 8, 3, 3), pupilColor);
      r.DrawFilledRect(MakeRect(cx + 8, cy - 8, 3, 3), pupilColor);
    end
    else
    begin
      r.DrawFilledRect(MakeRect(cx - 10, cy - 5, 3, 3), pupilColor);
      r.DrawFilledRect(MakeRect(cx + 8, cy - 5, 3, 3), pupilColor);
    end;
  end;

  case FState of
    fsFine:
      r.DrawFilledRect(MakeRect(cx - 6, cy + 8, 12, 2), $8B4513);
    fsHurt:
      begin
        r.DrawFilledRect(MakeRect(cx - 6, cy + 8, 12, 2), $8B4513);
        r.DrawFilledRect(MakeRect(cx + 4, cy + 6, 3, 2), $8B4513);
      end;
    fsBad:
      r.DrawFilledRect(MakeRect(cx - 8, cy + 6, 16, 4), $8B4513);
    fsDead:
      r.DrawFilledRect(MakeRect(cx - 8, cy + 6, 16, 6), $000000);
  end;

  if (FState = fsOuch) and (FBlinkTimer mod 4 < 2) then
    r.DrawFilledRect(MakeRect(bounds.x + 4, bounds.y + 4, bounds.w - 8, bounds.h - 8), $40FF0000);

  r.DrawRect(bounds, $8B4513);
end;

procedure TDoomFaceWidget.Update(dt: Single);
begin
  inherited Update(dt);
  
  if FBlinkTimer > 0 then
  begin
    Dec(FBlinkTimer);
    if FBlinkTimer = 0 then
      UpdateState;
  end;
end;

procedure TDoomFaceWidget.SetHealth(pct: Integer);
begin
  FHealthPct := pct;
  if FState <> fsOuch then
    UpdateState;
end;

procedure TDoomFaceWidget.GetHit;
begin
  FState := fsOuch;
  FBlinkTimer := 12;
end;

{ TAmmoCounterWidget }

constructor TAmmoCounterWidget.Create(const aID: String; font: IFont);
begin
  inherited Create(aID);
  FFont := font;
  FBullets := 200; FMaxBullets := 200;
  FShells := 50; FMaxShells := 50;
  FRockets := 50; FMaxRockets := 50;
  FCells := 300; FMaxCells := 300;
end;

procedure TAmmoCounterWidget.Render(r: IRenderer);
var
  bounds: TRect;
  y: Integer;
  
  procedure DrawAmmoLine(const label_: String; current, max: Integer; offsetY: Integer);
  var
    text: String;
    color: LongWord;
  begin
    // Метка
    r.DrawText(FFont, label_, bounds.x + 4, bounds.y + offsetY, $5a5a5a);
    
    // Текущее значение
    if current > 0 then
      color := $D44000
    else
      color := $5a5a5a;
    
    text := IntToStr(current);
    r.DrawText(FFont, text, bounds.x + 50, bounds.y + offsetY, color);
    
    // Разделитель
    r.DrawText(FFont, '/', bounds.x + 90, bounds.y + offsetY, $5a5a5a);
    
    // Максимум
    text := IntToStr(max);
    r.DrawText(FFont, text, bounds.x + 100, bounds.y + offsetY, $5a5a5a);
  end;
  
begin
  if r = nil then Exit;
  
  bounds := GetBounds;
  
  // Фон
  r.DrawFilledRect(bounds, $1a1a1a);
  r.DrawRect(bounds, $5a3a18);
  
  // Строки патронов
  DrawAmmoLine('BULL', FBullets, FMaxBullets, 4);
  DrawAmmoLine('SHEL', FShells, FMaxShells, 14);
  DrawAmmoLine('RCKT', FRockets, FMaxRockets, 24);
  DrawAmmoLine('CELL', FCells, FMaxCells, 34);
end;

procedure TAmmoCounterWidget.SetAmmo(kind: TAmmoKind; current, max: Integer);
begin
  case kind of
    akBullet: begin FBullets := current; FMaxBullets := max; end;
    akShell:  begin FShells := current; FMaxShells := max; end;
    akRocket: begin FRockets := current; FMaxRockets := max; end;
    akCell:   begin FCells := current; FMaxCells := max; end;
  end;
end;

{ TDoomHUD }

constructor TDoomHUD.Create(const aID: String; font: IFont; const assets: TDoomAssets);
var
  i: Integer;
  slot: Integer;
begin
  inherited Create(aID);
  FFont := font;
  FActiveWeapon := 2;
  FHudBgImg := assets.HudBg;
  
  // AMMO label (текущие патроны)
  FAmmoLabel := TLabel.Create('lbl_ammo');
  FAmmoLabel.Text := '50';
  FAmmoLabel.Color := $D44000;
  FAmmoLabel.Font := font;
  FAmmoLabel.Align := alCenter;
  FAmmoLabel.SetBounds(MakeRect(8, 544, 56, 28));
  AddChild(FAmmoLabel);
  
  // AMMO text
  FAmmoText := TLabel.Create('lbl_ammo_text');
  FAmmoText.Text := 'AMMO';
  FAmmoText.Color := $8B4513;
  FAmmoText.Font := font;
  FAmmoText.Align := alCenter;
  FAmmoText.SetBounds(MakeRect(8, 574, 56, 16));
  AddChild(FAmmoText);
  
  // HEALTH label
  FHealthLabel := TLabel.Create('lbl_health');
  FHealthLabel.Text := '100%';
  FHealthLabel.Color := $D44000;
  FHealthLabel.Font := font;
  FHealthLabel.Align := alCenter;
  FHealthLabel.SetBounds(MakeRect(72, 544, 90, 28));
  AddChild(FHealthLabel);
  
  // HEALTH text
  FHealthText := TLabel.Create('lbl_health_text');
  FHealthText.Text := 'HEALTH';
  FHealthText.Color := $8B4513;
  FHealthText.Font := font;
  FHealthText.Align := alCenter;
  FHealthText.SetBounds(MakeRect(72, 574, 90, 16));
  AddChild(FHealthText);
  
  // ARMS panel
  FArmsPanel := TBaseWidget.Create('arms_panel');
  FArmsPanel.SetBounds(MakeRect(170, 544, 100, 54));
  AddChild(FArmsPanel);
  
  // Weapon slots 2-7
  slot := 2;
  for i := 0 to 5 do
  begin
    FWeaponSlots[slot] := TLabel.Create('arm' + IntToStr(slot));
    FWeaponSlots[slot].Text := IntToStr(slot);
    FWeaponSlots[slot].Color := $5a5a5a;
    FWeaponSlots[slot].Font := font;
    FWeaponSlots[slot].Align := alCenter;
    
    if i < 3 then
      FWeaponSlots[slot].SetBounds(MakeRect(170 + (i mod 3) * 32, 544, 30, 26))
    else
      FWeaponSlots[slot].SetBounds(MakeRect(170 + (i mod 3) * 32, 572, 30, 26));
    
    FArmsPanel.AddChild(FWeaponSlots[slot]);
    Inc(slot);
  end;
  
  // Face widget
  FFaceWidget := TDoomFaceWidget.Create('face');
  FFaceWidget.SetBounds(MakeRect(278, 540, 60, 60));
  FFaceWidget.SetFaceImages(assets.FaceFine, assets.FaceHurt, assets.FaceBad,
                            assets.FaceDead, assets.FaceOuch);
  AddChild(FFaceWidget);
  
  // ARMOR label
  FArmorLabel := TLabel.Create('lbl_armor');
  FArmorLabel.Text := '50%';
  FArmorLabel.Color := $D44000;
  FArmorLabel.Font := font;
  FArmorLabel.Align := alCenter;
  FArmorLabel.SetBounds(MakeRect(346, 544, 90, 28));
  AddChild(FArmorLabel);
  
  // ARMOR text
  FArmorText := TLabel.Create('lbl_armor_text');
  FArmorText.Text := 'ARMOR';
  FArmorText.Color := $8B4513;
  FArmorText.Font := font;
  FArmorText.Align := alCenter;
  FArmorText.SetBounds(MakeRect(346, 574, 90, 16));
  AddChild(FArmorText);
  
  // Ammo counter
  FAmmoCounter := TAmmoCounterWidget.Create('ammo_counter', font);
  FAmmoCounter.SetBounds(MakeRect(580, 540, 220, 60));
  AddChild(FAmmoCounter);
end;

procedure TDoomHUD.Render(r: IRenderer);
var
  bounds: TRect;
  srcRect: TRect;
begin
  if r = nil then Exit;
  WriteLn('HUD.Render begin');

  bounds := GetBounds;

  if (FHudBgImg <> nil) and (FHudBgImg.GetHandle <> nil) then
  begin
    WriteLn('HUD.DrawImage');
    srcRect.x := 0; srcRect.y := 0;
    srcRect.w := FHudBgImg.GetWidth; srcRect.h := FHudBgImg.GetHeight;
    r.DrawImage(FHudBgImg, srcRect, bounds);
    WriteLn('HUD.DrawImage done');
  end
  else
  begin
    r.DrawFilledRect(bounds, $1a0a00);
    r.DrawRect(MakeRect(bounds.x, bounds.y, bounds.w, 2), $8B2500);
    r.DrawFilledRect(MakeRect(66, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
    r.DrawFilledRect(MakeRect(164, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
    r.DrawFilledRect(MakeRect(274, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
    r.DrawFilledRect(MakeRect(340, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
    r.DrawFilledRect(MakeRect(440, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
    r.DrawFilledRect(MakeRect(576, bounds.y + 4, 1, bounds.h - 8), $5a3a18);
  end;

  WriteLn('HUD.inherited Render');
  inherited Render(r);
  WriteLn('HUD.Render done');
end;

procedure TDoomHUD.UpdateWeaponHighlight;
var
  i: Integer;
begin
  for i := 2 to 7 do
  begin
    if i = FActiveWeapon then
      FWeaponSlots[i].Color := $D44000
    else
      FWeaponSlots[i].Color := $5a5a5a;
  end;
end;

procedure TDoomHUD.SetHealth(pct: Integer);
begin
  FHealthLabel.Text := IntToStr(pct) + '%';
  FFaceWidget.SetHealth(pct);
end;

procedure TDoomHUD.SetArmor(pct: Integer);
begin
  FArmorLabel.Text := IntToStr(pct) + '%';
end;

procedure TDoomHUD.SetAmmo(bullets: Integer);
begin
  FAmmoLabel.Text := IntToStr(bullets);
  FAmmoCounter.SetAmmo(akBullet, bullets, 200);
end;

procedure TDoomHUD.SetWeapon(slot: Integer);
begin
  if (slot >= 2) and (slot <= 7) then
  begin
    FActiveWeapon := slot;
    UpdateWeaponHighlight;
  end;
end;

procedure TDoomHUD.TakeDamage;
begin
  FFaceWidget.GetHit;
end;

procedure TDoomHUD.SetScore(score: Integer);
begin
  // Можно добавить отображение счёта
end;

end.
