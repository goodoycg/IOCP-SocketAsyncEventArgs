unit BaseForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs;

type
  TFmBase = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  protected
    FParHandle: THandle;
    {* ÌáÊ¾¿ò *}
    procedure InfoBox(AText: string);
    procedure ErrorBox(AText: string);
    function AskBox(AText: string): Boolean;
  public
    constructor Create(AOwner: TComponent; AHandle: THandle = 0); reintroduce;
  end;

implementation

uses ClientDefineUnit;

{$R *.dfm}

function TFmBase.AskBox(AText: string): Boolean;
begin
  if MessageBox(Handle, PChar(AText), CAsk, MB_ICONQUESTION + MB_YESNO) = mrYes then
    Result := True
  else
    Result := False;
end;

procedure TFmBase.ErrorBox(AText: string);
begin
  MessageBox(Handle, PChar(AText), CError, MB_ICONERROR);
end;

procedure TFmBase.InfoBox(AText: string);
begin
  MessageBox(Handle, PChar(AText), CHint, MB_ICONINFORMATION);
end;

procedure TFmBase.FormCreate(Sender: TObject);
var
  NonClientMetrics: TNonClientMetrics;
begin
  NonClientMetrics.cbSize := SizeOf(TNonClientMetrics);
  SystemParametersInfo(SPI_GETNONCLIENTMETRICS, 0, @NonClientMetrics, 0);
  Self.Font.Handle := CreateFontIndirect(NonClientMetrics.lfMenuFont);
end;

constructor TFmBase.Create(AOwner: TComponent; AHandle: THandle);
begin
  FParHandle := AHandle;
  inherited Create(AOwner);
end;

end.
