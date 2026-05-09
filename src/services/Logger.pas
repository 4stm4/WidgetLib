unit Logger;

{$mode objfpc}{$H+}

interface

type
  TLogLevel = (llDebug, llInfo, llWarn, llError);

  IOutputWriter = interface
    ['{E3E9B4B7-2F31-4E2A-9F5D-0F0A3A2C4F11}']
    procedure WriteLn(const s: String);
  end;

  TStringOutputWriter = class(TInterfacedObject, IOutputWriter)
  public
    Last: String;
    procedure WriteLn(const s: String);
  end;

  TLogger = class
  private
    class var FInstance: TLogger;

    FMinLevel: TLogLevel;
    FOutputFile: String;
    FLastLine: String;

    function GetMinLevel: TLogLevel;
    procedure SetMinLevel(value: TLogLevel);

    function GetOutputFile: String;
    procedure SetOutputFile(const value: String);

    function GetLastLine: String;

    function LevelToRank(level: TLogLevel): Integer;
    procedure WriteLine(const line: String);
    function LevelToString(level: TLogLevel): String;
  public
    constructor Create;

    class function Instance: TLogger;

    procedure Log(level: TLogLevel; const msg: String);
    procedure LogFmt(level: TLogLevel; const fmt: String; args: array of const);

    procedure ClearLastLine;

    property MinLevel: TLogLevel read GetMinLevel write SetMinLevel;
    property OutputFile: String read GetOutputFile write SetOutputFile;
    property LastLine: String read GetLastLine;
  end;

implementation

uses
  SysUtils;

procedure TStringOutputWriter.WriteLn(const s: String);
begin
  Last := s;
end;

function TLogger.GetMinLevel: TLogLevel;
begin
  Result := FMinLevel;
end;

procedure TLogger.SetMinLevel(value: TLogLevel);
begin
  FMinLevel := value;
end;

function TLogger.GetOutputFile: String;
begin
  Result := FOutputFile;
end;

procedure TLogger.SetOutputFile(const value: String);
begin
  FOutputFile := value;
end;

function TLogger.GetLastLine: String;
begin
  Result := FLastLine;
end;

procedure TLogger.ClearLastLine;
begin
  FLastLine := '';
end;

constructor TLogger.Create;
begin
  inherited Create;
  FMinLevel := llDebug;
  FOutputFile := '';
  FLastLine := '';
end;

function TLogger.LevelToRank(level: TLogLevel): Integer;
begin
  case level of
    llDebug: Result := 0;
    llInfo: Result := 1;
    llWarn: Result := 2;
    llError: Result := 3;
  else
    Result := 0;
  end;
end;

function TLogger.LevelToString(level: TLogLevel): String;
begin
  case level of
    llDebug: Result := 'DEBUG';
    llInfo: Result := 'INFO';
    llWarn: Result := 'WARN';
    llError: Result := 'ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

procedure TLogger.WriteLine(const line: String);
var
  f: TextFile;
begin
  FLastLine := line;

  if FOutputFile <> '' then
  begin
    AssignFile(f, FOutputFile);
    if FileExists(FOutputFile) then
      Append(f)
    else
      Rewrite(f);

    try
      WriteLn(f, line);
    finally
      CloseFile(f);
    end;
  end
  else
  begin
    // stderr
    WriteLn(line);
  end;
end;

procedure TLogger.Log(level: TLogLevel; const msg: String);
begin
  if LevelToRank(level) < LevelToRank(FMinLevel) then
    Exit;

  WriteLine(Format('[%s] %s', [LevelToString(level), msg]));
end;

procedure TLogger.LogFmt(level: TLogLevel; const fmt: String; args: array of const);
begin
  if LevelToRank(level) < LevelToRank(FMinLevel) then
    Exit;

  Log(level, Format(fmt, args));
end;

class function TLogger.Instance: TLogger;
begin
  if FInstance = nil then
    FInstance := TLogger.Create;
  Result := FInstance;
end;

initialization
  // ensure singleton created lazily, but keep deterministic minlevel
finalization
  if TLogger.FInstance <> nil then
    TLogger.FInstance.Free;
  TLogger.FInstance := nil;

end.
