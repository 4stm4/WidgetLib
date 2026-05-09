unit JSONWidgetLoader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser,
  Core.Contracts, WidgetSystem, BaseWidget, ResourceManager, SkinSystem,
  BasicWidgets;

type
  TJSONWidgetLoader = class(IWidgetLoader)
  private
    FWidgetSystem: TWidgetSystem;
    FResourceManager: TResourceManager;

    function ParseWidget(obj: TJSONObject): IWidget;
    function CreateWidgetByType(const typeName: String): IWidget;
    function TryGetInt(obj: TJSONObject; const name: String; defaultValue: Integer): Integer;
    function TryGetString(obj: TJSONObject; const name: String; defaultValue: String): String;
    function TryGetLongWordFromStringOrInt(
      obj: TJSONObject; const name: String; defaultValue: LongWord): LongWord;

  public
    constructor Create(ws: TWidgetSystem; rm: TResourceManager);
    function LoadFromJSON(const json: String): IWidget;
  end;

implementation

constructor TJSONWidgetLoader.Create(ws: TWidgetSystem; rm: TResourceManager);
begin
  inherited Create;
  FWidgetSystem := ws;
  FResourceManager := rm;
end;

function TJSONWidgetLoader.TryGetInt(obj: TJSONObject; const name: String; defaultValue: Integer): Integer;
var
  v: TJSONData;
begin
  Result := defaultValue;
  if obj = nil then Exit;
  v := obj.Find(name);
  if (v <> nil) and (v.JSONType = jtNumber) then
    Result := v.AsInteger;
end;

function TJSONWidgetLoader.TryGetString(obj: TJSONObject; const name: String; defaultValue: String): String;
var
  v: TJSONData;
begin
  Result := defaultValue;
  if obj = nil then Exit;
  v := obj.Find(name);
  if (v <> nil) and ((v.JSONType = jtString) or (v.JSONType = jtNumber)) then
    Result := v.AsString;
end;

function TJSONWidgetLoader.TryGetLongWordFromStringOrInt(
  obj: TJSONObject; const name: String; defaultValue: LongWord): LongWord;
var
  v: TJSONData;
  s: String;
  parsed: QWord;
  hasHexLetters: Boolean;
begin
  Result := defaultValue;
  if obj = nil then Exit;

  v := obj.Find(name);
  if v = nil then Exit;

  if v.JSONType = jtNumber then
  begin
    if v.AsInteger < 0 then Exit;
    Result := LongWord(v.AsInteger);
    Exit;
  end;

  if not (v.JSONType in [jtString]) then Exit;

  s := Trim(v.AsString);
  if s = '' then Exit;

  // Support: 0xRRGGBB, $AARRGGBB, plain decimal, or plain hex without prefix
  if (Length(s) > 2) and ((Copy(s, 1, 2) = '0x') or (Copy(s, 1, 2) = '0X')) then
    s := Copy(s, 3, MaxInt);

  if (Length(s) > 0) and (s[1] = '$') then
    s := Copy(s, 2, MaxInt);

  // If it looks like hex, parse as hex; otherwise decimal
  try
    hasHexLetters := False;

    // detect hex letters without relying on PosAny()
    for parsed := 1 to Length(s) do
    begin
      if s[parsed] in ['a'..'f', 'A'..'F'] then
      begin
        hasHexLetters := True;
        Break;
      end;
    end;

    if hasHexLetters then
      parsed := StrToQWord('$' + s)
    else if (s <> '') and (s[1] in ['0'..'9']) then
      parsed := StrToQWord(s)
    else
      Exit;

    Result := LongWord(parsed);
  except
    // keep default
  end;
end;

function TJSONWidgetLoader.LoadFromJSON(const json: String): IWidget;
var
  data: TJSONData;
  obj: TJSONObject;
begin
  data := GetJSON(json);
  try
    if not (data is TJSONObject) then
      raise Exception.Create('Root JSON must be object');
    obj := TJSONObject(data);
    Result := ParseWidget(obj);
  finally
    data.Free;
  end;
end;

function TJSONWidgetLoader.CreateWidgetByType(const typeName: String): IWidget;
begin
  if SameText(typeName, 'Panel') then
    Result := TBaseWidget.Create('')
  else if SameText(typeName, 'Label') then
    Result := TLabel.Create('')
  else if SameText(typeName, 'Image') then
    Result := TImage.Create('')
  else if SameText(typeName, 'Button') then
    Result := TButton.Create('')
  else
    raise Exception.Create('Unknown widget type: ' + typeName);
end;

function TJSONWidgetLoader.ParseWidget(obj: TJSONObject): IWidget;
var
  idV, typeV, skinV: String;
  boundsObj, childrenArrV, skinNode, typeNode: TJSONData;
  bounds: TRect;
  i: Integer;
  child: IWidget;

  labelObj: TLabel;
  buttonObj: TButton;
  fontPath: String;
  fontSize: Integer;
begin
  if obj = nil then Exit(nil);

  typeNode := obj.Find('type');
  if (typeNode = nil) then
    raise Exception.Create('Widget type not specified');

  typeV := typeNode.AsString;
  Result := CreateWidgetByType(typeV);

  // id
  idV := '';
  if obj.Find('id') <> nil then
    idV := obj.Find('id').AsString;
  if (Result is TBaseWidget) then
    TBaseWidget(Result).SetID(idV);

  // bounds
  bounds.x := 0; bounds.y := 0; bounds.w := 0; bounds.h := 0;
  boundsObj := obj.Find('bounds');
  if (boundsObj <> nil) and (boundsObj is TJSONObject) then
  begin
    bounds.x := TryGetInt(TJSONObject(boundsObj), 'x', 0);
    bounds.y := TryGetInt(TJSONObject(boundsObj), 'y', 0);
    bounds.w := TryGetInt(TJSONObject(boundsObj), 'w', 0);
    bounds.h := TryGetInt(TJSONObject(boundsObj), 'h', 0);
    Result.SetBounds(bounds);
  end;

  // skin (if GlobalSkinManager has it)
  skinNode := obj.Find('skin');
  if skinNode <> nil then
  begin
    skinV := skinNode.AsString;
    if (Result is TBaseWidget) and (GlobalSkinManager <> nil) then
      TBaseWidget(Result).Skin := GlobalSkinManager.GetSkin(skinV);
  end;

  // type-specific fields
  if Result is TLabel then
  begin
    labelObj := TLabel(Result);
    labelObj.Text := TryGetString(obj, 'text', labelObj.Text);
    // align: allow "left/center/right" or "alLeft/alCenter/alRight"
    if obj.Find('align') <> nil then
    begin
      case LowerCase(Trim(obj.Find('align').AsString)) of
        'left', 'aleft': labelObj.Align := alLeft;
        'center', 'alcenter': labelObj.Align := alCenter;
        'right', 'aright', 'alright': labelObj.Align := alRight;
      end;
    end;
    labelObj.Color := TryGetLongWordFromStringOrInt(obj, 'color', labelObj.Color);
    
    // font
    fontPath := TryGetString(obj, 'font', '');
    fontSize := TryGetInt(obj, 'fontSize', 12);
    if (fontPath <> '') and (FResourceManager <> nil) then
      labelObj.Font := FResourceManager.GetFont(fontPath, fontSize);
  end
  else if Result is TButton then
  begin
    buttonObj := TButton(Result);
    buttonObj.Caption := TryGetString(obj, 'caption', buttonObj.Caption);
    buttonObj.Command := TryGetString(obj, 'command', buttonObj.Command);
    buttonObj.Color := TryGetLongWordFromStringOrInt(obj, 'color', buttonObj.Color);
    
    // font
    fontPath := TryGetString(obj, 'font', '');
    fontSize := TryGetInt(obj, 'fontSize', 12);
    if (fontPath <> '') and (FResourceManager <> nil) then
      buttonObj.Font := FResourceManager.GetFont(fontPath, fontSize);
  end;

  // children
  childrenArrV := obj.Find('children');
  if (childrenArrV <> nil) and (childrenArrV is TJSONArray) then
  begin
    for i := 0 to TJSONArray(childrenArrV).Count - 1 do
    begin
      if not (TJSONArray(childrenArrV).Items[i] is TJSONObject) then Continue;
      child := ParseWidget(TJSONObject(TJSONArray(childrenArrV).Items[i]));
      Result.AddChild(child);
    end;
  end;
end;

end.
