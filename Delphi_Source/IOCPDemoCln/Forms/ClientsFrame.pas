unit ClientsFrame;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, BaseFrame, ComCtrls, ImgList, ToolWin, Types, VirtualTrees;

type
  TClients = record
    ServerIP: string;
    ClientIP: string;
    SocketType: string;
    UserName: string;
    ConnectTime: string;
    ActiveTime: string;
  end;
  TDynClients = array of TClients;

  TFamClients = class(TFamBase)
    tlbLog: TToolBar;
    ilTool: TImageList;
    vsttree: TVirtualStringTree;
    btnDisconnect: TToolButton;
    procedure vsttreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
  private
    { Private declarations }
    FDynClients: TDynClients;
  public
    { Public declarations }
    procedure DoClients(AItems: TStrings);
  end;

implementation

uses BasisFunction;

{$R *.dfm}

{ TFamTasks }

procedure TFamClients.DoClients(AItems: TStrings);
var
  i, iCount: Integer;
  DynStr: TStringDynArray;
  Node, PreNode: PVirtualNode;

  function GetText(const AIndex: Integer): string;
  begin
    if (AIndex >= Low(DynStr)) and (AIndex <= High(DynStr)) then
      Result := DynStr[AIndex]
    else
      Result := '';
  end;
begin
  vsttree.BeginUpdate;
  try
    SetLength(FDynClients, AItems.Count);
    for i := 0 to AItems.Count - 1 do
    begin
      DynStr := SplitString(AItems[i], #9);
      FDynClients[i].ServerIP := GetText(0);
      FDynClients[i].ClientIP := GetText(1);
      FDynClients[i].SocketType := GetText(2);
      FDynClients[i].UserName := GetText(3);
      FDynClients[i].ConnectTime := GetText(4);
      FDynClients[i].ActiveTime := GetText(5);
    end;
    iCount := vsttree.TotalCount;
    for i := iCount to High(FDynClients) do //Ìí¼Ó
      vsttree.AddChild(nil, nil);
    Node := vsttree.GetLast();
    if Node <> nil then
    begin
      iCount := vsttree.TotalCount;
      for i := iCount - 1 downto Length(FDynClients) do //É¾³ý
      begin
        PreNode := Node.PrevSibling;
        vsttree.DeleteNode(Node);
        Node := PreNode;
        if Node = nil then Break;
      end;
    end;
  finally
    vsttree.EndUpdate;
  end;
end;

procedure TFamClients.vsttreeGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
begin
  inherited;
  if Node.Index < Cardinal(Length(FDynClients)) then
  begin
    case Column of
      0: CellText := IntToStr(Node.Index + 1);
      1: CellText := FDynClients[Node.Index].ServerIP;
      2: CellText := FDynClients[Node.Index].ClientIP;
      3: CellText := FDynClients[Node.Index].SocketType;
      4: CellText := FDynClients[Node.Index].UserName;
      5: CellText := FDynClients[Node.Index].ConnectTime;
      6: CellText := FDynClients[Node.Index].ActiveTime;
    end;
  end
  else
    CellText := '';
end;

end.
