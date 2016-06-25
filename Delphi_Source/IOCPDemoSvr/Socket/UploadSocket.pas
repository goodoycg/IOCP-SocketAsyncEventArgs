unit UploadSocket;

interface

uses
  SysUtils, Classes, IOCPSocket, ADODB, DB, Windows, DefineUnit, BaseSocket;

type
  TUploadSocket = class(TBaseSocket)
  private
    {* 上传文件名 *}
    FFileName: string;
    {* 文件流 *}
    FFileStream: TFileStream;
    {* 检测文件是否正在被其它Socket打开，如果打开则关闭其它Socket *}
    function CheckCloseFile(const AFileName: string): Boolean;
  protected
    {* 处理数据接口 *}
    procedure Execute(AData: PByte; const ALen: Cardinal); override;
    {* 获取目录结构 *}
    procedure DoCmdDir;
    {* 创建目录 *}
    procedure DoCmdCreateDir;
    {* 删除目录 *}
    procedure DoCmdDeleteDir;
    {* 获取文件列表 *}
    procedure DoCmdFileList;
    {* 删除文件 *}
    procedure DoCmdDeleteFile;
    {* 开始上传 *}
    procedure DoCmdUpload;
    {* 收到数据 *}
    procedure DoCmdData;
    {* 上传结束 *}
    procedure DoCmdEof;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
    {* 关闭文件 *}
    procedure CloseFile;
    property FileName: string read FFileName;
  end;

implementation

uses Logger, BasisFunction, OptionSet;

{ TUploadSocket }

procedure TUploadSocket.DoCreate;
begin
  inherited;
  LenType := ltCardinal;
  FSocketFlag := sfUpload;
end;

destructor TUploadSocket.Destroy;
begin
  inherited;
  CloseFile;
end;

procedure TUploadSocket.Execute(AData: PByte; const ALen: Cardinal);
var
  sErr: string;
  UploadCmd: TUploadCmd;
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
      UploadCmd := StrToUploadCommand(Command);
      if (not (UploadCmd in [ucLogin, ucActive])) and (not FLogined) then
      begin //必须先登陆，才能发起业务
        DoFailure(CINotLogin);
        DoSendResult(True);
        Exit;
      end;
      case UploadCmd of
        ucLogin:
        begin
          DoCmdLogin;
          DoSendResult(True);
        end;
        ucActive:
        begin
          DoSuccess;
          DoSendResult(True);
        end;
        ucDir:
        begin
          DoCmdDir;
          DoSendResult(True);
        end;
        ucCreateDir:
        begin
          DoCmdCreateDir;
          DoSendResult(True);
        end;
        ucDeleteDir:
        begin
          DoCmdDeleteDir;
          DoSendResult(True);
        end;
        ucFileList:
        begin
          DoCmdFileList;
          DoSendResult(True);
        end;
        ucDeleteFile:
        begin
          DoCmdDeleteFile;
          DoSendResult(True);
        end;
        ucUpload:
        begin
          DoCmdUpload;
          DoSendResult(True);
        end;
        ucData:
        begin
          DoCmdData;
        end;
        ucEof:
        begin
          DoCmdEof;
          DoSendResult(True);
        end;
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

procedure TUploadSocket.DoCmdDir;
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

procedure TUploadSocket.DoCmdCreateDir;
var
  sParentDir, sDirName: string;
begin
  if not (CheckAndGetValue(CSParentDir, sParentDir) and CheckAndGetValue(CSDirName, sDirName)) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if IsEmptyStr(sParentDir) then
    sParentDir := GIniOptions.FileDirestory
  else
    sParentDir := GIniOptions.FileDirestory + sParentDir;
  sParentDir := IncludeTrailingPathDelimiter(sParentDir);
  if not DirectoryExists(sParentDir) then //目录不存在
  begin
    DoFailure(CIDirNotExist);
    Exit;
  end;
  sParentDir := sParentDir + sDirName;
  if CreateDir(sParentDir) then
    DoSuccess
  else
    DoFailure(CICreateDirError, GetLastErrorString);      
end;

procedure TUploadSocket.DoCmdDeleteDir;
var
  sParentDir, sDirName: string;
begin
  if not (CheckAndGetValue(CSParentDir, sParentDir) and CheckAndGetValue(CSDirName, sDirName)) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if IsEmptyStr(sParentDir) then
    sParentDir := GIniOptions.FileDirestory
  else
    sParentDir := GIniOptions.FileDirestory + sParentDir;
  sParentDir := IncludeTrailingPathDelimiter(sParentDir) + sDirName;
  if not DirectoryExists(sParentDir) then //目录不存在
  begin
    DoFailure(CIDirNotExist);
    Exit;
  end;
  if RemoveDir(sParentDir) then
    DoSuccess
  else
    DoFailure(CIDeleteDirError, GetLastErrorString);
end;

procedure TUploadSocket.DoCmdFileList;
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

procedure TUploadSocket.DoCmdDeleteFile;
var
  sDirName, sFileName: string;
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
    for i := 0 to FRequest.Count - 1 do //获取文件列表
    begin
      if SameText(FRequest.Names[i], CSItem) then
      begin
        slFiles.Add(FRequest.ValueFromIndex[i]);
      end;
    end;
    if slFiles.Count = 0 then
    begin
      DoFailure(CIFileNotExist);
      Exit;
    end;
    for i := 0 to slFiles.Count - 1 do //检测文件是否存在
    begin
      sFileName := sDirName + slFiles[i];
      if not FileExists(sFileName) then
      begin
        DoFailure(CIFileNotExist);
        Exit;
      end;
    end;
    for i := 0 to slFiles.Count - 1 do //删除文件
    begin
      sFileName := sDirName + slFiles[i];
      if not Windows.DeleteFile(PChar(sFileName)) then //删除文件失败，返回错误码
      begin
        DoFailure(CIDeleteFileFailed, GetLastErrorStr);
        Exit;
      end;
    end;
    DoSuccess;
  finally
    slFiles.Free;
  end;
end;

procedure TUploadSocket.DoCmdUpload;
var
  sDirName, sFileName: string;
begin
  if not (CheckAndGetValue(CSDirName, sDirName) and CheckAndGetValue(CSFileName, sFileName)) then
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
  if not CheckCloseFile(FFileName) then //检测文件是否正在被使用
  begin
    DoFailure(CIFileInUseing);
    Exit;
  end;
  FFileName := sFileName;
  if FileExists(FFileName) then
    FFileStream := TFileStream.Create(FFileName, fmOpenReadWrite or fmShareDenyWrite)
  else
    FFileStream := TFileStream.Create(FFileName, fmCreate or fmOpenReadWrite or fmShareDenyWrite);
  FFileStream.Position := FFileStream.Size; //文件移到末尾
  DoSuccess;
  FResponse.Add(Format(CSFmtString, [CSFileSize, IntToStr(FFileStream.Size)])); //下发大小
  WriteLogMsg(ltInfo, 'Upload File: ' + FFileName);
end;

function TUploadSocket.CheckCloseFile(const AFileName: string): Boolean;
var
  i: Integer;
  UploadSocket: TUploadSocket;
begin //成功关闭文件返回True
  if IsFileInUse(AFileName) then
  begin
    Result := False;
    IocpServer.SocketHandles.Lock;
    try
      for i := 0 to IocpServer.SocketHandles.Count - 1 do
      begin
        if IocpServer.SocketHandles.Items[i].SocketHandle is TUploadSocket then
        begin
          UploadSocket := IocpServer.SocketHandles.Items[i].SocketHandle as TUploadSocket;
          if SameText(UploadSocket.FileName, AFileName) then
          begin
            UploadSocket.CloseFile;
            UploadSocket.Disconnect;
            Result := True;
            Break;
          end;
        end;
      end;
    finally
      IocpServer.SocketHandles.UnLock;
    end;
  end
  else
    Result := True;
end;

procedure TUploadSocket.CloseFile;
begin
  if Assigned(FFileStream) then
  begin
    FreeAndNilEx(FFileStream);
  end;
  FFileName := '';
end;

procedure TUploadSocket.DoCmdData;
begin
  if not Assigned(FFileStream) then
  begin
    WriteLogMsg(ltError, 'Data or Eof, you must first Upload');
    Disconnect;
    Exit;
  end;
  FFileStream.Write(FRequestData^, FRequestDataLen);
end;

procedure TUploadSocket.DoCmdEof;
var
  iFileSize: Int64;
  sFileName: string;
begin
  if not CheckAndGetValue(CSFileSize, iFileSize) then
  begin
    DoFailure(FErrorCode);
    Exit;
  end;
  if not Assigned(FFileStream) then
  begin
    DoFailure(CINotOpenFile);
    Exit;
  end;
  if FFileStream.Size <> iFileSize then
  begin
    DoFailure(CIFileSizeError);
    Exit;
  end;
  sFileName := FFileName;
  CloseFile;
  DoSuccess;
  WriteLogMsg(ltInfo, 'Eof: ' + sFileName);
end;

end.
