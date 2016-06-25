unit ConfigForm;

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, ExtCtrls, StdCtrls, Buttons,
  Spin, DefineUnit, ComCtrls;

type
  TFmConfig = class(TForm)
    pnl1: TPanel;
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    pnl2: TPanel;
    pgcClient: TPageControl;
    tsBasic: TTabSheet;
    tsDatabase: TTabSheet;
    tsLog: TTabSheet;
    lbl2: TLabel;
    edtDBServer: TEdit;
    lbl7: TLabel;
    edtDBPort: TEdit;
    lbl5: TLabel;
    cbbDBAuthentication: TComboBox;
    lbl4: TLabel;
    edtDBLoginName: TEdit;
    lbl6: TLabel;
    edtDBPassword: TEdit;
    lbl3: TLabel;
    cbbDBName: TComboBox;
    lbl13: TLabel;
    lbl12: TLabel;
    lbl11: TLabel;
    lbl8: TLabel;
    lbl10: TLabel;
    btnTestCon: TButton;
    lblFileDirectory: TLabel;
    lbl9: TLabel;
    edtFileDirectory: TEdit;
    btnSelectDirectory: TButton;
    tsSocket: TTabSheet;
    lblDefault: TLabel;
    lbl1: TLabel;
    seSocketPort: TSpinEdit;
    lblSocketTimeOut: TLabel;
    seSocketTimeOut: TSpinEdit;
    lblTransTimeOut: TLabel;
    seTransTimeOut: TSpinEdit;
    lbl14: TLabel;
    lbl15: TLabel;
    lblMaxSocketCount: TLabel;
    seMaxSocketCount: TSpinEdit;
    chkMaxWorkThreadCount: TLabel;
    chkMaxListenThreadCount: TLabel;
    seMaxWorkThreadCount: TSpinEdit;
    seMaxListenThreadCount: TSpinEdit;
    chkMinWorkThreadCount: TLabel;
    seMinWorkThreadCount: TSpinEdit;
    chkMinListenThreadCount: TLabel;
    seMinListenThreadCount: TSpinEdit;
    grpProtocol: TGroupBox;
    chkSQL: TCheckBox;
    chkUpload: TCheckBox;
    chkDownload: TCheckBox;
    chkControl: TCheckBox;
    chkLog: TCheckBox;
    cbbLogType: TComboBox;
    chkLogInfo: TCheckBox;
    chkLogSucc: TCheckBox;
    chkLogWarn: TCheckBox;
    chkLogError: TCheckBox;
    chkLogDebug: TCheckBox;
    chkConnectDB: TCheckBox;
    chkRemoteStream: TCheckBox;
    procedure seSocketPortChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure cbbDBNameDropDown(Sender: TObject);
    procedure btnTestConClick(Sender: TObject);
    procedure cbbDBAuthenticationChange(Sender: TObject);
    procedure btnSelectDirectoryClick(Sender: TObject);
    procedure cbbLogTypeChange(Sender: TObject);
  private
    FLoad: Boolean;
    procedure UpdateUIAsAuthentication;
  public
    procedure Load;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure SetCanEdit(const AValue: Boolean);
  end;

var
  FmConfig: TFmConfig;

implementation

uses OptionSet, Logger, DBConnect, BasisFunction;

{$R *.dfm}

procedure TFmConfig.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.WndParent := Application.MainForm.Handle;
end;

procedure TFmConfig.Load;
begin
  FLoad := True;
  try
    edtFileDirectory.Text := GIniOptions.FileDirestory;
    seMaxWorkThreadCount.Value := GIniOptions.MaxWorkThreadCount;
    seMinWorkThreadCount.Value := GIniOptions.MinWorkThreadCount;
    seMaxListenThreadCount.Value := GIniOptions.MaxListenThreadCount;
    seMinListenThreadCount.Value := GIniOptions.MinListenThreadCount;

    seSocketPort.Value := GIniOptions.SocketPort;
    seSocketTimeOut.Value := GIniOptions.SocketTimeOut;
    seTransTimeOut.Value := GIniOptions.TransTimeOut;
    seMaxSocketCount.Value := GIniOptions.MaxSocketCount;
    chkSQL.Checked := GIniOptions.SQLProtocol;
    chkUpload.Checked := GIniOptions.UploadProtocol;
    chkDownload.Checked := GIniOptions.DownloadProtocol;
    chkRemoteStream.Checked := GIniOptions.RemoteStreamProtocol;
    chkControl.Checked := GIniOptions.ControlProtocol;
    chkLog.Checked := GIniOptions.LogProtocol;

    edtDBServer.Text := GIniOptions.DBServer;
    cbbDBAuthentication.ItemIndex := Integer(GIniOptions.DBAuthentication);
    edtDBPort.Text := IntToStr(GIniOptions.DBPort);
    edtDBLoginName.Text := GIniOptions.DBLoginName;
    edtDBPassword.Text := GIniOptions.DBPassword;
    cbbDBName.Text := GIniOptions.DBName;
    chkConnectDB.Checked := GIniOptions.DBConnectDB;
    UpdateUIAsAuthentication;

    cbbLogType.ItemIndex := 0;
    cbbLogTypeChange(cbbLogType);
  finally
    FLoad := False;
    btnOk.Enabled := False;
  end;
end;

procedure TFmConfig.seSocketPortChange(Sender: TObject);
begin
  if not FLoad then
    btnOk.Enabled := True;
end;

procedure TFmConfig.FormCreate(Sender: TObject);
begin
  tsDatabase.Enabled := False;
  pgcClient.ActivePage := tsBasic;
  Load;
end;

procedure TFmConfig.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFmConfig.btnOkClick(Sender: TObject);

  function SetLogFilter: TLogFilter;
  begin
    Result[ltInfo] := chkLogInfo.Checked;
    Result[ltSucc] := chkLogSucc.Checked;
    Result[ltWarn] := chkLogWarn.Checked;
    Result[ltError] := chkLogError.Checked;
    Result[ltDebug] := chkLogDebug.Checked;
  end;
begin
  GIniOptions.BeginWrite;
  try
    GIniOptions.FileDirestory := edtFileDirectory.Text;
    GIniOptions.MaxWorkThreadCount := seMaxWorkThreadCount.Value;
    GIniOptions.MinWorkThreadCount := seMinWorkThreadCount.Value;
    GIniOptions.MaxListenThreadCount := seMaxListenThreadCount.Value;
    GIniOptions.MinListenThreadCount := seMinListenThreadCount.Value;
    
    GIniOptions.SocketPort := seSocketPort.Value;
    GIniOptions.SocketTimeOut := seSocketTimeOut.Value;
    GIniOptions.TransTimeOut := seTransTimeOut.Value;
    GIniOptions.MaxSocketCount := seMaxSocketCount.Value;
    GIniOptions.SQLProtocol := chkSQL.Checked;
    GIniOptions.UploadProtocol := chkUpload.Checked;
    GIniOptions.DownloadProtocol := chkDownload.Checked;
    GIniOptions.RemoteStreamProtocol := chkRemoteStream.Checked;
    GIniOptions.ControlProtocol := chkControl.Checked;
    GIniOptions.LogProtocol := chkLog.Checked;

    GIniOptions.DBServer := edtDBServer.Text;
    GIniOptions.DBAuthentication := TDBAuthentication(cbbDBAuthentication.ItemIndex);
    GIniOptions.DBPort := StrToInt(edtDBPort.Text);
    GIniOptions.DBLoginName := edtDBLoginName.Text;
    GIniOptions.DBPassword := edtDBPassword.Text;
    GIniOptions.DBName := cbbDBName.Text;
    GIniOptions.DBConnectDB := chkConnectDB.Checked;

    case cbbLogType.ItemIndex of
      0: GIniOptions.LogFile := SetLogFilter;
      1: GIniOptions.LogDesktop := SetLogFilter;
      2: GIniOptions.LogSocket := SetLogFilter;
    end;
  finally
    GIniOptions.EndWrite;
  end;
  WriteLogMsg(ltInfo, 'Change Option Set');
  ModalResult := mrOk;
end;

procedure TFmConfig.cbbDBNameDropDown(Sender: TObject);
begin
  GDBConnect.SetConConfig(edtDBServer.Text, cbbDBName.Text, edtDBLoginName.Text,
    edtDBPassword.Text, TDBAuthentication(cbbDBAuthentication.ItemIndex), StrToInt(edtDBPort.Text));
  GDBConnect.GetAllDBName(cbbDBName.Items);
end;

procedure TFmConfig.btnTestConClick(Sender: TObject);
begin
  GDBConnect.SetConConfig(edtDBServer.Text, cbbDBName.Text, edtDBLoginName.Text,
    edtDBPassword.Text, TDBAuthentication(cbbDBAuthentication.ItemIndex), StrToInt(edtDBPort.Text));
  try
    if GDBConnect.TestConnect then
      MessageBox(Handle, 'Connect DB Server Success', 'Hint', MB_ICONINFORMATION)
  except
    on E: Exception do
    begin
      MessageBox(Handle, PChar('Connect DB Server Error: ' + E.Message), 'Error', MB_ICONERROR);
    end;
  end;
end;

procedure TFmConfig.cbbDBAuthenticationChange(Sender: TObject);
begin
  seSocketPortChange(Sender);
  UpdateUIAsAuthentication;
end;

procedure TFmConfig.UpdateUIAsAuthentication;
begin
  if cbbDBAuthentication.ItemIndex = 0 then
  begin
    edtDBLoginName.Enabled := False;
    edtDBPassword.Enabled := False;
  end
  else
  begin
    edtDBLoginName.Enabled := True;
    edtDBPassword.Enabled := True;
  end;
end;

procedure TFmConfig.btnSelectDirectoryClick(Sender: TObject);
var
  sPath: string;
begin
  sPath := edtFileDirectory.Text;
  if SelectDirectoryEx(sPath, 'Select File Directory', '') then
  begin
    edtFileDirectory.Text := sPath;
  end;
end;

procedure TFmConfig.SetCanEdit(const AValue: Boolean);
begin
  tsBasic.Enabled := AValue;
  //tsDatabase.Enabled := AValue;
  tsLog.Enabled := AValue;
end;

procedure TFmConfig.cbbLogTypeChange(Sender: TObject);

  procedure LoadLogFilter(const AValue: TLogFilter);
  begin
    chkLogInfo.Checked := AValue[ltInfo];
    chkLogSucc.Checked := AValue[ltSucc];
    chkLogWarn.Checked := AValue[ltWarn];
    chkLogError.Checked := AValue[ltError];
    chkLogDebug.Checked := AValue[ltDebug];
  end;
begin
  case cbbLogType.ItemIndex of
    0: LoadLogFilter(GIniOptions.LogFile);
    1: LoadLogFilter(GIniOptions.LogDesktop);
    2: LoadLogFilter(GIniOptions.LogSocket);
  end;
end;

end.
