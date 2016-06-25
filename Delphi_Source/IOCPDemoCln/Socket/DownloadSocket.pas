unit DownloadSocket;

interface

uses
  IdTCPClient, BasisFunction, Windows, SysUtils, Classes, SyncObjs, DefineUnit,
  Types, BaseClientSocket, IdIOHandlerSocket, Messages;

type
  TDownloadSocket = class(TThreadClientSocket)
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
    {* 获取文件列表 *}
    function FileList(const ADirName: string; AFiles: TStrings): Boolean;
    {* 下载文件 *}
    function Download(const ADirName: string; const AFileName: string;
      const APosition: Int64; const APacketSize: Cardinal; var AFileSize: Int64): Boolean;
    property User: string read FUser write FUser;
    property Password: string read FPassword write FPassword;
  end;

implementation

{ TUploadSocket }

constructor TDownloadSocket.Create;
begin
  inherited;
  FTimeOutMS := 60 * 1000; //超时设置为60S
end;

destructor TDownloadSocket.Destroy;
begin   
  inherited;
end;

function TDownloadSocket.GetErrorCodeString(
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

function TDownloadSocket.CheckActive: Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    try
      Result := ControlCommand(CSDownloadCmd[dcActive], nil, nil, '');
    except
      Result := False;
    end;
  finally
    slRequest.Free;
  end;
end;

function TDownloadSocket.ReConnect: Boolean;
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

function TDownloadSocket.ReConnectAndLogin: Boolean;
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

function TDownloadSocket.Connect(const ASvr: string;
  APort: Integer): Boolean;
begin
  FHost := ASvr;
  FPort := APort;
  Result := inherited Connect(#3);
end;

procedure TDownloadSocket.Disconnect;
begin
  inherited Disconnect;
end;

function TDownloadSocket.Login(const AUser, APassword: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnect;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSUserName, AUser]));
    slRequest.Add(Format(CSFmtString, [CSPassword, MD5String(APassword)]));
    Result := ControlCommand(CSDownloadCmd[dcLogin], slRequest, nil, '');
    if Result then
    begin
      FUser := AUser;
      FPassword := APassword;
    end;
  finally
    slRequest.Free;
  end;
end;

function TDownloadSocket.Dir(const AParentDir: string; ADirectory: TStrings): Boolean;
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
    Result := ControlCommandThread(CSDownloadCmd[dcDir], slRequest, slResponse, '');
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

function TDownloadSocket.FileList(const ADirName: string;
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
    Result := ControlCommandThread(CSDownloadCmd[dcFileList], slRequest, slResponse, '');
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

function TDownloadSocket.Download(const ADirName, AFileName: string;
  const APosition: Int64; const APacketSize: Cardinal; var AFileSize: Int64): Boolean;
var
  slRequest, slResponse: TStringList;
begin
  slRequest := TStringList.Create;
  slResponse := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSDirName, ADirName]));
    slRequest.Add(Format(CSFmtString, [CSFileName, AFileName]));
    slRequest.Add(Format(CSFmtString, [CSFileSize, IntToStr(APosition)])); //发送本地已有大小上去
    slRequest.Add(Format(CSFmtString, [CSPacketSize, IntToStr(APacketSize)]));
    Result := ControlCommand(CSDownloadCmd[dcDownload], slRequest, nil, '');
    if Result then
    begin
      Result := RecvCommand(slResponse);
      if Result then
        AFileSize := StrToInt64(slResponse.Values[CSFileSize]);
    end;
  finally
    slResponse.Free;
    slRequest.Free;
  end;
end;

end.
