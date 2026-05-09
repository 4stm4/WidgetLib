unit BasicWidgets;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Core.Contracts,
  BaseWidget;

type
  TAlignment = (alLeft, alCenter, alRight);

  TCommandCallback = procedure(const e: TWidgetEvent) of object;

  TLabel = class(TBaseWidget)
  private
    FText: String;
    FFont: IFont;
    FColor: LongWord;
    FAlign: TAlignment;
  public
    constructor Create(const aID: String);

    procedure Render(r: IRenderer); override;

    property Text: String read FText write FText;
    property Font: IFont read FFont write FFont;
    property Color: LongWord read FColor write FColor;
    property Align: TAlignment read FAlign write FAlign;
  end;

  TImage = class(TBaseWidget)
  private
    FImage: IImage;
    FStretch: Boolean;
  public
    constructor Create(const aID: String);

    procedure Render(r: IRenderer); override;

    property Image: IImage read FImage write FImage;
    property Stretch: Boolean read FStretch write FStretch;
  end;

  TButton = class(TBaseWidget)
  private
    FLabel: String;
    FCommand: String;
    FFont: IFont;
    FOnCommand: TCommandCallback;
    FColor: LongWord;
  public
    constructor Create(const aID: String);

    procedure Render(r: IRenderer); override;
    function HandleEvent(e: TWidgetEvent): Boolean; override;

    property Caption: String read FLabel write FLabel;
    property Command: String read FCommand write FCommand;
    property Font: IFont read FFont write FFont;

    // Test hook: receives evCommand
    property OnCommand: TCommandCallback read FOnCommand write FOnCommand;

    // optional default color if no skin
    property Color: LongWord read FColor write FColor;
  end;

implementation

{ TLabel }

constructor TLabel.Create(const aID: String);
begin
  inherited Create(aID);
  FText := '';
  FFont := nil;
  FColor := $FFFFFFFF;
  FAlign := alLeft;
end;

procedure TLabel.Render(r: IRenderer);
var
  bounds: TRect;
  textSize: TPoint;
  x: Integer;
  y: Integer;
  textColor: LongWord;
begin
  if r = nil then
    Exit;

  // BaseWidget manages dirty/FSkin; for label we don't use FSkin directly.
  bounds := GetBounds;

  if FFont <> nil then
    textSize := FFont.MeasureText(FText)
  else
  begin
    textSize.x := 0;
    textSize.y := 0;
  end;

  case FAlign of
    alLeft: x := bounds.x;
    alCenter: x := bounds.x + (bounds.w - textSize.x) div 2;
    alRight: x := bounds.x + (bounds.w - textSize.x);
  end;

  y := bounds.y + (bounds.h - textSize.y) div 2;

  textColor := FColor;

  r.DrawText(FFont, FText, x, y, textColor);
  inherited Render(r); // keeps existing FSkin drawing behavior if any
end;

{ TImage }

constructor TImage.Create(const aID: String);
begin
  inherited Create(aID);
  FImage := nil;
  FStretch := False;
end;

procedure TImage.Render(r: IRenderer);
var
  bounds: TRect;
  srcRect, dstRect: TRect;
begin
  if r = nil then
    Exit;

  bounds := GetBounds;

  if FImage = nil then
  begin
    inherited Render(r);
    Exit;
  end;

  srcRect.x := 0;
  srcRect.y := 0;
  srcRect.w := FImage.GetWidth;
  srcRect.h := FImage.GetHeight;

  if FStretch then
    dstRect := bounds
  else
  begin
    dstRect.x := bounds.x;
    dstRect.y := bounds.y;
    dstRect.w := srcRect.w;
    dstRect.h := srcRect.h;
  end;

  r.DrawImage(FImage, srcRect, dstRect);
  inherited Render(r);
end;

{ TButton }

constructor TButton.Create(const aID: String);
begin
  inherited Create(aID);
  FLabel := '';
  FCommand := '';
  FFont := nil;
  FOnCommand := nil;
  FColor := $FFFFFFFF;
end;

procedure TButton.Render(r: IRenderer);
var
  bounds: TRect;
  textSize: TPoint;
  x: Integer;
  y: Integer;
  textColor: LongWord;
begin
  if r = nil then
    Exit;

  bounds := GetBounds;

  if Skin <> nil then
    Skin.Draw(r, bounds, State);

  if FFont <> nil then
    textSize := FFont.MeasureText(FLabel)
  else
  begin
    textSize.x := 0;
    textSize.y := 0;
  end;

  x := bounds.x + (bounds.w - textSize.x) div 2;
  y := bounds.y + (bounds.h - textSize.y) div 2;

  if Skin <> nil then
    textColor := Skin.GetTextColor(State)
  else
    textColor := FColor;

  r.DrawText(FFont, FLabel, x, y, textColor);
end;

function TButton.HandleEvent(e: TWidgetEvent): Boolean;
var
  inside: Boolean;
  newState: TWidgetState;
  ev: TWidgetEvent;
begin
  Result := False;

  if not IsVisible then
    Exit;

  if State = wsDisabled then
    Exit;

  case e.kind of
    evMouseDown:
      begin
        inside := ContainsPoint(e.x, e.y);
        if inside and (State <> wsActive) then
        begin
          State := wsActive;
          Invalidate;
          Result := True;
        end;
      end;

    evMouseUp:
      begin
        inside := ContainsPoint(e.x, e.y);

        // If we were active and mouse is released inside -> execute command
        if State = wsActive then
        begin
          if inside then
          begin
            FillChar(ev, SizeOf(ev), 0);
            ev.kind := evCommand;
            ev.x := 0;
            ev.y := 0;
            ev.button := 0;
            ev.key := 0;
            ev.wheelDelta := 0;
            ev.dragSource := nil;
            ev.commandName := FCommand;
            ev.commandData := nil;
            ev.handled := False;

            if Assigned(FOnCommand) then
              FOnCommand(ev);

            Result := True;
          end;

          State := wsNormal;
          Invalidate;
        end
        else
        begin
          // if not active, just normalize on mouse up
          newState := wsNormal;
          if newState <> State then
          begin
            State := newState;
            Invalidate;
            Result := True;
          end;
        end;
      end;

    evMouseMove:
      begin
        // Hover/move handling.
        inside := ContainsPoint(e.x, e.y);

        if State = wsActive then
        begin
          // keep active
          Result := False;
          Exit;
        end;

        if inside then
          newState := wsHover
        else
          newState := wsNormal;

        if newState <> State then
        begin
          State := newState;
          Invalidate;
          Result := True;
        end;
      end;

    evHoverEnter:
      begin
        if State <> wsActive then
        begin
          if State <> wsHover then
          begin
            State := wsHover;
            Invalidate;
            Result := True;
          end;
        end;
      end;

    evHoverLeave:
      begin
        if State <> wsActive then
        begin
          if State <> wsNormal then
          begin
            State := wsNormal;
            Invalidate;
            Result := True;
          end;
        end;
      end;
  end;
end;

end.
