unit DefineUnit;

interface

uses
  SysUtils, Classes;

type
  {* SQL Server监权方式 *}
  TDBAuthentication = (daWindows, daSQLServer);
  {* SOCKET列别 *}
  TSocketFlag = (sfNone, sfSQL, sfUpload, sfDownload, sfRemoteStream, sfThroughput, sfControl = 8, sfLog = 9);
  {* Control命令 *}
  TControlCmd = (ccNone, ccLogin, ccActive, ccGetClients);
  {* SQL命令 *}
  TSQLCmd = (scNone, scLogin, scActive, scSQLOpen, scSQLExec, scBeginTrans,
    scCommitTrans, scRollbackTrans);
  {* Upload命令 *}
  TUploadCmd = (ucNone, ucLogin, ucActive, ucDir, ucCreateDir, ucDeleteDir, ucFileList,
    ucDeleteFile, ucUpload, ucData, ucEof);
  {* Download命令 *}
  TDownloadCmd = (dcNone, dcLogin, dcActive, dcDir, dcFileList, dcDownload);
  {* 远程文件流命令 *}
  TRemoteStreamCommand = (rscNone, rscFileExists, rscOpenFile, rscSetSize, rscGetSize,
    rscSetPosition, rscGetPosition, rscRead, rscWrite, rscSeek, rscCloseFile);
  {* 吞吐量测试命令 *}
  TThroughputCommand = (tcNone, tcCyclePacket);

type
  TRemoteStreamMode = (rsmRead, rsmReadWrite);

const
  CSCompanyName = 'SQLDebug_Fan';
  CSSoftwareName = 'IOCPDemo';
  {* 通用错误码 *}
  CISuccessCode = $00000000; //正确返回
  CINoExistCommand = $00000001; //命令不存在
  CIPackLenError = $00000002; //数据包长度错误
  CIPackFormatError = $00000003; //数据包格式不正确，没有包含双回车换行
  CIUnknowError = $00000004; //发生未知错误
  CICommandNoCompleted = $00000005; //命令不完整
  CIParameterError = $00000006; //参数错误
  CIUserNotExistOrPasswordError = $00000007; //用户不存在或密码错误
  CINotLogin = $00000008; //用户没有登陆
  {* SQL协议 *}
  CISQLOpenError = $01000001; //SQL查询出错
  CISQLExecError = $01000002; //SQL执行出错
  CIHavedBeginTrans = $01000003; //已经启动了事务
  CIBeginTransError = $01000004; //启动事务出错
  CINotExistTrans = $01000005; //没有先BeginTrans
  CICommitTransError = $01000006; //CommitTrans失败
  CIRollbackTransError = $01000007; //RollbackTrans失败
  {* Upload协议 *}
  CIDirNotExist = $02000001; //目录不存在
  CICreateDirError = $02000002; //创建目录失败
  CIDeleteDirError = $02000003; //删除目录失败
  CIFileNotExist = $02000004; //文件不存在
  CIFileInUseing = $02000005; //文件正在使用中
  CINotOpenFile = $02000006; //发送数据或Eof之前，必须先Upload
  CIDeleteFileFailed = $02000007; //删除文件失败
  CIFileSizeError = $02000008; //文件大小错误

  {* 命令和数据分隔符 *}
  CSCmdSeperator = #13#10#13#10;
  CSCrLf = #13#10;
  CSTxtSeperator = #1; //文本分隔符用#1
  CSRequest = 'Request';
  CSResponse = 'Response';
  CSCommand = 'Command';
  CSComma = ';';
  CSEqualSign = '=';
  CSCode = 'Code';
  CSUserName = 'UserName';
  CSPassword = 'Password';
  CSSQL = 'SQL';
  CSSendFile = 'SendFile';
  CSData = 'Data';
  CSFileName = 'FileName';
  CSFileSize = 'FileSize';
  CSCompressSize = 'CompressSize';
  CSMessage = 'Message';
  CSTitle = 'Title';
  CSItem = 'Item';
  CSEffectRow = 'EffectRow';
  CSParentDir = 'ParentDir';
  CSDirName = 'DirName';
  CSPacketSize = 'PacketSize';
  CSMode = 'Mode';
  CSOffset = 'Offset';
  CSSeekOrigin = 'SeekOrigin';
  CSSize = 'Size';
  CSPosition = 'Position';
  CSCount = 'Count';
  CSFmtString = '%s=%s';
  CSFmtInt = '%s=%d';
  {* Control命令文本 *}
  CSControlCmd: array[TControlCmd] of string = ('', 'Login', 'Active', 'GetClients');
  {* SQL命令文本 *}
  CSSQLCmd: array[TSQLCmd] of string = ('', 'Login', 'Active', 'SQLOpen', 'SQLExec',
    'BeginTrans', 'CommitTrans', 'RollbackTrans');
  {* Upload命令文本 *}
  CSUploadCmd: array[TUploadCmd] of string = ('', 'Login', 'Active', 'Dir',
    'CreateDir', 'DeleteDir', 'FileList', 'DeleteFile', 'Upload', 'Data', 'Eof');
  {* Download命令文本 *}
  CSDownloadCmd: array[TDownloadCmd] of string = ('', 'Login', 'Active', 'Dir',
    'FileList', 'Download');
  {* 远程文件流命令 *}
  CSRemoteStreamCommand: array[TRemoteStreamCommand] of string = ('', 'FileExists',
    'OpenFile', 'SetSize', 'GetSize', 'SetPosition', 'GetPosition', 'Read',
    'Write', 'Seek', 'CloseFile');
  {* 吞吐量测试命令 *}
  CSThroughputCommand: array[TThroughputCommand] of string = ('', 'CyclePacket');

{* 获取Socket标志文本 *}
function GetSocketFlagStr(const ASocketFlag: TSocketFlag): string;
{* 字符转Control命令 *}
function StrToControlCommand(const ACommand: string): TControlCmd;
{* 字符转SQL命令 *}
function StrToSQLCommand(const ACommand: string): TSQLCmd;
{* 字符转Upload命令 *}
function StrToUploadCommand(const ACommand: string): TUploadCmd;
{* 字符转Download命令 *}
function StrToDownloadCommand(const ACommand: string): TDownloadCmd;

implementation

function GetSocketFlagStr(const ASocketFlag: TSocketFlag): string;
begin
  case ASocketFlag of
    sfSQL: Result := 'SQL';
    sfUpload: Result := 'Upload';
    sfDownload: Result := 'Download';
    sfControl: Result := 'Control';
    sfLog: Result := 'Log';
  else
    Result := '';
  end;
end;

function StrToControlCommand(const ACommand: string): TControlCmd;
var
  i: TControlCmd;
begin
  Result := ccNone;
  for i := Low(TControlCmd) to High(TControlCmd) do
  begin
    if SameText(ACommand, CSControlCmd[i]) then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function StrToSQLCommand(const ACommand: string): TSQLCmd;
var
  i: TSQLCmd;
begin
  Result := scNone;
  for i := Low(TSQLCmd) to High(TSQLCmd) do
  begin
    if SameText(ACommand, CSSQLCmd[i]) then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function StrToUploadCommand(const ACommand: string): TUploadCmd;
var
  i: TUploadCmd;
begin
  Result := ucNone;
  for i := Low(TUploadCmd) to High(TUploadCmd) do
  begin
    if SameText(ACommand, CSUploadCmd[i]) then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function StrToDownloadCommand(const ACommand: string): TDownloadCmd;
var
  i: TDownloadCmd;
begin
  Result := dcNone;
  for i := Low(TDownloadCmd) to High(TDownloadCmd) do
  begin
    if SameText(ACommand, CSDownloadCmd[i]) then
    begin
      Result := i;
      Break;
    end;
  end;
end;

end.

