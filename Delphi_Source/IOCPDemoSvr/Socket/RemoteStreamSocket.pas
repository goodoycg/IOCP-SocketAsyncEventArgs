unit RemoteStreamSocket;

interface

uses
  SysUtils, Classes, Windows, Types, IOCPSocket, DefineUnit, BasisFunction,
  BaseSocket, Logger, Math;
  
type
  TRemoteStreamSocket = class(TBaseSocket)
  private
    FFileStream: TFileStream;
    {* 读取的数据缓存 *}
    FBuffer: array of Byte;
  protected
    { *处理数据接口，每个子类在这编写命令处理，外部已有锁处理，这里不再加锁* }
    procedure Execute(AData: PByte; const ALen: Cardinal); override;
    {* 命令实现 *}
    procedure DoCmdFileExists;
    procedure DoCmdOpenFile;
    procedure DoCmdSetSize;
    procedure DoCmdGetSize;
    procedure DoCmdSetPosition;
    procedure DoCmdGetPosition;
    procedure DoCmdRead;
    procedure DoCmdWrite;
    procedure DoCmdSeek;
    procedure DoCmdCloseFile;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
  end;

function StrToRemoteStreamCommand(const AValue: string): TRemoteStreamCommand;

implementation

function StrToRemoteStreamCommand(const AValue: string): TRemoteStreamCommand;
var
  i: TRemoteStreamCommand;
begin
  Result := rscNone;
  for i := Low(TRemoteStreamCommand) to High(TRemoteStreamCommand) do
  begin
    if SameText(CSRemoteStreamCommand[i], AValue) then
    begin
      Result := i;
      Break;
    end;
  end;
end;

{ TRemoteStreamSocket }

procedure TRemoteStreamSocket.DoCreate;
begin
  inherited;
  LenType := ltCardinal;
end;

destructor TRemoteStreamSocket.Destroy;
begin
  FreeAndNilEx(FFileStream);
  inherited;
end;

procedure TRemoteStreamSocket.Execute(AData: PByte; const ALen: Cardinal);
var
  sErr: string;
begin
  inherited;
  FRequest.Clear;
  FResponse.Clear;
  try
    AddResponseHeader;
    if ALen = 0 then
    begin
      DoFailure(CIPackLenError);
      DoSendResult(True);
      Exit;
    end;
    if DecodePacket(AData, ALen) then //如果是命令包，则处理命令
    begin
      case StrToRemoteStreamCommand(Command) of
        rscFileExists:
        begin
          DoCmdFileExists;
          DoSendResult(True);
        end;
        rscOpenFile:
        begin
          DoCmdOpenFile;
          DoSendResult(True);
        end;
        rscSetSize:
        begin
          DoCmdSetSize;
          DoSendResult(True);
        end;
        rscGetSize:
        begin
          DoCmdGetSize;
          DoSendResult(True);
        end;
        rscSetPosition:
        begin
          DoCmdSetPosition;
          DoSendResult(True);
        end;
        rscGetPosition:
        begin
          DoCmdGetPosition;
          DoSendResult(True);
        end;
        rscRead: DoCmdRead;
        rscWrite:
        begin
          DoCmdWrite;
          DoSendResult(True);
        end;
        rscSeek:
        begin
          DoCmdSeek;
          DoSendResult(True);
        end;
        rscCloseFile:
        begin
          DoCmdCloseFile;
          DoSendResult(True);
        end;
      else
        DoFailure(CINoExistCommand, 'Unknow Command');
        DoSendResult(True);
      end;
    end
    else //未知数据包，写日志，断开
    begin
      DoFailure(CIPackFormatError, 'Decode Packet Error');
      DoSendResult(True);
    end;
  except
    on E: Exception do
    begin
      sErr := Format('Unknow Error, Class: %s, Message: %s', [E.ClassName, E.Message]);
      sErr := DateTimeToStr(GMTNow) + ';' + RemoteAddress + ':' + IntToStr(RemotePort) + ';' + sErr;
      WriteLogMsg(ltError, sErr);
      DoFailure(GetLastError, '');
      DoSendResult(True);
    end;
  end;
end;

procedure TRemoteStreamSocket.DoCmdFileExists;
var
  sFileName: string;
begin
  if not CheckAndGetValue(CSFileName, sFileName) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if FileExists(sFileName) then
    DoSuccess
  else
    DoFailure(CIFileNotExist, '');
end;

procedure TRemoteStreamSocket.DoCmdOpenFile;
var
  wMode: Word;
  sFileName: string;
begin
  if not (CheckAndGetValue(CSFileName, sFileName) and CheckAndGetValue(CSMode, wMode)) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if Assigned(FFileStream) then
    FreeAndNilEx(FFileStream);
  if TRemoteStreamMode(wMode) = rsmRead then
    FFileStream := TFileStream.Create(sFileName, fmOpenRead)
  else
    FFileStream := TFileStream.Create(sFileName, fmOpenReadWrite or fmShareDenyWrite);
  DoSuccess;
end;

procedure TRemoteStreamSocket.DoCmdSetSize;
var
  iFileSize: Int64;
begin
  if not (CheckAndGetValue(CSSize, iFileSize)) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  FFileStream.Size := iFileSize;
  DoSuccess;
end;

procedure TRemoteStreamSocket.DoCmdGetSize;
begin
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  DoSuccess;
  FResponse.Add(Format(CSFmtInt, [CSSize, FFileStream.Size]));
end;

procedure TRemoteStreamSocket.DoCmdSetPosition;
var
  iPosition: Int64;
begin
  if not (CheckAndGetValue(CSPosition, iPosition)) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  FFileStream.Position := iPosition;
  DoSuccess;
end;

procedure TRemoteStreamSocket.DoCmdGetPosition;
begin
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  DoSuccess;
  FResponse.Add(Format(CSFmtInt, [CSPosition, FFileStream.Position]));
end;

procedure TRemoteStreamSocket.DoCmdRead;
var
  iCount: Integer;
  utf8Header: UTF8String;
  dwLen, dwHeaderLen: Cardinal;
begin
  if not (CheckAndGetValue(CSCount, iCount)) then
  begin
    DoFailure(FErrorCode, '');
    DoSendResult(True);
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    DoSendResult(True);
    Exit;
  end;
  if iCount > Length(FBuffer) then
    SetLength(FBuffer, iCount);
  iCount := FFileStream.Read(FBuffer[0], iCount);
  DoSuccess;
  FResponse.Add(Format(CSFmtInt, [CSCount, iCount]));
  FResponse.Add('');
  OpenWriteBuffer;
  try
    utf8Header := AnsiToUtf8(FResponse.Text);
    dwHeaderLen := Length(utf8Header);
    dwLen := SizeOf(Cardinal) + dwHeaderLen + Cardinal(iCount); //总大小
    WriteCardinal(dwLen, False); //下发长度
    WriteCardinal(Length(utf8Header), False); //下发命令长度
    WriteBuffer(PUTF8String(utf8Header)^, Length(utf8Header)); //下发数据头
    WriteBuffer(FBuffer[0], iCount);//发送数据
  finally
    FlushWriteBuffer(ioWrite);
  end;
end;

procedure TRemoteStreamSocket.DoCmdWrite;
var
  iCount: Integer;
begin
  if not (CheckAndGetValue(CSCount, iCount)) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  iCount := FFileStream.Write(FRequestData^, iCount);
  DoSuccess;
  FResponse.Add(Format(CSFmtInt, [CSCount, iCount]));
end;

procedure TRemoteStreamSocket.DoCmdSeek;
var
  iOffset: Int64;
  iSeekOrigin: Integer;
  SeekOrigin: TSeekOrigin;
begin
  if not (CheckAndGetValue(CSOffset, iOffset) and CheckAndGetValue(CSSeekOrigin, iSeekOrigin)) then
  begin
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if (iSeekOrigin < Ord(Low(TSeekOrigin))) or (iSeekOrigin > Ord(High(TSeekOrigin))) then
  begin
    FErrorCode := CIParameterError;
    DoFailure(FErrorCode, '');
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  SeekOrigin := TSeekOrigin(iSeekOrigin);
  iOffset := FFileStream.Seek(iOffset, SeekOrigin);
  DoSuccess;
  FResponse.Add(Format(CSFmtInt, [CSOffset, iOffset]));
end;

procedure TRemoteStreamSocket.DoCmdCloseFile;
begin
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile, '');
    Exit;
  end;
  FreeAndNilEx(FFileStream);
  DoSuccess;
end;

end.
