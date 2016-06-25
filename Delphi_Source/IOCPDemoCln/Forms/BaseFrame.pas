unit BaseFrame;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, 
  Dialogs;

type
  TFamBase = class(TFrame)
  private
    { Private declarations }
  public
    { Public declarations }
    {* ÌáÊ¾¿ò *}
    procedure InfoBox(AText: string);
    procedure ErrorBox(AText: string);
    function AskBox(AText: string): Boolean;
  end;

implementation

uses ClientDefineUnit;

{$R *.dfm}

{ TFamBase }

function TFamBase.AskBox(AText: string): Boolean;
begin
  if MessageBox(Handle, PChar(AText), CAsk, MB_ICONQUESTION + MB_YESNO) = mrYes then
    Result := True
  else
    Result := False;
end;

procedure TFamBase.ErrorBox(AText: string);
begin
  MessageBox(Handle, PChar(AText), CError, MB_ICONERROR);
end;

procedure TFamBase.InfoBox(AText: string);
begin
  MessageBox(Handle, PChar(AText), CHint, MB_ICONINFORMATION);
end;

end.
