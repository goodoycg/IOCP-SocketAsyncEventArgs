unit SQLFrame;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, BaseFrame, ToolWin, ComCtrls, ImgList, ExtCtrls, StdCtrls,
  Grids, DBGrids, DB, ADODB, Math, DateUtils;

type
  TFamSQL = class(TFamBase)
    ilTool: TImageList;
    tlbSQL: TToolBar;
    btnSQLOpen: TToolButton;
    btnSQLExec: TToolButton;
    btnBeginTrans: TToolButton;
    btnCommitTrans: TToolButton;
    btnRollbackTrans: TToolButton;
    mmoSQL: TMemo;
    splTop: TSplitter;
    grdSQL: TDBGrid;
    statSQL: TStatusBar;
    dsSQL: TDataSource;
    adsSQL: TADODataSet;
    procedure btnSQLOpenClick(Sender: TObject);
    procedure btnSQLExecClick(Sender: TObject);
    procedure btnBeginTransClick(Sender: TObject);
    procedure btnCommitTransClick(Sender: TObject);
    procedure btnRollbackTransClick(Sender: TObject);
  private
    { Private declarations }
    procedure UpdateProgress(const ATotalByte, ARecvByte: Int64);
    procedure UpdateSpeed(const ATotalByte: Int64; const ATotalTimeMS: Int64);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses DataMgrCtr, BasisFunction;

{$R *.dfm}

procedure TFamSQL.btnSQLOpenClick(Sender: TObject);
var
  sSQLFile: string;
  FileStream: TFileStream;
  StartTime: TDateTime;
begin
  inherited;
  StartTime := Now;
  Screen.Cursor := crHourGlass;
  try
    sSQLFile := GDataMgrCtr.GetTmpFile('.xml');
    FileStream := TFileStream.Create(sSQLFile, fmCreate or fmOpenReadWrite);
    try
      if not GDataMgrCtr.SQLSocket.SQLOpen(mmoSQL.Text, FileStream) then
      begin
        ErrorBox(GDataMgrCtr.SQLSocket.LastError);
        Exit;
      end;
    finally
      FileStream.Free;
    end;
    adsSQL.Close;
    adsSQL.LoadFromFile(sSQLFile);
    statSQL.Panels[3].Text := IntToStr(MilliSecondsBetween(Now, StartTime)) + 'MS';
    statSQL.Panels[2].Text := 'Rows: ' + IntToStr(adsSQL.RecordCount);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFamSQL.btnSQLExecClick(Sender: TObject);
var
  iEffectRow: Integer;
  StartTime: TDateTime;
begin
  inherited;
  StartTime := Now;
  Screen.Cursor := crHourGlass;
  try
    if not GDataMgrCtr.SQLSocket.SQLExec(mmoSQL.Text, iEffectRow) then
    begin
      ErrorBox(GDataMgrCtr.SQLSocket.LastError);
      Exit;
    end;
    statSQL.Panels[3].Text := IntToStr(MilliSecondsBetween(Now, StartTime)) + 'MS';
    statSQL.Panels[2].Text := 'Effect Rows: ' + IntToStr(iEffectRow);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFamSQL.btnBeginTransClick(Sender: TObject);
begin
  inherited;
  Screen.Cursor := crHourGlass;
  try
    if not GDataMgrCtr.SQLSocket.BeginTrans then
    begin
      ErrorBox(GDataMgrCtr.SQLSocket.LastError);
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFamSQL.btnCommitTransClick(Sender: TObject);
begin
  inherited;
  Screen.Cursor := crHourGlass;
  try
    if not GDataMgrCtr.SQLSocket.CommitTrans then
    begin
      ErrorBox(GDataMgrCtr.SQLSocket.LastError);
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFamSQL.btnRollbackTransClick(Sender: TObject);
begin
  inherited;
  Screen.Cursor := crHourGlass;
  try
    if not GDataMgrCtr.SQLSocket.RollbackTrans then
    begin
      ErrorBox(GDataMgrCtr.SQLSocket.LastError);
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFamSQL.UpdateProgress(const ATotalByte, ARecvByte: Int64);
begin
  if ATotalByte > 0 then
    statSQL.Panels[0].Text := FixDouble(2, ARecvByte / ATotalByte * 100) + '%';
end;

procedure TFamSQL.UpdateSpeed(const ATotalByte, ATotalTimeMS: Int64);
begin
  if ATotalTimeMS > 0 then
    statSQL.Panels[1].Text := GetSpeedDisplay(ATotalByte / ATotalTimeMS * 1000);
end;

constructor TFamSQL.Create(AOwner: TComponent);
begin
  inherited;
  GDataMgrCtr.SQLSocket.OnProgress := UpdateProgress;
  GDataMgrCtr.SQLSocket.OnSpeed := UpdateSpeed;
end;

end.
