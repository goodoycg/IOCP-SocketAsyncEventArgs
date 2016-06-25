unit Logger;

interface

uses
  Windows, SysUtils, Classes, SyncObjs, ActiveX, Messages, Graphics;

const
  {* 日志消息 *}
  WM_LOG = WM_USER + 6001;

type
  {* 日志类型 *}
  TLogType = (ltInfo, ltSucc, ltWarn, ltError, ltDebug);
  TLogFilter = array[TLogType] of Boolean;
  {* 日志处理操作 *}
  TLogProcess = (lpFile, lpDesktop, lpDatabase, lpSocket);
  TLogProcessSet = set of TLogProcess;
  {* 日志处理事件 *}
  TOnLog = procedure(const ALogType: TLogType; const ALog: string) of object;

  TLogMgr = class;
  TLogHandler = class;
  TLogHandlerMgr = class;
  TLogThread = class;

  {* 日志实现类，提供外部接口 *}
  TLogger = class(TObject)
  private
    {* 日志列表类 *}
    FLogMgr: TLogMgr;
    {* 日志分隔符 *}
    FLogSeparator: Char;
    {* 日志是否加时间戳 *}
    FDateTimeStamp: Boolean;
    {* 日志处理类列表 *}
    FLogHandlerMgr: TLogHandlerMgr;
    {* 日志处理线程 *}
    FLogThread: TLogThread;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    {* 添加日志 *}
    procedure AddLog(const ALogType: TLogType; const ALogMsg: string); overload;
    {* 启动 *}
    procedure Start;
    {* 停止 *}
    procedure Stop;

    property LogSeparator: Char read FLogSeparator write FLogSeparator;
    property DateTimeStamp: Boolean read FDateTimeStamp write FDateTimeStamp;
    property LogMgr: TLogMgr read FLogMgr;
    property LogHandlerMgr: TLogHandlerMgr read FLogHandlerMgr;
  end;

  {* 日志记录基类 *}
  TLogRecordBase = class(TObject)
  protected
    {* 日志接口对象 *}
    FLogger: TLogger;
    {* 日志类型 *}
    FLogType: TLogType;
    {* 日志时间 *}
    FLogTime: TDateTime;
    {* 日志内容 *}
    FLogMsg: string;
    {* 返回错误描述 *}
    function GetLogTypeStr(const ALogType: TLogType): string;
  public
    constructor Create(ALogger: TLogger; const ALogType: TLogType;
      const ALogTime: TDateTime; const ALogMsg: string); virtual;
    destructor Destroy; override;
    {* 格式化方法 *}
    function FormatLog: string; virtual;

    property LogType: TLogType read FLogType;
    property LogTime: TDateTime read FLogTime;
    property LogMsg: string read FLogMsg;
  end;

  {* 日志列表类，缓存日志列表，自己不提供锁功能，需要在调用的时候加锁 *}
  TLogMgr = class(TObject)
  private
    {* 日志接口对象 *}
    FLogger: TLogger;
    {* 列表管理类 *}
    FList: TList;
    {* 锁 *}
    FLock: TCriticalSection;
    {* 获取个数 *}
    function GetCount: Integer;
    {* 获取某一个项 *}
    function GetItems(const AIndex: Integer): TLogRecordBase;
  public
    constructor Create(ALogger: TLogger); virtual;
    destructor Destroy; override;
    {* 清除 *}
    procedure Clear;
    {* 添加 *}
    procedure Add(const ALogType: TLogType; const ALogMsg: string); overload;
    procedure Add(ALogRecord: TLogRecordBase); overload;
    {* 删除 *}
    procedure Delete(const AIndex: Integer);
    {* 剪贴数据，并清除本地列表 *}
    procedure CutData(ALogMgr: TLogMgr);

    property Count: Integer read GetCount;
    property Items[const AIndex: Integer]: TLogRecordBase read GetItems; default;
  end;

  {* 日志处理线程 *}
  TLogThread = class(TThread)
  private
    FLogger: TLogger;
  protected
    procedure Execute; override;
  end;

  TLogHandlerMgr = class(TObject)
  private
    {* 列表 *}
    FList: TList;
    {* 锁 *}
    FLock: TCriticalSection;
    {* 获取个数 *}
    function GetCount: Integer;
    {* 获取某一个项 *}
    function GetItems(const AIndex: Integer): TLogHandler;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    {* 清除 *}
    procedure Clear;
    {* 添加 *}
    procedure Add(ALogHandler: TLogHandler);
    {* 删除 *}
    procedure Delete(ALogHandler: TLogHandler);

    property Count: Integer read GetCount;
    property Items[const AIndex: Integer]: TLogHandler read GetItems; default;
  end;

  {* 日志处理基类 *}
  TLogHandler = class(TObject)
  private
    {* 日志接口对象 *}
    FLogger: TLogger;
    {* 过滤 *}
    FLogFilter: TLogFilter;
  protected
    constructor Create(ALogger: TLogger); virtual;
  public
    {* 执行日志处理的接口 *}
    procedure DoExceute(const ALogRecord: TLogRecordBase); virtual;
    {* 过滤 *}
    function DoFilter(const ALogRecord: TLogRecordBase): Boolean; virtual;

    property LogFilter: TLogFilter read FLogFilter write FLogFilter;
  end;

  {* 日志写文件 *}
  TLogFileHandler = class(TLogHandler)
  private
    {* 文件流 *}
    FFileStream: TFileStream;
    {* 循环写文件名 *}
    FFileName1, FFileName2, FCurrFileName: string;
    {* 单个文件最大大小，单位Byte，为0表示没有限制 *}
    FMaxFileSize: Int64;
  public
    constructor Create(ALogger: TLogger; const AFileName1, AFileName2: string); reintroduce; virtual;
    destructor Destroy; override;
    {* 把日志内容清除 *}
    procedure Clear;
    {* 执行日志处理的接口 *}
    procedure DoExceute(const ALogRecord: TLogRecordBase); override;
    {* 过滤 *}
    function DoFilter(const ALogRecord: TLogRecordBase): Boolean; override;

    property FileName1: string read FFileName1;
    property FileName2: string read FFileName2;
    property MaxFileSize: Int64 read FMaxFileSize write FMaxFileSize;
  end;

  {* 桌面显示日志 *}
  TLogDesktopHandler = class(TLogHandler)
  private
    {* 接收消息句柄 *}
    FHandle: THandle;
  public
    {* AHandle为接收消息句柄 *}
    constructor Create(ALogger: TLogger; const AHandle: THandle); reintroduce; virtual;
    destructor Destroy; override;
    {* 执行日志处理的接口 *}
    procedure DoExceute(const ALogRecord: TLogRecordBase); override;
    {* 过滤 *}
    function DoFilter(const ALogRecord: TLogRecordBase): Boolean; override;
  end;

  
  {* Socket下发日志 *}
  TLogSocketHandler = class(TLogHandler)
  private
    {* 日志响应事件 *}
    FOnLog: TOnLog;
    {* 触发日志事件 *}
    procedure DoLog(const ALogType: TLogType; const ALog: string);
  public
    constructor Create(ALogger: TLogger); reintroduce; virtual;
    {* 执行日志处理的接口 *}
    procedure DoExceute(const ALogRecord: TLogRecordBase); override;
    {* 过滤 *}
    function DoFilter(const ALogRecord: TLogRecordBase): Boolean; override;
    property OnLog: TOnLog read FOnLog write FOnLog;
  end;

  {* 数据库写日志 *}
  TLogDatabaseHandler = class(TLogHandler)
  private
    {* 日志响应事件 *}
    FOnLog: TOnLog;
    {* 触发日志事件 *}
    procedure DoLog(const ALogType: TLogType; const ALog: string);
  public
    constructor Create(ALogger: TLogger); reintroduce; virtual;
    {* 执行日志处理的接口 *}
    procedure DoExceute(const ALogRecord: TLogRecordBase); override;
    {* 过滤 *}
    function DoFilter(const ALogRecord: TLogRecordBase): Boolean; override;
    property OnLog: TOnLog read FOnLog write FOnLog; 
  end;

var
  GLogger, GDebugLogger: TLogger;

procedure InitLogger(const ALogSizeKB: Integer; const ALogPath: string);
procedure UnInitLogger;
procedure WriteLogMsg(const ALogType: TLogType; const ALogMsg: string);
procedure WriteLogMsgFmt(const ALogType: TLogType; const ALogMsg: string; AParams: array of const);
procedure WriteDebugLogMsg(const ALogType: TLogType; const ALogMsg: string);
{* 获取日志颜色 *}
function GetLogColor(const ALogType: TLogType): TColor;

const
  CSLogType: array[TLogType] of string = ('Info', 'Succ', 'Warn', 'Error', 'Debug');
  {* 回车换行 *}
  CSCrLf = #13#10;
  CDefaultColor: array[TLogType] of TColor = (clBlack, clBlack, clFuchsia, clRed, clBlue);

implementation

uses BasisFunction;

procedure InitLogger(const ALogSizeKB: Integer; const ALogPath: string);
var
  sAppFileName, sLogFile1, sLogFile2: string;
  LogFileHandler: TLogFileHandler;
begin
  GLogger := TLogger.Create;
  sAppFileName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  sLogFile1 := ExtractFilePath(ParamStr(0)) + ALogPath + '\' + sAppFileName + '-0.log';
  sLogFile2 := ExtractFilePath(ParamStr(0)) + ALogPath + '\' + sAppFileName + '-1.log';
  LogFileHandler := TLogFileHandler.Create(GLogger, sLogFile1, sLogFile2);
  LogFileHandler.MaxFileSize := ALogSizeKB * 1024;
  GLogger.LogHandlerMgr.Add(LogFileHandler);
  GLogger.Start;

  GDebugLogger := TLogger.Create;
  sAppFileName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  sLogFile1 := ExtractFilePath(ParamStr(0)) + ALogPath + '\' + sAppFileName + '_Debug_0.log';
  sLogFile2 := ExtractFilePath(ParamStr(0)) + ALogPath + '\' + sAppFileName + '_Debug_1.log';
  LogFileHandler := TLogFileHandler.Create(GDebugLogger, sLogFile1, sLogFile2);
  LogFileHandler.MaxFileSize := ALogSizeKB * 1024;
  GDebugLogger.LogHandlerMgr.Add(LogFileHandler);
  GDebugLogger.Start;
end;

procedure UnInitLogger;
begin
  GLogger.Stop;
  FreeAndNil(GLogger);
  GDebugLogger.Stop;
  FreeAndNil(GDebugLogger);
end;

procedure WriteLogMsg(const ALogType: TLogType; const ALogMsg: string);
begin
  if Assigned(GLogger) then
    GLogger.AddLog(ALogType, ALogMsg);
end;

procedure WriteLogMsgFmt(const ALogType: TLogType; const ALogMsg: string; AParams: array of const);
begin
  WriteLogMsg(ALogType, Format(ALogMsg, AParams));
end;

procedure WriteDebugLogMsg(const ALogType: TLogType; const ALogMsg: string);
begin
  if Assigned(GDebugLogger) then
    GDebugLogger.AddLog(ALogType, ALogMsg);
end;

function GetLogColor(const ALogType: TLogType): TColor;
begin
  if (ALogType >= Low(TLogType)) and (ALogType <= High(TLogType)) then
    Result := CDefaultColor[ALogType]
  else
    Result := clBlack;
end;

{ TLogger }

constructor TLogger.Create;
begin
  FLogMgr := TLogMgr.Create(Self);
  FLogSeparator := ';'; //默认为分号
  FDateTimeStamp := True;
  FLogHandlerMgr := TLogHandlerMgr.Create;
end;

destructor TLogger.Destroy;
begin
  FLogMgr.Free;
  FLogHandlerMgr.Free;
  inherited;
end;

procedure TLogger.AddLog(const ALogType: TLogType; const ALogMsg: string);
begin
  FLogMgr.Add(ALogType, ALogMsg);
end;

procedure TLogger.Start;
begin
  if not Assigned(FLogThread) then
  begin
    FLogThread := TLogThread.Create(True);
    FLogThread.FLogger := Self;
    FLogThread.FreeOnTerminate := False;
    FLogThread.Resume;
  end;
end;

procedure TLogger.Stop;
begin
  if Assigned(FLogThread) then
  begin
    FLogThread.Terminate;
    FLogThread.WaitFor;
    FLogThread.Free;
    FLogThread := nil;
  end;
end;

{ TLogRecordBase }

constructor TLogRecordBase.Create(ALogger: TLogger; const ALogType: TLogType;
  const ALogTime: TDateTime; const ALogMsg: string);
begin
  FLogger := ALogger;
  FLogType := ALogType;
  FLogTime := ALogTime;
  FLogMsg := ALogMsg;
end;

destructor TLogRecordBase.Destroy;
begin
  inherited;
end;

function TLogRecordBase.FormatLog: string;
begin
  Result := GetLogTypeStr(FLogType) + FLogger.LogSeparator + FLogMsg;
  if FLogger.DateTimeStamp then
    Result := DateTimeToStr(FLogTime) + FLogger.LogSeparator + Result;
end;

function TLogRecordBase.GetLogTypeStr(const ALogType: TLogType): string;
begin
  if (ALogType >= Low(TLogType)) and (ALogType <= High(TLogType)) then
    Result := CSLogType[ALogType]
  else
    Result := '';
end;

{ TLogMgr }

constructor TLogMgr.Create(ALogger: TLogger);
begin
  FLogger := ALogger;
  FList := TList.Create;
  FLock := TCriticalSection.Create;
end;

destructor TLogMgr.Destroy;
begin
  Clear;
  FList.Free;
  FLock.Free;
  inherited;
end;

procedure TLogMgr.Clear;
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := 0 to FList.Count - 1 do
    begin
      TLogRecordBase(FList[i]).Free;
    end;
    FList.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TLogMgr.Add(ALogRecord: TLogRecordBase);
begin
  FLock.Enter;
  try
    FList.Add(ALogRecord);
  finally
    FLock.Leave;
  end;
end;

procedure TLogMgr.Add(const ALogType: TLogType; const ALogMsg: string);
var
  LogRecord: TLogRecordBase;
begin
  LogRecord := TLogRecordBase.Create(FLogger, ALogType, Now, ALogMsg);
  Add(LogRecord);
end;

procedure TLogMgr.Delete(const AIndex: Integer);
var
  LogRecord: TLogRecordBase;
begin
  FLock.Enter;
  try
    LogRecord := TLogRecordBase(FList.Items[AIndex]);
    LogRecord.Free;
    FList.Delete(AIndex);
  finally
    FLock.Leave;
  end;
end;

function TLogMgr.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TLogMgr.GetItems(const AIndex: Integer): TLogRecordBase;
begin
  Result := FList[AIndex];
end;

procedure TLogMgr.CutData(ALogMgr: TLogMgr);
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := 0 to Count - 1 do
    begin
      ALogMgr.Add(TLogRecordBase(Items[i]));
    end;
    FList.Clear; //清除本地列表，但不释放内存
  finally
    FLock.Leave;
  end;
end;

{ TLogThread }

procedure TLogThread.Execute;
var
  LogMgr: TLogMgr;
  i, j: Integer;
begin
  inherited;
  CoInitialize(nil);
  try
    while not Terminated do
    begin
      try
        if FLogger.LogMgr.Count > 0 then
        begin
          LogMgr := TLogMgr.Create(FLogger);
          try
            FLogger.LogMgr.CutData(LogMgr); //先复制数据
            for i := 0 to LogMgr.Count - 1 do
            begin
              for j := FLogger.LogHandlerMgr.Count - 1 downto 0 do
              begin
                if FLogger.LogHandlerMgr.Items[j].DoFilter(LogMgr.Items[i]) then
                  FLogger.LogHandlerMgr.Items[j].DoExceute(LogMgr.Items[i]);
              end;
            end;
            LogMgr.Clear;
          finally
            LogMgr.Free;
          end;
        end;
      except
        ; //出错了，接着往下执行
      end;
      Sleep(100);
    end;
  finally
    CoUninitialize;
  end;
end;

{ TLogHandlerMgr }

function TLogHandlerMgr.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TLogHandlerMgr.GetItems(const AIndex: Integer): TLogHandler;
begin
  Result := FList[AIndex];
end;

procedure TLogHandlerMgr.Clear;
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := 0 to Count - 1 do
    begin
      Items[i].Free;
    end;
    FList.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TLogHandlerMgr.Add(ALogHandler: TLogHandler);
begin
  FLock.Enter;
  try
    FList.Add(ALogHandler);
  finally
    FLock.Leave;
  end;
end;

procedure TLogHandlerMgr.Delete(ALogHandler: TLogHandler);
var
  iIndex: Integer;
begin
  FLock.Enter;
  try
    iIndex := FList.IndexOf(ALogHandler);
    if iIndex <> -1 then
      FList.Delete(iIndex);
  finally
    FLock.Leave;
  end;
end;

constructor TLogHandlerMgr.Create;
begin
  FList := TList.Create;
  FLock := TCriticalSection.Create;
end;

destructor TLogHandlerMgr.Destroy;
begin
  Clear;
  FList.Free;
  FLock.Free;
  inherited;
end;

{ TLogHandler }

constructor TLogHandler.Create(ALogger: TLogger);
begin
  FLogger := ALogger;
  FLogFilter[ltInfo] := True;
  FLogFilter[ltSucc] := True;
  FLogFilter[ltWarn] := True;
  FLogFilter[ltError] := True;
  FLogFilter[ltDebug] := True;
end;

procedure TLogHandler.DoExceute(const ALogRecord: TLogRecordBase);
begin

end;

function TLogHandler.DoFilter(const ALogRecord: TLogRecordBase): Boolean;
begin
  if (ALogRecord.LogType in [Low(TLogType)..High(TLogType)]) and (FLogFilter[ALogRecord.LogType]) then
    Result := True
  else
    Result := False;
end;

{ TFileHandler }

constructor TLogFileHandler.Create(ALogger: TLogger; const AFileName1, AFileName2: string);
var
  sLogPath: string;
begin
  inherited Create(ALogger);
  FFileName1 := AFileName1;
  FFileName2 := AFileName2;
  FCurrFileName := FFileName1;
  sLogPath := ExtractFilePath(FCurrFileName);
  if not DirectoryExists(sLogPath) then
    ForceDirectories(sLogPath);
  CreateFileOnDisk(FCurrFileName);
  FFileStream := TFileStream.Create(FCurrFileName, fmOpenReadWrite or fmShareDenyWrite);
  FFileStream.Position := FFileStream.Size;
end;

destructor TLogFileHandler.Destroy;
begin
  FFileStream.Free;
  inherited;
end;

procedure TLogFileHandler.Clear;
begin
  FFileStream.Size := 0;
  FFileStream.Position := 0;
end;

procedure TLogFileHandler.DoExceute(const ALogRecord: TLogRecordBase);
var
  sLog: string;
begin
  inherited;
  sLog := ALogRecord.FormatLog;
  //如果Log大小超过了最大限制，则开始写另外一个文件
  if (FMaxFileSize > 0) and (FFileStream.Position > FMaxFileSize) then
  begin
    if FCurrFileName = FFileName1 then
      FCurrFileName := FFileName2
    else
      FCurrFileName := FFileName1;
    FFileStream.Free;  //先释放老的文件
    CreateFileOnDisk(FCurrFileName);
    FFileStream := TFileStream.Create(FCurrFileName, fmOpenReadWrite or fmShareDenyWrite);
    if FFileStream.Size > FMaxFileSize then //如果超出文件大小则重写
    begin
      FFileStream.Size := 0;
      FFileStream.Position := 0;
    end
    else //否则续写
      FFileStream.Seek(FFileStream.Size, soFromBeginning);
  end;

  FFileStream.Write(PChar(sLog)^, Length(sLog)); //写入日志
  FFileStream.Write(CSCrLf, 2); //写入回车换行
end;

function TLogFileHandler.DoFilter(const ALogRecord: TLogRecordBase): Boolean;
begin
  Result := inherited DoFilter(ALogRecord);
end;

{ TDesktopHandler }

constructor TLogDesktopHandler.Create(ALogger: TLogger;
  const AHandle: THandle);
begin
  inherited Create(ALogger);
  FHandle := AHandle;
end;

destructor TLogDesktopHandler.Destroy;
begin
  inherited;
end;

procedure TLogDesktopHandler.DoExceute(const ALogRecord: TLogRecordBase);
var
  sLog: string;
begin
  inherited;
  sLog := ALogRecord.FormatLog;
  SendMessage(FHandle, WM_LOG, Ord(ALogRecord.LogType), Integer(PChar(sLog)));
end;

function TLogDesktopHandler.DoFilter(const ALogRecord: TLogRecordBase): Boolean;
begin
  Result := inherited DoFilter(ALogRecord);
end;

{ TLogSocketHandler }

constructor TLogSocketHandler.Create(ALogger: TLogger);
begin
  inherited Create(ALogger);
end;

procedure TLogSocketHandler.DoLog(const ALogType: TLogType; const ALog: string);
begin
  if Assigned(FOnLog) then
    FOnLog(ALogType, ALog);
end;

procedure TLogSocketHandler.DoExceute(const ALogRecord: TLogRecordBase);
var
  sLog: string;
begin
  inherited;
  sLog := ALogRecord.FormatLog;
  DoLog(ALogRecord.LogType, sLog);
end;

function TLogSocketHandler.DoFilter(const ALogRecord: TLogRecordBase): Boolean;
begin
  Result := inherited DoFilter(ALogRecord);
end;

{ TLogDatabaseHandler }

constructor TLogDatabaseHandler.Create(ALogger: TLogger);
begin
  inherited Create(ALogger);
end;

procedure TLogDatabaseHandler.DoLog(const ALogType: TLogType;
  const ALog: string);
begin
  if Assigned(FOnLog) then
    FOnLog(ALogType, ALog);
end;

procedure TLogDatabaseHandler.DoExceute(const ALogRecord: TLogRecordBase);
var
  sLog: string;
begin
  inherited;
  sLog := ALogRecord.FormatLog;
  DoLog(ALogRecord.LogType, sLog);
end;

function TLogDatabaseHandler.DoFilter(
  const ALogRecord: TLogRecordBase): Boolean;
begin
  Result := inherited DoFilter(ALogRecord);
end;

end.
