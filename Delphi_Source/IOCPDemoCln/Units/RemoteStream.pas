unit RemoteStream;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, ADODB, DB, RemoteStreamSocket,
  DefineUnit;

type
  TRemoteStream = class(TStream)
  protected
    FRemoteStreamSocket: TRemoteStreamSocket;
    procedure SetSize(const NewSize: Int64); override;
    function GetSize: Int64; override;
    procedure SetPosition(const APosition: Int64); virtual;
    function GetPosition: Int64; virtual;
  public
    constructor Create; virtual; 
    destructor Destroy; override;
    function Connect(const AServer: string; const APort: Integer): Boolean;
    function FileExists(const AFileName: string): Boolean;
    function OpenFile(const AFileName: string; AMode: TRemoteStreamMode): Boolean;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function CloseFile: Boolean;
    property Position: Int64 read GetPosition write SetPosition;
    property Size: Int64 read GetSize write SetSize;
    property RemoteStreamSocket: TRemoteStreamSocket read FRemoteStreamSocket;
  end;

implementation

{ TRemoteStream }

constructor TRemoteStream.Create;
begin
  FRemoteStreamSocket := TRemoteStreamSocket.Create;
end;

destructor TRemoteStream.Destroy;
begin
  FRemoteStreamSocket.Free;
  inherited;
end;

function TRemoteStream.Connect(const AServer: string;
  const APort: Integer): Boolean;
begin
  FRemoteStreamSocket.Host := AServer;
  FRemoteStreamSocket.Port := APort;
  Result := FRemoteStreamSocket.Connect;
end;

function TRemoteStream.FileExists(const AFileName: string): Boolean;
begin
  Result := FRemoteStreamSocket.DoCmdFileExists(AFileName);
end;

function TRemoteStream.OpenFile(const AFileName: string;
  AMode: TRemoteStreamMode): Boolean;
begin
  Result := FRemoteStreamSocket.DoCmdOpenFile(AFileName, AMode);
end;

function TRemoteStream.Read(var Buffer; Count: Integer): Longint;
begin
  inherited;
  if not FRemoteStreamSocket.DoCmdRead(Buffer, Count) then
    Result := 0
  else
    Result := Count;
end;

function TRemoteStream.Write(const Buffer; Count: Integer): Longint;
begin
  if not FRemoteStreamSocket.DoCmdWrite(Buffer, Count) then
    Result := 0
  else
    Result := Count;
end;

function TRemoteStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
var
  iOffset: Int64;
begin
  iOffset := Offset;
  if not FRemoteStreamSocket.DoCmdSeek(iOffset, Origin) then
    Result := 0
  else
    Result := iOffset;
end;

procedure TRemoteStream.SetSize(const NewSize: Int64);
begin
  inherited;
  if not FRemoteStreamSocket.DoCmdSetSzie(NewSize) then
    raise Exception.Create(FRemoteStreamSocket.LastError);
end;

function TRemoteStream.GetSize: Int64;
begin
  if not FRemoteStreamSocket.DoCmdGetSize(Result) then
    raise Exception.Create(FRemoteStreamSocket.LastError);
end;

procedure TRemoteStream.SetPosition(const APosition: Int64);
begin
  if not FRemoteStreamSocket.DoCmdSetPosition(APosition) then
    raise Exception.Create(FRemoteStreamSocket.LastError);
end;

function TRemoteStream.GetPosition: Int64;
begin
  if not FRemoteStreamSocket.DoCmdGetPosition(Result) then
    raise Exception.Create(FRemoteStreamSocket.LastError);
end;

function TRemoteStream.CloseFile: Boolean;
begin
  Result := FRemoteStreamSocket.DoCmdCloseFile;
end;

end.
