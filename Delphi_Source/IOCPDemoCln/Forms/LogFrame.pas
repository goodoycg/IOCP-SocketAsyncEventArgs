unit LogFrame;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, BaseFrame, ToolWin, ComCtrls, StdCtrls, ImgList;

type
  TFamLog = class(TFamBase)
    tlbLog: TToolBar;
    redtLog: TRichEdit;
    ilTool: TImageList;
    btnSave: TToolButton;
    btnClear: TToolButton;
    btnCopy: TToolButton;
    dlgSave: TSaveDialog;
    procedure btnSaveClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
  private
    { Private declarations }
  public
    procedure DoLog(const ALogMessage: string);
  end;

  TColorFilter = record
    Text: string;
    Color: TColor;
  end;

implementation

const
  CDefaultColor: array[0..6] of TColorFilter = (
    (Text: ';error;'; Color: clRed),
    (Text: ';failure;'; Color: clRed),
    (Text: ';bad;'; Color: clRed),
    (Text: ';drop;'; Color: clRed),
    (Text: ';poor;'; Color: clFuchsia),
    (Text: ';warn;'; Color: clFuchsia),
    (Text: ';debug;'; Color: clBlue)
  );

{$R *.dfm}

{ TFamLog }

procedure TFamLog.DoLog(const ALogMessage: string);
var
  Color: TColor;
  i: Integer;
begin
  if redtLog.Lines.Count > 5120 then
    redtLog.Lines.Clear;
  Color := redtLog.Font.Color;
  for i := Low(CDefaultColor) to High(CDefaultColor) do
  begin
    if Pos(CDefaultColor[i].Text, LowerCase(ALogMessage)) > 0 then
    begin
      Color := CDefaultColor[i].Color;
      Break;
    end;
  end;
  redtLog.SelAttributes.Color := Color;
  redtLog.SelStart := -1;//定位到最后；
  SendMessage(redtLog.Handle, EM_REPLACESEL, 0, LongInt(PChar(ALogMessage)));
  SendMessage(redtLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);//把滚动条定位到文本最底；
end;

procedure TFamLog.btnSaveClick(Sender: TObject);
var
  sFileName: string;
begin
  inherited;
  if dlgSave.Execute then
  begin
    sFileName := dlgSave.FileName;
    if not SameText(ExtractFileExt(sFileName), '.rtf') then
      sFileName := sFileName + '.rtf';
    redtLog.Lines.SaveToFile(sFileName);
  end;
end;

procedure TFamLog.btnCopyClick(Sender: TObject);
begin
  inherited;
  redtLog.SelectAll;
  redtLog.CopyToClipboard;
end;

procedure TFamLog.btnClearClick(Sender: TObject);
begin
  inherited;
  redtLog.Lines.Clear;
end;

end.
