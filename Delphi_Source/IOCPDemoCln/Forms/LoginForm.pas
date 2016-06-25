unit LoginForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ModalForm;

type
  TFmLogin = class(TFmModal)
    pnl1: TPanel;
    pnl2: TPanel;
    btnLogin: TButton;
    btnCancel: TButton;
    lblServer: TLabel;
    lblPort: TLabel;
    edtServer: TEdit;
    edtPort: TEdit;
    procedure btnCancelClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
  private
    
  public
    { Public declarations }
    class function ShowForm(const AHandle: THandle): Boolean;
  end;

implementation

uses DataMgrCtr, BasisFunction, BaseClientSocket;

{$R *.dfm}

{ TFmLogin }

class function TFmLogin.ShowForm(const AHandle: THandle): Boolean;
var
  FmLogin: TFmLogin;
begin
  FmLogin := TFmLogin.Create(Application, AHandle);
  try
    if FmLogin.ShowModal = mrOk then
      Result := True
    else
      Result := False;
  finally
    FmLogin.Free;
  end;
end;

procedure TFmLogin.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFmLogin.btnLoginClick(Sender: TObject);
begin
  if GDataMgrCtr.Connect(edtServer.Text, StrToInt(edtPort.Text)) then
  begin
    ModalResult := mrOk;
    if GDataMgrCtr.Login('admin', 'admin') then
    begin
      ModalResult := mrOk;
    end
    else
    begin
      ErrorBox(GDataMgrCtr.ControlSocket.LastError);
    end;
  end
  else
  begin
    ErrorBox(GDataMgrCtr.ControlSocket.LastError);
  end;
end;

end.
