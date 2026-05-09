unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Contnrs,
  Core.Contracts;

type
  TFPHashMap = TFPHashList;

  TResourceManager = class
  private
    FImageCache: TFPHashMap;
    FFontCache: TFPHashMap;
    FImageLoader: IImageLoader;
    FFontLoader: IFontLoader;

    FMissingImage: IImage;
    FMissingFont: IFont;

    function FontKey(const path: String; size: Integer): String;
    procedure ClearMap(cache: TFPHashMap);
    function EnsureMissingImage: IImage;
    function EnsureMissingFont: IFont;
  public
    constructor Create(il: IImageLoader; fl: IFontLoader);
    destructor Destroy; override;

    function GetImage(const path: String): IImage;
    function GetFont(const path: String; size: Integer): IFont;
    procedure PreloadImage(const path: String);
    procedure ClearCache;
  end;

  TNullImage = class(IImage)
  public
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    function GetHandle: Pointer; override;
  end;

  TFrozenMissingImage = class(IImage)
  public
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    function GetHandle: Pointer; override;
  end;

  TNullFont = class(IFont)
  public
    function GetHandle: Pointer; override;
    function MeasureText(s: String): TPoint; override;
  end;

  TFrozenMissingFont = class(IFont)
  public
    function GetHandle: Pointer; override;
    function MeasureText(s: String): TPoint; override;
  end;

  TNullImageLoader = class(IImageLoader)
  private
    FLoadCount: Integer;
  public
    function Load(path: String): IImage; override;
    property LoadCount: Integer read FLoadCount;
  end;

  TNullFontLoader = class(IFontLoader)
  private
    FLoadCount: Integer;
  public
    function Load(path: String; size: Integer): IFont; override;
    property LoadCount: Integer read FLoadCount;
  end;

implementation

uses Logger;

constructor TResourceManager.Create(il: IImageLoader; fl: IFontLoader);
begin
  inherited Create;
  FImageCache := TFPHashMap.Create;
  FFontCache := TFPHashMap.Create;
  FImageLoader := il;
  FFontLoader := fl;

  FMissingImage := nil;
  FMissingFont := nil;
end;

destructor TResourceManager.Destroy;
begin
  ClearCache;
  FImageCache.Free;
  FFontCache.Free;
  inherited Destroy;
end;

function TResourceManager.FontKey(const path: String; size: Integer): String;
begin
  Result := path + '_' + IntToStr(size);
end;

procedure TResourceManager.ClearMap(cache: TFPHashMap);
var
  i: Integer;
begin
  for i := cache.Count - 1 downto 0 do
  begin
    TObject(cache.Items[i]).Free;
    cache.Delete(i);
  end;
end;

function TResourceManager.EnsureMissingImage: IImage;
begin
  if FMissingImage = nil then
    FMissingImage := TFrozenMissingImage.Create;
  Result := FMissingImage;
end;

function TResourceManager.EnsureMissingFont: IFont;
begin
  if FMissingFont = nil then
    FMissingFont := TFrozenMissingFont.Create;
  Result := FMissingFont;
end;

function TResourceManager.GetImage(const path: String): IImage;
var
  loaderResult: IImage;
begin
  Result := IImage(FImageCache.Find(path));
  if Result <> nil then
    Exit;

  if FImageLoader = nil then
    Exit(EnsureMissingImage);

  try
    loaderResult := FImageLoader.Load(path);
    if loaderResult <> nil then
    begin
      FImageCache.Add(path, loaderResult);
      Exit(loaderResult);
    end;
  except
    on E: Exception do
    begin
      Logger.TLogger.Instance.Log(llWarn, 'Image load failed: ' + path + ' (' + E.Message + ')');
    end;
  end;

  Result := EnsureMissingImage;
end;

function TResourceManager.GetFont(const path: String; size: Integer): IFont;
var
  key: String;
  loaderResult: IFont;
begin
  key := FontKey(path, size);

  Result := IFont(FFontCache.Find(key));
  if Result <> nil then
    Exit;

  if FFontLoader = nil then
    Exit(EnsureMissingFont);

  try
    loaderResult := FFontLoader.Load(path, size);
    if loaderResult <> nil then
    begin
      FFontCache.Add(key, loaderResult);
      Exit(loaderResult);
    end;
  except
    on E: Exception do
    begin
      Logger.TLogger.Instance.Log(llWarn, 'Font load failed: ' + path + ' (' + E.Message + ')');
    end;
  end;

  Result := EnsureMissingFont;
end;

procedure TResourceManager.PreloadImage(const path: String);
begin
  GetImage(path);
end;

procedure TResourceManager.ClearCache;
begin
  ClearMap(FImageCache);
  ClearMap(FFontCache);
end;

function TNullImage.GetWidth: Integer;
begin
  Result := 0;
end;

function TNullImage.GetHeight: Integer;
begin
  Result := 0;
end;

function TNullImage.GetHandle: Pointer;
begin
  Result := nil;
end;

function TFrozenMissingImage.GetWidth: Integer;
begin
  Result := 1;
end;

function TFrozenMissingImage.GetHeight: Integer;
begin
  Result := 1;
end;

function TFrozenMissingImage.GetHandle: Pointer;
begin
  // SDLRenderer draws fallback when handle is nil
  Result := nil;
end;

function TNullFont.GetHandle: Pointer;
begin
  Result := nil;
end;

function TNullFont.MeasureText(s: String): TPoint;
begin
  Result.x := 0;
  Result.y := 0;
end;

function TFrozenMissingFont.GetHandle: Pointer;
begin
  Result := nil;
end;

function TFrozenMissingFont.MeasureText(s: String): TPoint;
begin
  // simple deterministic placeholder size
  Result.x := Length(s) * 6;
  Result.y := 8;
end;

function TNullImageLoader.Load(path: String): IImage;
begin
  Inc(FLoadCount);
  Result := TNullImage.Create;
end;

function TNullFontLoader.Load(path: String; size: Integer): IFont;
begin
  Inc(FLoadCount);
  Result := TNullFont.Create;
end;

end.
