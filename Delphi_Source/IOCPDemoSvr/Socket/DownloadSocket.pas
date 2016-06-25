unit DownloadSocket;

interface

uses
  SysUtils, Classes, IOCPSocket, ADODB, DB, Windows, DefineUnit, BaseSocket;

type
  TDownloadSocket = class(TBaseSocket)
  protected
    {* 处理数据接口 *}
    procedure Execute(AData: PByte; const ALen: Cardinal); override;
    {* 获取目录结构 *}
    procedure DoCmdDir;
    {* 获取文件列表 *}
    procedure DoCmdFileList;
    {* 开始下载 *}
    procedure DoCmdDownload;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
  end;

implementation

uses Logger, BasisFunction, OptionSet;

{ TDownloadSocket }

procedure TDownloadSocket.DoCreate;
begin
  inherited;
  LenType := ltCardinal;
  FSocketFlag := sfDownload;
end;

destructor TDownloadSocket.Destroy;
begin

  inherited;
end;

procedure TDownloadSocket.Execute(AData: PByte; const ALen: Cardinal);
var
  sErr: string;
  DownloadCmd: TDownloadCmd;
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
    if DecodePacket(AData, ALen) then
    begin
      FResponse.Clear;
      AddResponseHeader;
      DownloadCmd := StrToDownloadCommand(Command);
      if (not (DownloadCmd in [dcLogin, dcActive])) and (not FLogined) then
      begin //必须先登陆，才能发起业务
        DoFailure(CINotLogin);
        DoSendResult(True);
        Exit;
      end;
      case DownloadCmd of
        dcLogin:
        begin
          DoCmdLogin;
          DoSendResult(True);
        end;
        dcActive:
        begin
          DoSuccess;
          DoSendResult(True);
        end;
        dcDir:
        begin
          DoCmdDir;
          DoSendResult(True);
        end;
        dcFileList:
        begin
          DoCmdFileList;
          DoSendResult(True);
        end;
        dcDownload: DoCmdDownload;
      else
        DoFailure(CINoExistCommand, 'Unknow Command');
        DoSendResult(True);
      end;
    end
    else
    begin
      DoFailure(CIPackFormatError, 'Packet Must Include \r\n\r\n');
      DoSendResult(True);
    end;
  except
    on E: Exception do //发生未知错误，断开连接
    begin
      sErr := RemoteAddress + ':' + IntToStr(RemotePort) + CSComma + 'Unknow Error: ' + E.Message;
      WriteLogMsg(ltError, sErr);
      Disconnect;
    end;
  end;
end;

procedure TDownloadSocket.DoCmdDir;
var
  sParentDir: string;
  slSubDirName: TStringList;
  i: Integer;
begin
  if not CheckAndGetValue(CSParentDir, sParentDir) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if IsEmptyStr(sParentDir) then
    sParentDir := GIniOptions.FileDirestory
  else
    sParentDir := GIniOptions.FileDirestory + sParentDir;
  if not DirectoryExists(sParentDir) then //目录不存在
  begin
    DoFailure(CIDirNotExist);
    Exit;
  end;
  slSubDirName := TStringList.Create;
  try
    GetDirectoryListName(slSubDirName, sParentDir);
    DoSuccess;
    for i := 0 to slSubDirName.Count - 1 do
    begin
      FResponse.Add(Format(CSFmtString, [CSItem, slSubDirName[i]]));
    end;
  finally
    slSubDirName.Free;
  end;
end;

procedure TDownloadSocket.DoCmdFileList;
var
  sDirName, sItem: string;
  slFiles: TStringList;
  i: Integer;
begin
  if not CheckAndGetValue(CSDirName, sDirName) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if IsEmptyStr(sDirName) then
    sDirName := GIniOptions.FileDirestory
  else
    sDirName := GIniOptions.FileDirestory + sDirName;
  sDirName := IncludeTrailingPathDelimiter(sDirName);
  if not DirectoryExists(sDirName) then //目录不存在
  begin
    DoFailure(CIDirNotExist);
    Exit;
  end;
  slFiles := TStringList.Create;
  try
    GetFileListName(slFiles, sDirName, '*.*');
    DoSuccess;
    for i := 0 to slFiles.Count - 1 do
    begin
      sItem := slFiles[i] + CSTxtSeperator + IntToStr(FileSizeEx(sDirName + slFiles[i]));
      FResponse.Add(Format(CSFmtString, [CSItem, sItem]));
    end;
  finally
    slFiles.Free;
  end;
end;

procedure TDownloadSocket.DoCmdDownload;
var
  sDirName, sFileName: string;
  iFileSize: Int64;
  PacketSize: Integer;
begin
  if not (CheckAndGetValue(CSDirName, sDirName) and CheckAndGetValue(CSFileName, sFileName)
    and CheckAndGetValue(CSFileSize, iFileSize) and CheckAndGetValue(CSPacketSize, PacketSize)) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if IsEmptyStr(sDirName) then
    sDirName := GIniOptions.FileDirestory
  else
    sDirName := GIniOptions.FileDirestory + sDirName;
  if not DirectoryExists(sDirName) then //目录不存在
  begin
    DoFailure(CIDirNotExist);
    Exit;
  end;
  sFileName := IncludeTrailingPathDelimiter(sDirName) + sFileName;
  if not FileExists(sFileName) then
  begin
    DoFailure(CIFileNotExist);
    Exit;
  end;
  DoSuccess;
  OpenWriteBuffer;
  DoSendResult(False);
  SendFile(sFileName, iFileSize, PacketSize, False, False);
  FlushWriteBuffer(ioStream);
end;

end.
