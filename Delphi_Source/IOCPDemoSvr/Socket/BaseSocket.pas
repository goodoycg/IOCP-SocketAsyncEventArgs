unit BaseSocket;

interface

uses
  SysUtils, Classes, IOCPSocket, ADODB, DB, Windows, DateUtils, ActiveX,
  DefineUnit, ZLibEx;

type
  TBaseSocketClass = class of TBaseSocket;
  {* SOCKET协议处理基类 *}
  TBaseSocket = class(TSocketHandle)
  protected
    {* 协议类型 *}
    FSocketFlag: TSocketFlag;
    {* 数据包 *}
    FRequestData: PByte;
    FRequestDataLen: Integer;
    {* 协议的请求和接收串 *}
    FRequest, FResponse: TStrings;
    {* 登陆的用户 *}
    FUserName: string;
    {* 是否已经登陆 *}
    FLogined: Boolean;
    {* 协议校验错误码 *}
    FErrorCode: Integer;
    {* 发送流 *}
    FSendStream: TStream;
    FSendFile: string;
    {* 是否删除发送完成的文件 *}
    FDeleteFile: Boolean;
    {* 读取数据缓存 *}
    FPacketSize: Integer;
    FSendBuffer: array of Byte;
    {* 发送结果 *}
    procedure DoSendResult(const AWriteNow: Boolean); virtual;
    {* 分发命令和数据 *}
    function DecodePacket(APacketData: PByte; const ALen: Integer): Boolean; virtual;
    {* 返回命令 *}
    function GetCommand: string;
    {* 命令成功执行 *}
    procedure DoSuccess;
    {* 命令返回错误 *}
    procedure DoFailure(const ACode: Integer); overload;
    procedure DoFailure(const ACode: Integer; const AMessage: string); overload;
    {* 添加返回命令头 *}
    procedure AddResponseHeader;
    {* 检测参数合法性 *}
    function CheckCommandKey(const ACommandKey: string): Boolean;
    function CheckAndGetValue(const ACommandKey: string; var AValue: string): Boolean; overload;
    function CheckAndGetValue(const ACommandKey: string; var AValue: Integer): Boolean; overload;
    function CheckAndGetValue(const ACommandKey: string; var AValue: Int64): Boolean; overload;
    function CheckAndGetValue(const ACommandKey: string; var AValue: Cardinal): Boolean; overload;
    function CheckAndGetValue(const ACommandKey: string; var AValue: Word): Boolean; overload;
    {* 由于发送大文件需要采用回调，不能全部压入完成端口中，否则会造成内存溢出 *}
    procedure WriteStream(const AWriteNow: Boolean = True); override;
    {* 登录放到基类 *}
    procedure DoCmdLogin; virtual;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
    {* 发送文件, APacketSize为每次下发大小，单位为KB *}
    procedure SendFile(const AFileName: string; const APosition: Int64;
      const APacketSize: Cardinal; const ADeleteFile: Boolean; const AWriteNow: Boolean);
    procedure SendStream(AStream: TStream; const APacketSize: Cardinal; const AWriteNow: Boolean);
    {* 把数据以string返回 *}
    function GetRequestDataStr: string;
    property Command: string read GetCommand;
    property SocketFlag: TSocketFlag read FSocketFlag;
    property UserName: string read FUserName;
  end;

implementation

uses BasisFunction, Logger;

{ TBaseSocket }

destructor TBaseSocket.Destroy;
begin
  FRequest.Free;
  FResponse.Free;
  inherited;
end;

procedure TBaseSocket.DoCreate;
begin
  inherited;
  FRequest := TStringList.Create;
  FResponse := TStringList.Create;
end;

function TBaseSocket.DecodePacket(APacketData: PByte;
  const ALen: Integer): Boolean;
var
  CommandLen: Integer;
  UTF8Command: UTF8String;
begin
  if ALen > 4 then //命令长度为4字节，因而长度必须大于4
  begin
    CopyMemory(@CommandLen, APacketData, SizeOf(Cardinal)); //获取命令长度
    Inc(APacketData, SizeOf(Cardinal));
    SetLength(UTF8Command, CommandLen);
    CopyMemory(PUTF8String(UTF8Command), APacketData, CommandLen); //读取命令
    Inc(APacketData, CommandLen);
    FRequestData := APacketData; //数据
    FRequestDataLen := ALen - SizeOf(Cardinal) - CommandLen; //数据长度
    FRequest.Text := Utf8ToAnsi(UTF8Command); //把UTF8转为Ansi
    Result := True;
  end
  else
    Result := False; 
end;

procedure TBaseSocket.DoSendResult(const AWriteNow: Boolean);
var
  wLen: Word;
  cLen: Cardinal;
  utf8Buff: UTF8String;
begin
  if not Connected then Exit;
  if AWriteNow then
    OpenWriteBuffer;
  utf8Buff := AnsiToUtf8(FResponse.Text); //转为UTF8
  if LenType = ltWord then
  begin
    wLen := Length(utf8Buff) + SizeOf(Cardinal); //总长度
    WriteWord(wLen, False);
  end
  else if LenType = ltCardinal then
  begin
    cLen := Length(utf8Buff) + SizeOf(Cardinal); //总长度
    WriteCardinal(cLen, False);
  end;
  WriteCardinal(Length(utf8Buff), False); //下发命令长度
  WriteBuffer(PUTF8String(utf8Buff)^, Length(utf8Buff)); //命令内容
  if AWriteNow then
    FlushWriteBuffer(ioWrite); //直接发送
end;

function TBaseSocket.GetCommand: string;
begin
  Result := FRequest.Values[CSCommand];
end;

procedure TBaseSocket.DoSuccess;
begin
  FResponse.Add(CSCode + CSEqualSign + IntToStr(CISuccessCode));
end;

procedure TBaseSocket.DoFailure(const ACode: Integer);
begin
  FResponse.Values[CSCode] := IntToStr(ACode);
  WriteLogMsg(ltError, GetSocketFlagStr(FSocketFlag) + CSComma + RemoteAddress + ':'
    + IntToStr(RemotePort) + CSComma + Command + ' Failed, Error Code: 0x' + IntToHex(ACode, 8));
end;

procedure TBaseSocket.DoFailure(const ACode: Integer;
  const AMessage: string);
begin
  FResponse.Values[CSCode] := IntToStr(ACode);
  FResponse.Values[CSMessage] := AMessage;
  WriteLogMsg(ltError, GetSocketFlagStr(FSocketFlag) + CSComma + RemoteAddress + ':'
    + IntToStr(RemotePort) + CSComma + Command + ' Failed, Error Code: 0x'
    + IntToHex(ACode, 8) + ', Message: ' + AMessage);
end;

procedure TBaseSocket.AddResponseHeader;
begin
  FResponse.Add('[' + CSResponse + ']');
  FResponse.Add(CSCommand + CSEqualSign + Command);
end;

function TBaseSocket.CheckCommandKey(const ACommandKey: string): Boolean;
begin
  if FRequest.IndexOfName(ACommandKey) = -1 then
  begin
    FErrorCode := CICommandNoCompleted;
    Result := False;
  end
  else
  begin
    Result := True;
  end;
end;

function TBaseSocket.CheckAndGetValue(const ACommandKey: string;
  var AValue: string): Boolean;
begin
  Result := CheckCommandKey(ACommandKey);
  if Result then
  begin
    AValue := FRequest.Values[ACommandKey];
  end;
end;

function TBaseSocket.CheckAndGetValue(const ACommandKey: string;
  var AValue: Integer): Boolean;
var
  sValue: string;
begin
  Result := CheckCommandKey(ACommandKey);
  if Result then
  begin
    sValue := FRequest.Values[ACommandKey];
    if not IsInteger(sValue) then
    begin
      FErrorCode := CIParameterError;
      Result := False;
    end
    else
    begin
      AValue := StrToInt(sValue);
      Result := True;
    end;
  end;
end;

function TBaseSocket.CheckAndGetValue(const ACommandKey: string;
  var AValue: Int64): Boolean;
var
  sValue: string;
begin
  Result := CheckCommandKey(ACommandKey);
  if Result then
  begin
    sValue := FRequest.Values[ACommandKey];
    if not IsInt64(sValue) then
    begin
      FErrorCode := CIParameterError;
      Result := False;
    end
    else
    begin
      AValue := StrToInt64(sValue);
      Result := True;
    end;
  end;
end;

function TBaseSocket.CheckAndGetValue(const ACommandKey: string;
  var AValue: Cardinal): Boolean;
var
  sValue: string;
begin
  Result := CheckCommandKey(ACommandKey);
  if Result then
  begin
    sValue := FRequest.Values[ACommandKey];
    if not IsInteger(sValue) then
    begin
      FErrorCode := CIParameterError;
      Result := False;
    end
    else
    begin
      AValue := StrToInt(sValue);
      Result := True;
    end;
  end;
end;

function TBaseSocket.CheckAndGetValue(const ACommandKey: string;
  var AValue: Word): Boolean;
var
  sValue: string;
begin
  Result := CheckCommandKey(ACommandKey);
  if Result then
  begin
    sValue := FRequest.Values[ACommandKey];
    if not IsInteger(sValue) then
    begin
      FErrorCode := CIParameterError;
      Result := False;
    end
    else
    begin
      AValue := StrToInt(sValue);
      Result := True;
    end;
  end;
end;

procedure TBaseSocket.WriteStream(const AWriteNow: Boolean = True);
var
  sDataHeader: string;
  utf8Header: UTF8String;
  dwLen, dwReadLen, dwHeaderLen: Cardinal;
begin
  if not Assigned(FSendStream) then Exit;
  if FSendStream.Position < FSendStream.Size then
  begin
    if AWriteNow then
      OpenWriteBuffer;
    sDataHeader := '[' + CSResponse + ']' + CSCrLf + CSCommand
      + CSEqualSign + CSData + CSCmdSeperator;
    utf8Header := AnsiToUtf8(sDataHeader);
    dwHeaderLen := Length(utf8Header);
    if Length(FSendBuffer) < FPacketSize then
      SetLength(FSendBuffer, FPacketSize);
    dwReadLen :=  FSendStream.Read(FSendBuffer[0], FPacketSize);    
    dwLen := SizeOf(Cardinal) + dwHeaderLen + dwReadLen; //总大小
    WriteCardinal(dwLen, False); //下发长度
    WriteCardinal(Length(utf8Header), False); //下发命令长度
    WriteBuffer(PUTF8String(utf8Header)^, Length(utf8Header)); //下发数据头
    WriteBuffer(FSendBuffer[0], dwReadLen); //下发内容
    if AWriteNow then
      FlushWriteBuffer(ioStream);
  end
  else //发送完成
  begin
    FreeAndNilEx(FSendStream);
    if FSendFile <> '' then
    begin
      try
        if FDeleteFile then
        begin
          if FileExists(FSendFile) and (not IsFileInUse(FSendFile)) then
            DeleteFile(PChar(FSendFile));
        end;
        FSendFile := '';
      except
        on E: Exception do
        begin
          WriteLogMsg(ltError, 'WriteStream DeleteFile, Error, Message: ' + E.Message);
        end;
      end;  
    end;
  end;
end;

procedure TBaseSocket.SendFile(const AFileName: string; const APosition: Int64;
      const APacketSize: Cardinal; const ADeleteFile: Boolean; const AWriteNow: Boolean);
begin
  if Assigned(FSendStream) then
    FreeAndNilEx(FSendStream);
  FSendStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  FSendStream.Position := APosition;
  FSendFile := AFileName;
  FDeleteFile := ADeleteFile;
  FPacketSize := APacketSize;
  //发送文件头
  FResponse.Clear;
  FResponse.Add('[' + CSResponse + ']');
  FResponse.Add(Format(CSFmtString, [CSCommand, CSSendFile]));
  FResponse.Add(Format(CSFmtString, [CSFileSize, IntToStr(FSendStream.Size - APosition)]));
  DoSuccess;
  DoSendResult(AWriteNow);
  WriteStream(AWriteNow); //开始发送流
end;

procedure TBaseSocket.SendStream(AStream: TStream;
  const APacketSize: Cardinal; const AWriteNow: Boolean);
begin
  if Assigned(FSendStream) then
    FreeAndNilEx(FSendStream);
  FSendStream := AStream;
  FPacketSize := APacketSize;
  //发送文件头
  FResponse.Clear;
  FResponse.Add('[' + CSResponse + ']');
  FResponse.Add(Format(CSFmtString, [CSCommand, CSSendFile]));
  FResponse.Add(Format(CSFmtString, [CSFileSize, IntToStr(FSendStream.Size - FSendStream.Position)]));
  DoSuccess;
  DoSendResult(AWriteNow);
  WriteStream(AWriteNow); //开始发送流
end;

procedure TBaseSocket.DoCmdLogin;
var
  sUserName, sPassword: string;  
begin
  if not (CheckAndGetValue(CSUserName, sUserName) and CheckAndGetValue(CSPassword, sPassword)) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  FUserName := sUserName;
  if MD5Match('admin', sPassword) then //校验密码
  begin
    FLogined := True;
    DoSuccess;
    WriteLogMsg(ltInfo, Format('User: %s Login', [sUserName]));
  end
  else
  begin
    FLogined := False;
    DoFailure(CIUserNotExistOrPasswordError);
  end;
end;

function TBaseSocket.GetRequestDataStr: string;
begin
  Result := DataToHex(PChar(FRequestData), FRequestDataLen);
end;

end.
