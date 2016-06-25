unit UploadSocket;

interface

uses
  IdTCPClient, BasisFunction, Windows, SysUtils, Classes, SyncObjs, DefineUnit,
  Types, BaseClientSocket, IdIOHandlerSocket, Messages;

type
  TUploadSocket = class(TThreadClientSocket)
  private
    {* 用户名 *}
    FUser, FPassword: string;
  protected
    {* 检测连接是否存在 *}
    function CheckActive: Boolean;
    {* 重连 *}
    function ReConnect: Boolean;
    {* 重连和登录 *}
    function ReConnectAndLogin: Boolean;
    {* 返回错误描述 *}
    function GetErrorCodeString(const AErrorCode: Cardinal): string; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    {* 连接服务器 *}
    function Connect(const ASvr: string; APort: Integer): Boolean;
    {* 断开连接 *}
    procedure Disconnect;
    {* 登陆 *}
    function Login(const AUser, APassword: string): Boolean;
    {* 获取目录 *}
    function Dir(const AParentDir: string; ADirectory: TStrings): Boolean;
    {* 创建目录 *}
    function CreateDir(const AParentDir, ADirName: string): Boolean;
    {* 删除目录 *}
    function DeleteDir(const AParentDir, ADirName: string): Boolean;
    {* 获取文件列表 *}
    function FileList(const ADirName: string; AFiles: TStrings): Boolean;
    {* 删除文件 *}
    function DeleteFile(const ADirName: string; AFiles: TStrings): Boolean;
    {* 开始上传 *}
    function Upload(const ADirName: string; const AFileName: string; var AFilePosition: Int64): Boolean;
    {* 发送数据 *}
    function Data(const ABuffer; const ACount: Integer): Boolean;
    {* 发送结束 *}
    function Eof(const AFileSize: Int64): Boolean;
    property User: string read FUser write FUser;
    property Password: string read FPassword write FPassword;
  end;

implementation

{ TUploadSocket }

constructor TUploadSocket.Create;
begin
  inherited;
  FTimeOutMS := 60 * 1000; //超时设置为60S
end;

destructor TUploadSocket.Destroy;
begin   
  inherited;
end;

function TUploadSocket.GetErrorCodeString(
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

function TUploadSocket.CheckActive: Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    try
      Result := ControlCommand(CSUploadCmd[ucActive], nil, nil, '');
    except
      Result := False;
    end;
  finally
    slRequest.Free;
  end;
end;

function TUploadSocket.ReConnect: Boolean;
begin
  FTimeOutMS := CI_ReadTimeOut;
  if FClient.Connected and (not CheckActive) then
    Disconnect; //断开连接重新连
  if not FClient.Connected then
  begin
    Result := Connect(FHost, FPort);
  end
  else
    Result := True;
end;

function TUploadSocket.ReConnectAndLogin: Boolean;
begin
  FTimeOutMS := CI_ReadTimeOut;
  if FClient.Connected and (not CheckActive) then
    Disconnect; //断开连接重新连
  if not FClient.Connected then
  begin 
    Result := Connect(FHost, FPort);
    if Result then
      Result := Login(FUser, FPassword);
  end
  else
    Result := True;
end;

function TUploadSocket.Connect(const ASvr: string;
  APort: Integer): Boolean;
begin
  FHost := ASvr;
  FPort := APort;
  Result := inherited Connect(#2);
end;

procedure TUploadSocket.Disconnect;
begin
  inherited Disconnect;
end;

function TUploadSocket.Login(const AUser, APassword: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnect;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSUserName, AUser]));
    slRequest.Add(Format(CSFmtString, [CSPassword, MD5String(APassword)]));
    Result := ControlCommand(CSUploadCmd[ucLogin], slRequest, nil, '');
    if Result then
    begin
      FUser := AUser;
      FPassword := APassword;
    end;
  finally
    slRequest.Free;
  end;
end;

function TUploadSocket.Dir(const AParentDir: string; ADirectory: TStrings): Boolean;
var
  slRequest, slResponse: TStringList;
  i: Integer;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSParentDir, AParentDir]));
    Result := ControlCommandThread(CSUploadCmd[ucDir], slRequest, slResponse, '');
    if Result then
    begin
      ADirectory.Clear;
      for i := 0 to slResponse.Count - 1 do
      begin
        if SameText(slResponse.Names[i], CSItem) then
        begin
          ADirectory.Add(slResponse.ValueFromIndex[i]);
        end;
      end;
    end;
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TUploadSocket.CreateDir(const AParentDir,
  ADirName: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSParentDir, AParentDir]));
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    Result := ControlCommandThread(CSUploadCmd[ucCreateDir], slRequest, nil, '');
  finally
    slRequest.Free;
  end;
end;

function TUploadSocket.DeleteDir(const AParentDir,
  ADirName: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSParentDir, AParentDir]));
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    Result := ControlCommandThread(CSUploadCmd[ucDeleteDir], slRequest, nil, '');
  finally
    slRequest.Free;
  end;
end;

function TUploadSocket.FileList(const ADirName: string;
  AFiles: TStrings): Boolean;
var
  slRequest, slResponse: TStringList;
  i: Integer;
  sItem: string;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    Result := ControlCommandThread(CSUploadCmd[ucFileList], slRequest, slResponse, '');
    if Result then
    begin
      AFiles.Clear;
      for i := 0 to slResponse.Count - 1 do
      begin
        if SameText(slResponse.Names[i], CSItem) then
        begin
          sItem := slResponse.ValueFromIndex[i];
          sItem := StringReplace(sItem, #1, CSEqualSign, []);
          AFiles.Add(sItem);
        end;
      end;
    end;
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

function TUploadSocket.DeleteFile(const ADirName: string;
  AFiles: TStrings): Boolean;
var
  slRequest: TStringList;
  i: Integer;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    for i := 0 to AFiles.Count - 1 do
      slRequest.Add(Format(CSFmtString, [CSItem, AFiles[i]]));
    Result := ControlCommandThread(CSUploadCmd[ucDeleteFile], slRequest, nil, '');
  finally
    slRequest.Free;
  end;
end;

function TUploadSocket.Upload(const ADirName, AFileName: string;
  var AFilePosition: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    slRequest.Add(Format(CSFmtString, [CSFileName, AFileName]));
    Result := ControlCommand(CSUploadCmd[ucUpload], slRequest, slResponse, '');
    if Result then
      AFilePosition := StrToInt64(slResponse.Values[CSFileSize]);
  finally
    slRequest.Free;
    slResponse.Free;
  end;
end;

function TUploadSocket.Data(const ABuffer; const ACount: Integer): Boolean;
var
  dwPacketLen, dwCommandLen: Cardinal;
  utfHeader: UTF8String;
  sHeader: string;
begin
  try
    sHeader := '[' + CSRequest + ']' + CSCrLf + CSCommand + CSEqualSign + CSData + CSCmdSeperator;
    utfHeader := AnsiToUtf8(sHeader);
    dwCommandLen := Length(utfHeader);
    dwPacketLen := SizeOf(Cardinal) + dwCommandLen + Cardinal(ACount);
    //FClient.OpenWriteBuffer(-1);
    FClient.WriteCardinal(dwPacketLen, False); //发送数据包大小
    FClient.WriteCardinal(dwCommandLen, False); //发送命令长度
    FClient.WriteBuffer(PUTF8String(utfHeader)^, dwCommandLen, True); //发送命令内容
    FClient.WriteBuffer(ABuffer, ACount);
    //FClient.FlushWriteBuffer(-1); //发送当前全部数据
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

function TUploadSocket.Eof(const AFileSize: Int64): Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSFileSize, IntToStr(AFileSize)]));
    Result := ControlCommand(CSUploadCmd[ucEof], slRequest, nil, '');
  finally
    slRequest.Free;
  end;
end;

end.
