unit RemoteStreamSocket;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, ADODB, DB, BaseClientSocket,
  BasisFunction, DefineUnit, IdException;

type
  TRemoteStreamSocket = class(TBaseClientSocket)
  protected
    {* 返回错误描述 *}
    function GetErrorCodeString(const AErrorCode: Cardinal): string; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    {* 连接服务器 *}
    function Connect: Boolean; overload;
    function DoCmdFileExists(const AFileName: string): Boolean;
    function DoCmdOpenFile(const AFileName: string; const AMode: TRemoteStreamMode): Boolean;
    function DoCmdSetSzie(const AFileSize: Int64): Boolean;
    function DoCmdGetSize(var AFileSize: Int64): Boolean;
    function DoCmdSetPosition(const APosition: Int64): Boolean;
    function DoCmdGetPosition(var APosition: Int64): Boolean;
    function DoCmdRead(var ABuffer; var ACount: Integer): Boolean;
    function DoCmdWrite(const ABuffer; var ACount: Integer): Boolean;
    function DoCmdSeek(var AOffset: Int64; const ASeekOrigin: TSeekOrigin): Boolean;
    function DoCmdCloseFile: Boolean;
  end;

implementation

{ TRemoteStreamSocket }

constructor TRemoteStreamSocket.Create;
begin
  inherited;
  FTimeOutMS := CI_ReadTimeout;
end;

destructor TRemoteStreamSocket.Destroy;
begin
  inherited;
end;

function TRemoteStreamSocket.Connect: Boolean;
begin
  Result := inherited Connect(Char(sfRemoteStream));
end;

function TRemoteStreamSocket.DoCmdFileExists(const AFileName: string): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSFileName, AFileName]));
    Result := ControlCommand(CSRemoteStreamCommand[rscFileExists], slRequest, slResponse, '');
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdOpenFile(const AFileName: string;
  const AMode: TRemoteStreamMode): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSFileName, AFileName]));
    slRequest.Add(Format(CSFmtString, [CSMode, IntToStr(Ord(AMode))]));
    Result := ControlCommand(CSRemoteStreamCommand[rscOpenFile], slRequest, slResponse, '');
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdSetSzie(const AFileSize: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSSize, IntToStr(AFileSize)]));
    Result := ControlCommand(CSRemoteStreamCommand[rscSetSize], slRequest, slResponse, '');
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdGetSize(var AFileSize: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    Result := ControlCommand(CSRemoteStreamCommand[rscGetSize], slRequest, slResponse, '');
    AFileSize := StrToInt64(slResponse.Values[CSSize]);
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdSetPosition(
  const APosition: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtInt, [CSPosition, APosition]));
    Result := ControlCommand(CSRemoteStreamCommand[rscSetPosition], slRequest, slResponse, '');
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdGetPosition(
  var APosition: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    Result := ControlCommand(CSRemoteStreamCommand[rscGetPosition], slRequest, slResponse, '');
    APosition := StrToInt64(slResponse.Values[CSPosition]);
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdRead(var ABuffer;
  var ACount: Integer): Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtInt, [CSCount, ACount]));
    Result := ControlCommand(CSRemoteStreamCommand[rscRead], slRequest, ACount);
    if Result then
      CopyMemory(@ABuffer, @RecvBuf[0], ACount);
  finally
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdWrite(const ABuffer;
  var ACount: Integer): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtInt, [CSCount, ACount]));
    Result := ControlCommand(CSRemoteStreamCommand[rscWrite], slRequest, slResponse, ABuffer, ACount);
    ACount := StrToInt(slResponse.Values[CSCount]);
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdSeek(var AOffset: Int64;
  const ASeekOrigin: TSeekOrigin): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtInt, [CSOffset, AOffset]));
    slRequest.Add(Format(CSFmtInt, [CSSeekOrigin, Ord(ASeekOrigin)]));
    Result := ControlCommand(CSRemoteStreamCommand[rscSeek], slRequest, slResponse, '');
    AOffset := StrToInt64(slResponse.Values[CSOffset]);
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TRemoteStreamSocket.DoCmdCloseFile: Boolean;
begin
  Result := ControlCommand(CSRemoteStreamCommand[rscCloseFile], nil, nil, '');
end;

function TRemoteStreamSocket.GetErrorCodeString(
  const AErrorCode: Cardinal): string;
begin
  case AErrorCode of
    CIDirNotExist: Result := 'Directory Not Exist';
    CICreateDirError: Result := 'Create Directory Failed';
    CIDeleteDirError: Result := 'Delete Directory Failed';
    CIFileNotExist: Result := 'File Not Exist';
    CIFileInUseing: Result := 'File In Useing';
    CINotOpenFile: Result := 'Not Open File';
    CIDeleteFileFailed: Result := 'Delete File Failed';
    CIFileSizeError: Result := 'File Size Error';
  else
    Result := inherited GetErrorCodeString(AErrorCode);
  end;
end;

end.
