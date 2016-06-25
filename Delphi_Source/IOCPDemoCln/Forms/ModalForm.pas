unit ModalForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, BaseForm;

type
  TFmModal = class(TFmBase)
  private
    { Private declarations }
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { Public declarations }
  end;

implementation

{$R *.dfm}

{ TFmBase1 }

procedure TFmModal.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.WndParent := FParHandle;
end;

end.
