unit MsgDecodeVirtualTree;

interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, StdCtrls,
  CommCtrl, VirtualTrees, XMLDoc, XMLIntf, Math, Dialogs, Variants, Clipbrd;

type

  TSearchOptions = record
    Casesensitive: Boolean;
    WholeWordsOnly: Boolean;
    Backward: Boolean;
		GlobalScope: Boolean;
    FromCursor: Boolean;
  end;

	TBeforeSearchEvent = procedure(Sender: TObject; var SearchStr: String;
  	var Options: TSearchOptions; var Handled: Boolean;
    const ShowSearchSetting: Boolean) of Object;
	TBeforeExportEvent = procedure(Sender: TObject; var ExportFileName: String) of Object;

  TMsgDecodeVirtualTree = class(TCustomVirtualStringTree)
	private
    FSearchNode: PVirtualNode;
    FXmlDoc: IXMLDocument;
    FTextFile: TStringList; //CDJ110702 Export text File
    FExportType: Integer;   //CDJ110702 1: xml; 2: text
    FCurSourXml: string;    //CDJ110702
    FCurTitle: string;
    FOnBeforeSearch: TBeforeSearchEvent;
    FOnBeforeExport: TBeforeExportEvent;
    FMainColumeAddDelt: Integer;
    function GetOptions: TStringTreeOptions;
    procedure SetOptions(const Value: TStringTreeOptions);
    function GetXmlSour: String;
  protected
    function GetOptionsClass: TTreeOptionsClass; override;
    procedure GetTextEvent(Sender: TBaseVirtualTree;
    	Node: PVirtualNode; Column: TColumnIndex;
    	TextType: TVSTTextType; var CellText: WideString);
    procedure PaintTextEvent(Sender: TBaseVirtualTree;
	  	const TargetCanvas: TCanvas; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType);
    procedure DoImportXml(const Title: string; XmlDoc: IXMLDocument);
    procedure DoTextDrawing(var PaintInfo: TVTPaintInfo; Text: WideString;
    	CellRect: TRect; DrawFormat: Cardinal); override;
    procedure Paint; override;
    function GetSelectNodeText: string;                             //CDJ110702
    procedure DoCopyNodeTextToClipboard(const ExportStr: string);   //CDJ110702
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure FindText(const SearchStr: String; const SrchOptions: TSearchOptions);
    procedure ExportXml(ParentNode: IXMLNode);                  overload;
    procedure ExportXml(const SourXml, Title: string;	ParentNode: IXMLNode); overload;
    function ExportText(const SourXml, Title: String): String;
    procedure CopyNodeTextToClipboard;   //CDJ110702

    //NetFlag: 'G' GSM, 'C' CDMA, 'W' WCDMA, 'T' TD-SCDMA
    procedure ImportXml(const SourXml, Title: string; const NetFlag: Char);
    function GetLastSelected: PVirtualNode;
    procedure CustomSearch;
    procedure SearchAgain;
    procedure ExportContext;
    property Canvas;
    property ExportType: Integer read FExportType write FExportType;   //CDJ110702  1: XML, 2: Text
  published
    property Action;
    property Align;
    property Alignment;
    property Anchors;
    property AnimationDuration;
    property AutoExpandDelay;
    property AutoScrollDelay;
    property AutoScrollInterval;
    property Background;
    property BackgroundOffsetX;
    property BackgroundOffsetY;
    property BiDiMode;
    property BevelEdges;
    property BevelInner;
    property BevelOuter;
    property BevelKind;
    property BevelWidth;
    property BorderStyle;
    property ButtonFillMode;
    property ButtonStyle;
    property BorderWidth;
    property ChangeDelay;
    property CheckImageKind;
    property ClipboardFormats;
    property Color;
    property Colors;
    property Constraints;
    property Ctl3D;
    property CustomCheckImages;
    property DefaultNodeHeight;
    property DefaultPasteMode;
    property DefaultText;
    property DragCursor;
    property DragHeight;
    property DragKind;
    property DragImageKind;
    property DragMode;
    property DragOperations;
    property DragType;
    property DragWidth;
    property DrawSelectionMode;
    property EditDelay;
    property Enabled;
    property Font;
    property Header;
    property HintAnimation;
    property HintMode;
    property HotCursor;
    property Images;
    property IncrementalSearch;
    property IncrementalSearchDirection;
    property IncrementalSearchStart;
    property IncrementalSearchTimeout;
    property Indent;
    property LineMode;
    property LineStyle;
    property Margin;
    property NodeAlignment;
    property NodeDataSize;
    property ParentBiDiMode;
    property ParentColor default False;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RootNodeCount;
    property ScrollBarOptions;
    property SelectionBlendFactor;
    property SelectionCurveRadius;
    property ShowHint;
    property StateImages;
    property TabOrder;
    property TabStop default True;
    property TextMargin;
    property TreeOptions: TStringTreeOptions read GetOptions write SetOptions;
		property XmlSour: String read GetXmlSour;
    property Visible;
    property WantTabs;

    property OnAdvancedHeaderDraw;
    property OnAfterCellPaint;
    property OnAfterItemErase;
    property OnAfterItemPaint;
    property OnAfterPaint;
    property OnBeforeCellPaint;
    property OnBeforeItemErase;
    property OnBeforeItemPaint;
    property OnBeforePaint;
    property OnChange;
    property OnChecked;
    property OnChecking;
    property OnClick;
    property OnCollapsed;
    property OnCollapsing;
    property OnColumnClick;
    property OnColumnDblClick;
    property OnColumnResize;
    property OnCompareNodes;
    {$ifdef COMPILER_5_UP}
//    property OnContextPopup;
    {$endif COMPILER_5_UP}
    property OnCreateDataObject;
    property OnCreateDragManager;
    property OnCreateEditor;
    property OnDblClick;
    property OnDragAllowed;
    property OnDragOver;
    property OnDragDrop;
    property OnEditCancelled;
    property OnEdited;
    property OnEditing;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnExpanded;
    property OnExpanding;
    property OnFocusChanged;
    property OnFocusChanging;
    property OnFreeNode;
    property OnGetCellIsEmpty;
    property OnGetCursor;
    property OnGetHeaderCursor;
//    property OnGetText;
//    property OnPaintText;
    property OnGetHelpContext;
    property OnGetImageIndex;
    property OnGetImageIndexEx;
    property OnGetHint;
    property OnGetLineStyle;
    property OnGetNodeDataSize;
    property OnGetPopupMenu;
    property OnGetUserClipboardFormats;
    property OnHeaderClick;
    property OnHeaderDblClick;
    property OnHeaderDragged;
    property OnHeaderDraggedOut;
    property OnHeaderDragging;
    property OnHeaderDraw;
    property OnHeaderDrawQueryElements;
    property OnHeaderMouseDown;
    property OnHeaderMouseMove;
    property OnHeaderMouseUp;
    property OnHotChange;
    property OnIncrementalSearch;
    property OnInitChildren;
    property OnInitNode;
    property OnKeyAction;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnLoadNode;
    property OnMeasureItem;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
//    property OnNewText;
    property OnNodeCopied;
    property OnNodeCopying;
    property OnNodeMoved;
    property OnNodeMoving;
    property OnPaintBackground;
    property OnRenderOLEData;
    property OnResetNode;
    property OnResize;
    property OnSaveNode;
    property OnScroll;
    property OnShortenString;
    property OnShowScrollbar;
    property OnStartDock;
    property OnStartDrag;
    property OnStateChange;
    property OnStructureChange;
    property OnUpdating;
    property OnBeforeSearch: TBeforeSearchEvent read FOnBeforeSearch write FOnBeforeSearch;
    property OnBeforeExport: TBeforeExportEvent read FOnBeforeExport write FOnBeforeExport;
  end;

  function GainLastSelected(Tree: TBaseVirtualTree): PVirtualNode;

implementation

function GainLastSelected(Tree: TBaseVirtualTree): PVirtualNode;
	procedure Last(Node: PVirtualNode);
  begin
    if not Assigned(Node) then Exit;
    if Tree.Selected[Node] then
    begin
      Result := Node; Exit;
    end;
    Node := Node.LastChild;
    while Assigned(Node) do
    begin
      Last(Node);
      if Assigned(Result) then Exit;
      Node := Node.PrevSibling;
    end;
  end;
begin
	Result := nil;
  Last(Tree.GetLastChild(Tree.RootNode));
end;

{ TMsgDecodeVirtualTree }

constructor TMsgDecodeVirtualTree.Create(AOwner: TComponent);
begin
  inherited;
	OnGetText := GetTextEvent;
  OnPaintText := PaintTextEvent;
  NodeDataSize := 4;
  FXmlDoc := NewXMLDocument;
  FTextFile := TStringList.Create;
  Header.MainColumn := -1;
  Header.AutoSizeIndex := -1;
  Header.Options := Header.Options + [hoVisible, hoAutoResize];
  TreeOptions.SelectionOptions := TreeOptions.SelectionOptions + [toMultiSelect];
end;

destructor TMsgDecodeVirtualTree.Destroy;
begin
  if Assigned(FXmlDoc) then
  begin
    FXmlDoc._Release;
    FXmlDoc := nil;
  end;
  if Assigned(FTextFile) then
  begin
    FTextFile.Free;
    FTextFile := nil;
  end;
  inherited;
end;

procedure TMsgDecodeVirtualTree.ExportXml(ParentNode: IXMLNode);
begin
	ParentNode.ChildNodes.Add(FXmlDoc.DocumentElement.CloneNode(True));
end;

var
  EDoc: IXMLDocument = nil;

procedure TMsgDecodeVirtualTree.ExportXml(const SourXml, Title: string;
	ParentNode: IXMLNode);
begin
	if not Assigned(EDoc) then
  	EDoc := LoadXMLData(SourXml)
  else EDoc.LoadFromXML(SourXml);
  DoImportXml(Title, EDoc);
  ParentNode.ChildNodes.Add(EDoc.DocumentElement.CloneNode(True));
  EDoc.ChildNodes.Clear;
end;

function TMsgDecodeVirtualTree.ExportText(const SourXml, Title: String): String;
  procedure DoExportText(Level: Integer; Node: IXmlNode);
  var
    iCount: Integer;
  begin
    if Result = '' then
      Result := Title//Node.Attributes['Title']
    else
      if Node.NodeType = ntText then
        Result := Result +': ' + VarToStrDef(Node.NodeValue, '')
      else
        Result := Result + #$D#$A + StringOfChar(' ', Level * 2) + Node.NodeName;

    for iCount := 0 to Node.ChildNodes.Count - 1 do
    begin
      DoExportText(Level + 1, Node.ChildNodes.Get(iCount));
    end;
  end;

var
  sXML: string;
begin
  sXML := StringReplace(SourXml, #$9, '', [rfReplaceAll]);
  sXML := StringReplace(sXML   , #$D, '', [rfReplaceAll]);
  sXML := StringReplace(sXML   , #$A, '', [rfReplaceAll]);
  if not Assigned(EDoc) then
    EDoc := LoadXMLData(sXML)
  else EDoc.LoadFromXML(sXML);
  //DoImportXml(Title, EDoc);
  Result := '';
  DoExportText(1, EDoc.DocumentElement);
  EDoc.ChildNodes.Clear;
  Result := Format('"%s"', [Result]);
end;

function FindByTagName(const TagName: String; NodeList: IXMLNodeList): IXMLNode;
var
  iCount: Integer;
begin
  for iCount := 0 to Pred(NodeList.Count) do
  begin
    Result := NodeList.Get(iCount);
    if Result.NodeType = ntText then
    begin
      if SameText(VarToStrDef(Result.NodeValue, ''), TagName) then
      	Exit;
    end else
      if SameText(Result.NodeName, TagName) then
        Exit;
  end;
  Result := nil;
end;

procedure TMsgDecodeVirtualTree.DoImportXml(const Title: string;
	XmlDoc: IXMLDocument);
var
	Node, TitleNode: IXMLNode;
  iCount: Integer;
  ValueList: TStrings;

  procedure DuplicateNode(DestNodeList: IXMLNodeList; SourNode: IXMLNode);
  var
    iCount: Integer;
  begin
  	if not Assigned(SourNode) then Exit;

    if SourNode.NodeType = ntText then
    begin
      if (Pos(#$A, SourNode.Text) > 0) or
         (Pos(#$D, SourNode.Text) > 0) or
         (Pos(#$9, SourNode.Text) > 0) then
      begin
        ValueList.Text := StringReplace(Trim(SourNode.Text), #$9, '', [rfReplaceAll]);
        ValueList.BeginUpdate;
        try
          for iCount := Pred(ValueList.Count) downto 0 do
          if Trim(ValueList[iCount]) = '' then
          	ValueList.Delete(iCount);
        finally
          ValueList.EndUpdate;
        end;
        for iCount := 0 to Pred(ValueList.Count) do
        begin
          if Trim(ValueList[iCount]) <> '' then
            DestNodeList.Add(XmlDoc.CreateNode(ValueList[iCount], ntText));
        end;
      end else DestNodeList.Add(SourNode.CloneNode(False));
    end else
    begin
      DestNodeList.Add(SourNode.CloneNode(False));
      with DestNodeList.Last do
    	for iCount := 0 to Pred(SourNode.ChildNodes.Count) do
        DuplicateNode(ChildNodes, SourNode.ChildNodes.Get(iCount));
    end;
  end;
begin
  Node := XMLDoc.DocumentElement;
  if Assigned(Node) then
  begin
    TitleNode := XmlDoc.CreateElement('Message', '');
    TitleNode.Attributes['Title'] := Title;
    ValueList := TStringList.Create;
    try
      for iCount := 0 to Pred(Node.ChildNodes.Count) do
      begin
        DuplicateNode(TitleNode.ChildNodes, Node.ChildNodes.Get(iCount));
      end;
    finally
      ValueList.Free;
    end;
    XmlDoc.ChildNodes.Clear;
    XmlDoc.ChildNodes.Add(TitleNode);
	end;
end;
{
procedure TMsgDecodeVirtualTree.DoImportXml(const Title: string;
	XmlDoc: IXMLDocument);
var
	Node, TitleNode: IXMLNode;
  iCount, iIndex: Integer;
  ValueList: TStrings;
begin
  Node := FindByTagName('content', XmlDoc.DocumentElement.ChildNodes);
  if Assigned(Node) then
  begin
    TitleNode := XmlDoc.CreateElement('Message', '');
    TitleNode.Attributes['Title'] := Title;
    if Node.ChildNodes.Count = 1 then
    begin
      Node := Node.ChildNodes.Get(0); //para
      if Node.HasChildNodes then
      	Node := Node.ChildNodes.Get(0) //unfmt
      else Exit;
      if Node.HasChildNodes then
      	Node := Node.ChildNodes.Get(0) //
      else Exit;
      if Node.NodeType = ntText then
      begin
        if (Pos(#$A, Node.Text) > 0) or
           (Pos(#$D, Node.Text) > 0) or
           (Pos(#$9, Node.Text) > 0) then
        begin
          FStandard := False;
          ValueList := TStringList.Create;
          try
            ValueList.Text := StringReplace(Node.Text, #$9, '', [rfReplaceAll]);
            iCount := IfThen(ValueList.Count > 1, 1, 0);
            for iCount := iCount to Pred(ValueList.Count) do
            if ValueList[iCount] <> '' then
            begin
	            //TitleNode.ChildNodes.Add(XmlDoc.CreateElement(ValueList[iCount], ''));
              TitleNode.ChildNodes.Add(XmlDoc.CreateNode(ValueList[iCount], ntText));
            end;
          finally
            ValueList.Free;
          end;
        end else
        begin
          FStandard := True;
	      	TitleNode.ChildNodes.Add(Node.CloneNode(True));
        end;
      end else
      begin
        FStandard := True;
      	for iCount := 0 to Pred(Node.ChildNodes.Count) do
          TitleNode.ChildNodes.Add(Node.ChildNodes.Get(iCount).CloneNode(True));
      end;
    end else
    begin
      FStandard := True;
      for iCount := 0 to Node.ChildNodes.Count - 1 do
      begin
        with Node.ChildNodes.Get(iCount) do
        if not SameText(NodeName, 'para') then
        begin
          for iIndex := 0 to Pred(ChildNodes.Count) do
          	TitleNode.ChildNodes.Add(ChildNodes.Get(iIndex).CloneNode(True));
        end;
      end;
    end;
    XmlDoc.ChildNodes.Clear;
    XmlDoc.ChildNodes.Add(TitleNode);
	end;
end;
}
procedure TMsgDecodeVirtualTree.ImportXml(const SourXml, Title: string;
	const NetFlag: Char);

  procedure InitialHeader;
  begin
    if UpCase(NetFlag) = 'T' then
    begin
      if Header.Columns.Count <> 2 then
      begin
        Header.MainColumn := 0;
        Header.AutoSizeIndex := 1;
        Header.Columns.Clear;
        Header.Columns.Add;
        Header.Columns.Add;
        Header.Columns[0].Width := Self.ClientWidth div 2;
        Header.Columns[1].Width := Self.ClientWidth div 2;
      end;
    end else//'G', 'C', 'W'
      if Header.Columns.Count <> 1 then
      begin
        Header.Columns.Clear;
        Header.Columns.Add;
        Header.MainColumn := -1;
        Header.AutoSizeIndex := 0;
      end;
  end;

  procedure FillTree(Node: PVirtualNode; XmlNode: IXMLNode);
  begin
  	Node := AddChild(Node, Pointer(XmlNode));
    if XmlNode.HasChildNodes and (not XmlNode.IsTextElement or
                                 (XmlNode = FXmlDoc.DocumentElement)) then
    begin
      XmlNode := XmlNode.ChildNodes.Get(0);
      repeat
        FillTree(Node, XmlNode);
        XmlNode := XmlNode.NextSibling;
      until not Assigned(XmlNode);
      Expanded[Node] := True;
    end;
  end;
begin
  Self.BeginUpdate;
  try
    Self.Clear;
    FXmlDoc.LoadFromXML(SourXml);
    InitialHeader;
    DoImportXml(Title, FXmlDoc);
	  FillTree(RootNode, FXmlDoc.DocumentElement);
    FCurSourXml := SourXml;    //CDJ110702
    FCurTitle := Title;
  finally
    Self.EndUpdate;
  end;
end;


procedure TMsgDecodeVirtualTree.FindText(const SearchStr: String;
	const SrchOptions: TSearchOptions);
var
	TmpNode, Node, PreSelNode: PVirtualNode;

	procedure Find(const Node: PVirtualNode);
  begin
    if SrchOptions.GlobalScope or Selected[Node] then
    begin
      if SrchOptions.WholeWordsOnly then
      begin
        if SrchOptions.Casesensitive then
        begin
          if ((AnsiCompareStr(Text[Node, 0], SearchStr) = 0) or
              (AnsiCompareStr(Text[Node, 1], SearchStr) = 0)) and
             (PreSelNode <> Node) then
          begin
            FSearchNode := Node;
            ScrollIntoView(Node, True);
          end;
        end else
        begin
          if (AnsiSameText(Text[Node, 0], SearchStr) or
              AnsiSameText(Text[Node, 1], SearchStr)) and
             (PreSelNode <> Node) then
          begin
            FSearchNode := Node;
            ScrollIntoView(Node, True);
          end;
        end;
      end else
      begin
				if SrchOptions.Casesensitive then
        begin
          if ((AnsiPos(SearchStr, Text[Node, 0]) > 0) or
              (AnsiPos(SearchStr, Text[Node, 1]) > 0)) and
             (PreSelNode <> Node) then
          begin
            FSearchNode := Node;
            ScrollIntoView(Node, True);
          end;
        end else
        begin
          if ((AnsiPos(AnsiUpperCase(SearchStr), AnsiUpperCase(Text[Node, 0])) > 0) or
              (AnsiPos(AnsiUpperCase(SearchStr), AnsiUpperCase(Text[Node, 1])) > 0)) and
             (PreSelNode <> Node) then
          begin
            FSearchNode := Node;;
            ScrollIntoView(Node, True);
          end;
        end;
      end;
    end;
  end;
begin
  if SearchStr = '' then Exit;
  PreSelNode := nil;
  if SrchOptions.Backward then
  begin
    if SrchOptions.FromCursor then
    begin
      if not Assigned(FSearchNode) then
      begin
	      TmpNode := GetLastSelected;
        TmpNode := GetNext(TmpNode);
      end else TmpNode := FSearchNode;

      if Assigned(TmpNode) then
        PreSelNode := TmpNode
      else
        TmpNode := GetLast(RootNode);
    end else
      TmpNode := GetLast(RootNode);
  end else
  begin
    if SrchOptions.FromCursor then
    begin
      if not Assigned(FSearchNode) then
      begin
      	TmpNode := GetFirstSelected;
        TmpNode := GetPrevious(TmpNode);
      end else TmpNode := FSearchNode;

      if Assigned(TmpNode) then
        PreSelNode := TmpNode
      else
      	TmpNode := GetFirst
    end else
    	TmpNode := GetFirst;
  end;

  if not Assigned(TmpNode) then Exit;
  FSearchNode := nil;

  repeat
    Node := TmpNode;
  	Find(Node);
    if Assigned(FSearchNode) then Break;

    if SrchOptions.Backward then
      TmpNode := Self.GetPrevious(Node)
    else
      TmpNode := Self.GetNext(Node);
  until not Assigned(TmpNode) or (TmpNode = Node) or (TmpNode = RootNode);

  if not Assigned(FSearchNode) then
	  MessageDlg(Format('Search string ''%s'' not found!', [SearchStr]), mtInformation	, [mbOk], 0)
  else Refresh;
end;

function TMsgDecodeVirtualTree.GetOptions: TStringTreeOptions;
begin
  Result := FOptions as TStringTreeOptions;
end;

function TMsgDecodeVirtualTree.GetOptionsClass: TTreeOptionsClass;
begin
  Result := TStringTreeOptions;
end;

procedure TMsgDecodeVirtualTree.GetTextEvent(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: WideString);
begin
  CellText := '';
  if (TextType = ttNormal) then
  with IXMLNode(Sender.GetNodeData(Node)^) do
  begin
		case Column of
    0:
      begin
        if Header.Columns.Count = 1 then
        begin
          if Node.Parent = RootNode then
						CellText := Attributes['Title']
          else if NodeType = ntText then
            CellText := VarToStrDef(NodeValue, '')
          else if IsTextElement then
            CellText := NodeName + ': ' + VarToStrDef(NodeValue, '')
          else CellText := NodeName;
        end else
        begin
          if NodeType = ntText then
            CellText := VarToStrDef(NodeValue, '')
          else CellText := NodeName;
        end;
      end;
    1:
      begin
        if Node.Parent = RootNode then
          CellText := Attributes['Title']
        else
          if IsTextElement then
            CellText := VarToStrDef(NodeValue, '')
      end;
    end;
    {
    case Column of
    0:
      begin
        if Header.Columns.Count = 1 then
        begin
          if IsTextElement then
          begin
            if FStandard then
              CellText := NodeName + ': ' + VarToStrDef(NodeValue, '')
            else CellText := VarToStrDef(NodeValue, '');
          end else
          begin
            if NodeType = ntText then
              CellText := VarToStrDef(NodeValue, '')
            else
              if Sender.GetNodeLevel(Node) = 0 then
                CellText := Attributes['Title']
              else CellText := NodeName;
          end;
        end else
        begin
          if NodeType = ntText then
            CellText := VarToStrDef(NodeValue, '')
          else CellText := NodeName;
        end;
      end;
    1:
      begin
        if Sender.GetNodeLevel(Node) = 0 then
          CellText := Attributes['Title']
        else
          if IsTextElement then
            CellText := VarToStrDef(NodeValue, '')
      end;
    end;
    }
  end;
end;

function TMsgDecodeVirtualTree.GetXmlSour: String;
begin
  FXmlDoc.SaveToXML(Result)
end;

procedure TMsgDecodeVirtualTree.PaintTextEvent(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);
begin
  if (Column = 1) or
     ((Header.Columns.Count = 1) and
      (Node.ChildCount = 0)) then
    TargetCanvas.Font.Color := clBlue;
  if (FSearchNode = Node) then
    TargetCanvas.Font.Color := clRed
end;

procedure TMsgDecodeVirtualTree.SetOptions(
  const Value: TStringTreeOptions);
begin
  FOptions.Assign(Value);
end;

function TMsgDecodeVirtualTree.GetLastSelected: PVirtualNode;
begin
	Result := GainLastSelected(Self);
end;

procedure TMsgDecodeVirtualTree.CustomSearch;
var
  Handled: Boolean;
  SearchStr: String;
	SrchOptions: TSearchOptions;
begin
  if not Assigned(FOnBeforeSearch) then Exit;
  Handled := False;
  FOnBeforeSearch(Self, SearchStr, SrchOptions, Handled, True);
  if not Handled then FindText(SearchStr, SrchOptions);
end;

procedure TMsgDecodeVirtualTree.ExportContext;
var
  FileName: String;
  XmlDoc: IXMLDocument;
begin
  if not Assigned(FOnBeforeExport) then Exit;
  FileName := '';
  FOnBeforeExport(Self, FileName);
  if FileName = '' then Exit;
  if FExportType = 1 then             //XML
  begin
    XmlDoc := NewXMLDocument;
    Self.ExportXml(XmlDoc.Node);
    XmlDoc.SaveToFile(FileName);
  end
  else                                //Text  CDJ110702
  begin
    FTextFile.Text := ExportText(FCurSourXml, FCurTitle);
    FTextFile.SaveToFile(FileName);
  end;
end;

procedure TMsgDecodeVirtualTree.SearchAgain;
var
  Handled: Boolean;
  SearchStr: String;
	SrchOptions: TSearchOptions;
begin
  if not Assigned(FOnBeforeSearch) then Exit;
  Handled := False;
  FOnBeforeSearch(Self, SearchStr, SrchOptions, Handled, False);
  if not Handled then FindText(SearchStr, SrchOptions);
end;

procedure TMsgDecodeVirtualTree.DoTextDrawing(var PaintInfo: TVTPaintInfo;
  Text: WideString; CellRect: TRect; DrawFormat: Cardinal);
begin
  if (PaintInfo.Column = Header.MainColumn) then
  begin
    FMainColumeAddDelt := Max(FMainColumeAddDelt,
												    	(PaintInfo.NodeWidth - 2 * TextMargin) -
                              (CellRect.Right - CellRect.Left));
  end;
  inherited;
end;

procedure TMsgDecodeVirtualTree.Paint;
begin
  repeat
    FMainColumeAddDelt := 0;
    inherited;
    if (FMainColumeAddDelt > 0) and
       (Header.MainColumn >= 0) and
       (Header.MainColumn <> Header.AutoSizeIndex) then
    begin
      Header.Columns[Header.MainColumn].Width :=
        Header.Columns[Header.MainColumn].Width + FMainColumeAddDelt;
    end else Break;
  until (FMainColumeAddDelt = 0);
end;

procedure TMsgDecodeVirtualTree.DoCopyNodeTextToClipboard(const ExportStr: string);
//var
//  hMem: THandle;
//  pMem: Pchar;
begin
 (* hMem := GlobalAlloc(GHND or GMEM_DDESHARE, succ(Length(ExportStr)));
  if hMem <> 0 then
  begin
    pMem := GlobalLock(hMem);                  {加锁全局内存块}
    if pMem <> nil then
    begin
      StrCopy(pMem, PChar(ExportStr));         {向全局内存块写入数据}
      GlobalUnlock(hMem);                      {解锁全局内存块}
    end;
  end;
  OpenClipboard(0);
  EmptyClipboard();
  SetClipboardData(CF_TEXT, hMem);
  CloseClipboard();
  //GlobalFree(hMem);
  *)

  Clipboard.AsText := ExportStr;
end;

function TMsgDecodeVirtualTree.GetSelectNodeText: string;
  procedure DoExportSelectText(Level: Integer; Node: PVirtualNode);
  var
    iCount: Integer;
  begin
    while Node <> nil do
    begin
      if Selected[Node] then
      begin
        if Result = '' then
          Result := Text[Node, 0]
        else
          Result := Result + #$D#$A + Text[Node, 0];
      end;
      DoExportSelectText(Level + 1, Node.FirstChild);
      Node := GetNextSibling(Node);
    end;
  end;
begin
  Result := '';
  DoExportSelectText(1, Self.RootNode.FirstChild);
end;

procedure TMsgDecodeVirtualTree.CopyNodeTextToClipboard;
var
  sExportStr: string;
begin
  sExportStr := GetSelectNodeText;
  if sExportStr <> '' then
    DoCopyNodeTextToClipboard(sExportStr);
end;

end.
