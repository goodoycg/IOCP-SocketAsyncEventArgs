unit ThroughputSocket;

interface

uses
  IdTCPClient, BasisFunction, Windows, SysUtils, Classes, SyncObjs, DefineUnit,
  Types, BaseClientSocket, IdIOHandlerSocket, Messages;

type
  TThroughputScoket = class(TBaseClientSocket)
  private
    {* 数据缓冲区 *}
    FBuffer: array of Byte;
    {* 数据缓冲区大小 *}
    FBufferSize: Integer;
    {* 循环发包次数 *}
    FCount: Integer;
  public
    constructor Create; override;
    destructor Destroy; override;
    {* 连接服务器 *}
    function Connect(const ASvr: string; APort: Integer): Boolean;
    {* 断开连接 *}
    procedure Disconnect;
    {* 循环发包检测 *}
    function CyclePacket: Boolean;

    property BufferSize: Integer read FBufferSize write FBufferSize;
    property Count: Integer read FCount;
  end;

implementation

{ TThroughputScoket }

constructor TThroughputScoket.Create;
begin
  inherited;
  FBufferSize := 1024;
end;

destructor TThroughputScoket.Destroy;
begin
  inherited;
end;

function TThroughputScoket.Connect(const ASvr: string;
  APort: Integer): Boolean;
begin
  FHost := ASvr;
  FPort := APort;
  Result := inherited Connect(Char(sfThroughput));
end;

procedure TThroughputScoket.Disconnect;
begin
  inherited Disconnect;
end;

function TThroughputScoket.CyclePacket: Boolean;
var
  i: Integer;
  slRequest, slResponse: TStringList;
begin
  if FBufferSize > Length(FBuffer) then
  begin
    SetLength(FBuffer, FBufferSize);
    for i := Low(FBuffer) to High(FBuffer) do
    begin
      FBuffer[i] := 1;
    end;
  end;
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    FCount := FCount + 1;
    slRequest.Add(Format(CSFmtInt, [CSCount, FCount]));
    Result := ControlCommand(CSThroughputCommand[tcCyclePacket], slRequest, slResponse, FBuffer);
    if Result then
      FCount := StrToInt(slResponse.Values[CSCount]);
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

end.
