{$A+,B-,D+,F-,G+,I+,K+,L+,N-,P-,Q-,R-,S+,T-,V+,W-,X+,Y+}
{$M 8192,8192}
Program Ishido;
Uses
  WinProcs, WinTypes,
  Objects, OWindows, ODialogs, OStdDlgs, BWCC, Strings;

{$R ISHIDO.RES}

Const
  AppName= 'Ishido';
  Version= 'Version 2.11';
  Copyright= 'by Olaf Gottschalk';
  Date= '03.09.95';
  IniName= 'ENTPACK.INI';
  HelpName= 'ISHIDO.HLP';

Const
  Crypt= $5115D04A;

  cm_Neu= 101; cm_Beenden= 102;
  cm_Backup= 103; cm_Sound= 104;
  cm_ShowMoves= 105; cm_Info= 106;
  cm_HighScores= 107; cm_ShowPouch= 108;
  cm_Help= 120;

  wm_InfoCancel= wm_User+200;

  XSize= 12; YSize= 8;
  XField= 40; YField= 46;

  XScore= 504; YScore= 55; WScore= 110; HScore= 60;
  XTouchStone= 540; YTouchStone= 190;
  WTouchStone= XField+2; HTouchStone= YField+2;
  XPouch= 508; YPouch= 302; WPouch= 100; HPouch= 85;
  XBoard= 16;  YBoard= 16;

  WindowWidth= 625; WindowHeight= 405;

Type
  THighScore= Record
    Name: Array[0..20] Of Char;
    Score: Word;
    FourWays, StonesLeft: Byte;
  End;
  PHighScoreList= ^THighScoreList;
  THighScoreList= Array[1..6] Of THighScore;

  PStone= ^TStone;
  TStone= Record
    Shape, Color: Byte;
  End;

  THints= Array[1..XSize, 1..YSize] Of Boolean;

Type
  TIshidoApp= Object(TApplication)
    Procedure InitMainWindow; virtual;
  End;

  PInfoDlg= ^TInfoDlg;
  TInfoDlg= Object(TDlgWindow)
    BM, OldBM: HBitmap;
    DC: HDC;
    TxtWidth, TxtHeight, FieldWidth, OX: Integer;
    A: TPoint;
    Quit: Boolean;
    Procedure SetupWindow; virtual;
    Procedure Ok(Var Msg: TMessage); virtual id_First+id_Ok;
    Procedure DoScroll;
    Procedure DoYield;
    Destructor Done; virtual;
  End;

  PHighScoreDlg= ^THighScoreDlg;
  THighScoreDlg= Object(TDialog)
    Highs: PHighScoreList;
    Procedure SetupWindow; virtual;
  End;

  PPouchDlg= ^TPouchDlg;
  TPouchDlg= Object(TDialog)
    Procedure WMDrawItem(Var Msg: TMessage); virtual wm_First+wm_DrawItem;
  End;

  PIshidoWin= ^TIshidoWin;
  TIshidoWin= Object(TWindow)
    Score, ScoreFactor: Word;
    FourWays: Byte;
    Pouch: Array[1..67] Of TStone;
    PouchCnt: Byte;
    Stone: TStone;
    Board: Array[0..XSize+1, 0..YSize+1] Of TStone;
    Hints: THints;
    PossibleMoves: Byte;
    LastMove: TPoint; LastScore, LastFourWays: Word;
    Sound: Boolean;
    ShowMoves: Boolean;
    HighScores: THighScoreList;
    HighScoreAdded: Boolean;
    { OWL-Methoden }
    Constructor Init;
    Procedure SetupWindow; virtual;
    Destructor Done; virtual;
    Function CanClose: Boolean; virtual;
    Procedure GetWindowClass(Var AWndClass: TWndClass); virtual;
    Function GetClassName: PChar; virtual;
    Procedure Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct); virtual;
    { eigene Methoden }
    Procedure LoadHighScores;
    Procedure SaveHighScores;
    Procedure AddHighScore;
    Procedure Rahmen(PaintDC: HDC; X1, Y1, X2, Y2: Word;
      drct: Boolean; St: Byte);
    Procedure Text3D(DC: HDC; X, Y: Word; Txt: String);
    Procedure InitGame;
    Function EndGame: Boolean;
    Function ScoreFunc(X, Y, Matches: Byte): Word;
    Function CheckPosition(X, Y: Byte): Byte;
    Procedure GetHints(PaintDC: HDC; Erase: Boolean);
    Procedure DrawTouchStone(PaintDC: HDC); 
    Procedure DrawScore(PaintDC: HDC); 
    Procedure DrawShape(PaintDC: HDC; X, Y: Word; aStone: TStone); 
    Procedure DrawStone(PaintDC: HDC; X, Y: Byte; EraseBkgrd: Boolean);
    Procedure DrawPouch(PaintDC: HDC; All: Boolean);
    { Messages }
    Procedure WMInfoCancel(Var Msg: TMessage); virtual wm_First+wm_InfoCancel;
    Procedure WMLButtonDown(Var Msg: TMessage); virtual wm_First+wm_LButtonDown;
    Procedure CMNew(Var Msg: TMessage); virtual cm_First+cm_Neu;
    Procedure CMBeenden(Var Msg: TMessage); virtual cm_First+cm_Beenden;
    Procedure CMBackup(Var Msg: TMessage); virtual cm_First+cm_Backup;
    Procedure CMSound(Var Msg: TMessage); virtual cm_First+cm_Sound;
    Procedure CMShowMoves(Var Msg: TMessage); virtual cm_First+cm_ShowMoves;
    Procedure CMInfo(Var Msg: TMessage); virtual cm_First+cm_Info;
    Procedure CMHighScores(Var Msg: TMessage); virtual cm_First+cm_HighScores;
    Procedure CMShowPouch(Var Msg: TMessage); virtual cm_First+cm_ShowPouch;
    Procedure CMHelp(Var Msg: TMessage); virtual cm_First+cm_Help;
   private
    InfoCancel: Boolean;
    WhitePen, GrayPen: HPen;
    TheFont: HFont;
    StonesBM, OldBM: HBitmap;
    StonesDC: HDC;
  End;

{==============================}

Function GetString(N: Byte): PChar;
Const
  S: Array[0..255] Of Char= '';
Begin
  LoadString(hInstance, N, S, SizeOf(S));
  GetString:=@S;
End;

Procedure TIshidoApp.InitMainWindow;
Begin
  MainWindow:=New(PIshidoWin, Init);
End;

{== TInfoDlg ==}
Const
  InfoTxt: PChar=
    'Geschrieben mit Borland Pascal 7.01 - '+
    'Viele Grüße an Ulli, Karsten, Niko, Judith, Holly, Christian'+
    ', Franzi, Jens und alle die mich kennen - '+
    'Viel Spaß beim Spielen ! ! !';
  Step= 1;

Procedure TInfoDlg.SetupWindow;
Var
  L: LongInt;
  PaintDC: HDC;
  OldBrush: HBrush;
  OldFont, TheFont: HFont;
  R: TRect;
Begin
  TDlgWindow.SetupWindow;
  SetDlgItemText(hWindow, 201, Version);
  SetDlgItemText(hWindow, 202, Copyright);
  SetDlgItemText(hWindow, 203, Date);
  { Koordinaten von Item 210 }
  GetWindowRect(GetItemHandle(210), R);
  A.X:=R.Left; A.Y:=R.Top;
  ScreenToClient(hWindow, A);
  FieldWidth:=R.Right-R.Left-4;
  { DC erzeugen und Font in richtiger Größe bestimmen }
  PaintDC:=GetDC(hWindow);
  DC:=CreateCompatibleDC(PaintDC);
  TheFont:=CreateFont(R.Bottom-R.Top-4, 0, 0, 0, fw_Bold, 0, 0, 0, ansi_charset,
    out_default_precis, clip_default_precis, proof_quality, default_pitch or
    ff_swiss, 'MS Sans Serif');
  { Bitmap anlegen }
  OldFont:=SelectObject(DC, TheFont);
  L:=GetTextExtent(DC, InfoTxt, StrLen(InfoTxt));
  TxtWidth:=LoWord(L)+Step;
  TxtHeight:=HiWord(L);
  Inc(A.Y, (R.Bottom-R.Top-4-TxtHeight) Div 2);
  BM:=CreateCompatibleBitmap(PaintDC, TxtWidth, TxtHeight);
  ReleaseDC(PaintDC, hWindow);
  { Bitmap vorbereiten }
  OldBM:=SelectObject(DC, BM);
  OldBrush:=SelectObject(DC, GetStockObject(LTGRAY_BRUSH));
  PatBlt(DC, 0, 0, TxtWidth, TxtHeight, PatCopy);
  SelectObject(DC, OldBrush);
  SetBkMode(DC, Transparent);
  TextOut(DC, 0, 0, InfoTxt, StrLen(InfoTxt));
  SelectObject(DC, OldFont);
  OX:=-FieldWidth;
  EnableWindow(Parent^.hWindow, False);
End;

Procedure TInfoDlg.DoScroll;
Var
  PaintDC: HDC;
  R: TRect;
Begin
  PaintDC:=GetDC(hWindow);
  BitBlt(PaintDC, A.X+2, A.Y+2, FieldWidth, TxtHeight, DC, OX, 0, SrcCopy);
  Inc(OX, Step);
  If OX>TxtWidth Then OX:=-FieldWidth;
  ReleaseDC(hWindow, PaintDC);
End;

Procedure TInfoDlg.DoYield;
Var Msg: TMsg;
Begin
  While PeekMessage(Msg, 0, 0, 0, pm_Remove) Do
    If Not IsDialogMessage(hWindow, Msg) Then
    Begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    End;
End;

Procedure TInfoDlg.Ok;
Begin
  SendMessage(Parent^.hWindow, wm_InfoCancel, 0, 0);
  EnableWindow(Parent^.hWindow, True);
End;

Destructor TInfoDlg.Done;
Begin
  SelectObject(DC, OldBM);
  DeleteObject(BM);
  DeleteDC(DC);
  EnableWindow(Parent^.hWindow, True);
  EndDlg(1);
  TDlgWindow.Done;
End;

{== TPouchDlg ==}
Procedure TPouchDlg.WMDrawItem;
Var
  X, Y, P: Byte;
  IS: PDrawItemStruct;
  SpaceX, OfsX, SpaceY, OfsY: Word;
  R: TRect;
Begin
  IS:=PDrawItemStruct(Msg.lParam);
  GetClientRect(IS^.hWndItem, R);
  SpaceX:=(R.Right-11*XField) Div 10;
  OfsX:=((R.Right-11*XField-10*SpaceX) Div 2)+1; 
  SpaceY:=(R.Bottom-6*YField) Div 5;
  OfsY:=((R.Bottom-6*YField-5*SpaceY) Div 2)+1;
  P:=1;
  With PIshidoWin(Parent)^ Do
  For Y:=0 To 5 Do
    For X:=0 To 10 Do
    Begin
      If P>=PouchCnt Then
        DrawShape(IS^.hDC, OfsX+X*(XField+SpaceX), OfsY+Y*(YField+SpaceY), Pouch[P]);
      Inc(P);
    End;
  Msg.Result:=1;
End;

{== THighScoreDlg ==}
Procedure THighScoreDlg.SetupWindow;
Var I: Byte;
Begin
  TDialog.SetupWindow;
  For I:=1 To 6 Do
  With Highs^[I] Do
  Begin
    SetDlgItemText(hWindow, I*100, Name);
    SetDlgItemInt(hWindow, I*100+1, Score, False);
    SetDlgItemInt(hWindow, I*100+2, FourWays, False);
    SetDlgItemInt(hWindow, I*100+3, StonesLeft, False); 
  End;
End;

{== TIshidoWin ==}
Constructor TIshidoWin.Init;
Var XS, YS, H: Word;
Begin
  TWindow.Init(nil, AppName+' for Windows');
  Attr.Style:=ws_Overlapped Or ws_MinimizeBox Or ws_SysMenu;
  Attr.Menu:=LoadMenu(hInstance, PChar(100));
  H:=WindowHeight+GetSystemMetrics(SM_CYCAPTION)+GetSystemMetrics(SM_CYMENU);
  XS:=GetSystemMetrics(SM_CXSCREEN); YS:=GetSystemMetrics(SM_CYSCREEN);
  Attr.X:=(XS Div 2)-(WindowWidth Div 2);
  Attr.Y:=(YS Div 2)-(H Div 2);
  Attr.W:=WindowWidth; Attr.H:=H;
  Sound:=GetPrivateProfileInt(AppName, 'Sound', 1, IniName)=1;
  If Not Sound Then
    CheckMenuItem(Attr.Menu, cm_Sound, mf_UnChecked);
  ShowMoves:=False;
  LoadHighScores;
  InitGame;
End;

Procedure TIshidoWin.SetupWindow;
Var
  DC: HDC;
  L: TLogBrush;
Begin
  TWindow.SetupWindow;
  DC:=GetDC(hWindow);
  StonesBM:=LoadBitmap(hInstance, PChar(100));
  StonesDC:=CreateCompatibleDC(DC);
  OldBM:=SelectObject(StonesDC, StonesBM);
  ReleaseDC(hWindow, DC);
  WhitePen:=GetStockObject(WHITE_PEN);
  GrayPen:=CreatePen(ps_Solid, 1, RGB(128, 128, 128));
  TheFont:=CreateFont(28, 16, 0, 0, fw_Bold, 0, 0, 0,
    ansi_charset, out_default_precis,
    clip_default_precis, proof_quality, variable_pitch or
    ff_dontcare, 'Times New Roman');
  ShowWindow(hWindow, sw_Show);
  If ParamStr(1)<>'/c' Then
    SendMessage(hWindow, wm_Command, cm_Info, 0);
End;

Destructor TIshidoWin.Done;
Var C: Array[0..1] Of Char;
Begin
  WinHelp(hWindow, HelpName, Help_Quit, 0);
  C[1]:=#0;
  C[0]:=Char(Byte('0')+Byte(Sound));
  WritePrivateProfileString(AppName, 'Sound', C, IniName);
  DeleteObject(GrayPen);
  DeleteObject(TheFont);
  SelectObject(StonesDC, OldBM);
  DeleteObject(StonesBM);
  DeleteDC(StonesDC);
  TWindow.Done;
End;

Function TIshidoWin.CanClose: Boolean;
Begin
  CanClose:=EndGame;
End;

Procedure TIshidoWin.InitGame;
Var
  I: Word;
  Shape, Color, S1, S2: Byte;
  S: TStone;
  Start: Array[1..6] Of TStone;

  Function ShapeOk: Boolean;
  Var I: Byte;
  Begin
    ShapeOk:=True;
    For I:=1 To 6 Do If Start[I].Shape=Shape Then
    Begin
      ShapeOk:=False;
      Exit;
    End;           
  End;

  Function ColorOk: Boolean;
  Var I: Byte;
  Begin
    ColorOk:=True;
    For I:=1 To 6 Do If Start[I].Color=Color Then
    Begin
      ColorOk:=False;
      Exit;
    End;      
  End;

  Function StoneOk: Boolean;
  Var I: Byte;
  Begin
    StoneOk:=True;
    For I:=1 To 6 Do If (Start[I].Shape=Shape) And (Start[I].Color=Color) Then
    Begin
      StoneOk:=False;
      Exit;
    End;
  End;

Begin
  Randomize;
  { Startsteine aussuchen }
  FillChar(Start, SizeOf(Start), 0);
  For I:=1 To 6 Do
  Begin
    Repeat
      Shape:=Random(6)+1;
    Until ShapeOk;
    Repeat
      Color:=Random(6)+1;
    Until ColorOk;
    Start[I].Shape:=Shape;
    Start[I].Color:=Color;
  End;     
  { Pouch füllen }
  FillChar(Pouch, SizeOf(Pouch), 0);
  I:=1;
  For Shape:=1 To 6 Do
    For Color:=1 To 6 Do
    Begin
      Pouch[I].Shape:=Shape;
      Pouch[I].Color:=Color;
      Inc(I);
      If StoneOk Then
      Begin 
        Pouch[I]:=Pouch[I-1];
        Inc(I);
      End;
    End;
  { Durchmischen }
  If I<>67 Then MessageBox(hWindow, 'FEHLER: Pouchgröße  !', AppName, MB_OK);
  For I:=1 To 66 Do
    If Pouch[I].Shape=0 Then
      MessageBox(hWindow, 'FEHLER: Pouch fehlerhaft !', AppName, MB_OK);
  For I:=1 To 500 Do
  Begin
    S1:=Random(66)+1;
    S2:=Random(66)+1;
    S:=Pouch[S1];
    Pouch[S1]:=Pouch[S2];
    Pouch[S2]:=S;
  End;
  FillChar(Board, SizeOf(Board), 0);
  Board[1, 1]:=Start[1];
  Board[12, 1]:=Start[2];
  Board[12, 8]:=Start[3];
  Board[1, 8]:=Start[4];
  Board[6, 4]:=Start[5];
  Board[7, 5]:=Start[6];
  Stone:=Pouch[1];
  PouchCnt:=2;
  Score:=0;
  ScoreFactor:=1;
  FourWays:=0;
  LastMove.X:=-1; LastMove.Y:=-1;
  PossibleMoves:=1;
  HighScoreAdded:=False;
  { Menü setzen }
  EnableMenuItem(Attr.Menu, cm_Backup, mf_Disabled Or mf_Grayed);
  CheckMenuItem(Attr.Menu, cm_ShowMoves, mf_UnChecked);
  ShowMoves:=False;
End;

Function TIshidoWin.EndGame: Boolean;
Begin
  If (PossibleMoves>0) And (Score>0) Then
    If MessageBox(hWindow, GetString(1), AppName,
      MB_YESNO Or MB_ICONQUESTION)<>ID_YES Then
    Begin
      EndGame:=False;
      Exit;
    End;
  AddHighScore;
  EndGame:=True;      
End;

Procedure TIshidoWin.LoadHighScores;
Var
  I, J: Byte;
  C: Integer;
  L: LongInt;
  S, T: Array[0..50] Of Char;
Begin
  FillChar(HighScores, SizeOf(HighScores), 0);
  StrCopy(S, 'High  ');
  For I:=1 To 6 Do
  With HighScores[I] Do
  Begin
    S[4]:=Char(I+Ord('0'));
    S[5]:='N';
    GetPrivateProfileString(AppName, S, 'Unbekannt', Name, 21, IniName);
    S[5]:='S';
    GetPrivateProfileString(AppName, S, '', T, SizeOf(T), IniName);
    If T[0]=#0 Then L:=0 XOr Crypt Else Val(T, L, C);
    L:=L Xor Crypt;
    Score:=HiWord(L);
    FourWays:=LoWord(L) And $00FF;
    StonesLeft:=(LoWord(L) And $FF00) Shr 8;
  End;
End;

Procedure TIshidoWin.SaveHighScores;
Var
  I, J: Byte;
  L: LongInt;
  S, T: Array[0..50] Of Char; 
Begin
  StrCopy(S, 'High  ');
  For I:=1 To 6 Do
  With HighScores[I] Do
  Begin
    S[4]:=Char(I+Ord('0'));
    S[5]:='N';
    WritePrivateProfileString(AppName, S, Name, IniName);
    L:=(LongInt(Score) Shl 16) Or (StonesLeft Shl 8) Or FourWays;
    L:=L XOr Crypt;
    Str(L, T);
    S[5]:='S';
    WritePrivateProfileString(AppName, S, T, IniName);
  End;
End;

Procedure TIshidoWin.AddHighScore;
Var
  I, J: Word;
  M: TMessage;
  D: PInputDialog;
  S: Array[0..20] Of Char;
Begin
  If HighScoreAdded Then Exit;
  HighScoreAdded:=True;
  If Score=0 Then Exit;
  I:=1;
  While (I<7) And (HighScores[I].Score>Score) Do Inc(I);
  If I<7 Then
  Begin
    S[0]:=#0;
    New(D, Init(@Self, AppName, GetString(2),
      @S, SizeOf(S)));
    If Application^.ExecDialog(D)=ID_OK Then
    Begin
      J:=6;
      While (J>I) Do
      Begin
        HighScores[J]:=HighScores[J-1];
        Dec(J);
      End;
      StrCopy(HighScores[I].Name, S);
      HighScores[I].Score:=Score;
      HighScores[I].FourWays:=FourWays;
      HighScores[I].StonesLeft:=68-PouchCnt;
      SaveHighScores;
      CMHighScores(M);
    End;
  End;
End;

Function TIshidoWin.ScoreFunc(X, Y, Matches: Byte): Word;
Const
  Bonus: Array[1..12] Of Word=
    (25, 50, 100, 200, 400, 600, 800, 1000, 5000, 10000, 25000, 50000); 
Begin
  If (X>1) And (Y>1) And (X<XSize) And (Y<YSize) Then
  Case Matches Of
    1: ScoreFunc:=ScoreFactor;
    2: ScoreFunc:=2*ScoreFactor;
    3: ScoreFunc:=4*ScoreFactor;
    4: Begin
         Inc(FourWays);
         ScoreFunc:=8*ScoreFactor+Bonus[FourWays];
         ScoreFactor:=ScoreFactor*2;
       End;
  End Else
    ScoreFunc:=0;
End;

Function TIshidoWin.CheckPosition(X, Y: Byte): Byte;
Var
  Color, Shape, Matches: Byte;
  Mismatch: Boolean;
  Procedure CheckStone(Var P: TStone);
  Begin
    If P.Shape=0 Then Exit;
    If (P.Shape<>Stone.Shape) And (P.Color<>Stone.Color) Then
    Begin
      Mismatch:=True;
      Exit;
    End;
    Inc(Matches);
    If P.Shape=Stone.Shape Then Inc(Shape);
    If P.Color=Stone.Color Then Inc(Color);
  End;
Begin
  Mismatch:=False;
  Color:=0;
  Shape:=0;
  Matches:=0;
  CheckStone(Board[X-1, Y]);
  CheckStone(Board[X+1, Y]);
  CheckStone(Board[X, Y-1]);
  CheckStone(Board[X, Y+1]);
  If Mismatch Then Matches:=0;
  Case Matches Of
    2, 3: If (Shape=0) Or (Color=0) Then Matches:=0;
    4: If (Shape<2) Or (Color<2) Then Matches:=0;
  End;
  CheckPosition:=Matches;
End;

Procedure TIshidoWin.GetHints;
Var
  X, Y: Byte;
  Old: THints;
Begin
  Move(Hints, Old, SizeOf(Old));
  PossibleMoves:=0;
  For X:=1 To XSize Do
    For Y:=1 To YSize Do
      If Board[X, Y].Shape=0 Then
      Begin
        If (CheckPosition(X, Y)>0) And (Not Erase) Then
        Begin
          Inc(PossibleMoves);
          Hints[X, Y]:=True;
        End Else
          Hints[X, Y]:=False;
        If Old[X, Y] Or Hints[X, Y] Then DrawStone(PaintDC, X, Y, ShowMoves);
      End;
End;

Procedure TIshidoWin.GetWindowClass;
Begin
  TWindow.GetWindowClass(AWndClass);
  AWndClass.hbrBackground:=GetStockObject(LTGRAY_BRUSH);
  AWndClass.hIcon:=LoadIcon(hInstance, PChar(100));
End;

Function TIshidoWin.GetClassName: PChar;
Begin
  GetClassName:='IshidoWindow';
End;

Procedure TIshidoWin.Rahmen;
Var
  Nr: Byte;
  OldPen: HPen; 
Begin
  If drct Then
    OldPen:=SelectObject(PaintDC, WhitePen)
  Else
    OldPen:=SelectObject(PaintDC, GrayPen);
  For Nr:=0 To St-1 Do
  Begin
    MoveTo(PaintDC, X1+Nr, Y2-Nr);
    LineTo(PaintDC, X1+Nr, Y1+Nr);
    LineTo(PaintDC, X2-Nr, Y1+Nr);
  End;
  If drct Then
    SelectObject(PaintDC, GrayPen)
  Else
    SelectObject(PaintDC, WhitePen);
  For Nr:=0 To St-1 Do
  Begin
    MoveTo(PaintDC, X2-Nr, Y1+Nr);
    LineTo(PaintDC, X2-Nr, Y2-Nr);
    LineTo(PaintDC, X1+Nr, Y2-Nr);
  End;
  SelectObject(PaintDC, OldPen);
End;

Procedure TIshidoWin.Text3D;
Var OldFont: HFont;
Begin
  SetTextAlign(DC, ta_Center);
  SetBkMode(DC, Transparent);
  OldFont:=SelectObject(DC, TheFont);
  SetTextColor(DC, RGB(255, 255, 255));
  TextOut(DC, X-1, Y-1, @Txt[1], Length(Txt));
  SetTextColor(DC, RGB(128, 128, 128));
  TextOut(DC, X+1, Y+1, @Txt[1], Length(Txt));
  SetTextColor(DC, RGB(192, 192, 192));
  TextOut(DC, X, Y, @Txt[1], Length(Txt));
  SelectObject(DC, OldFont);
End;

Procedure TIshidoWin.DrawTouchStone;
Begin
  DrawShape(PaintDC, XTouchStone+4, YTouchStone+4, Stone);
End;

Procedure TIshidoWin.DrawScore;
Var
  Txt: String;
  OldBrush: HBrush;
Begin
  OldBrush:=SelectObject(PaintDC, GetStockObject(LTGRAY_BRUSH));
  PatBlt(PaintDC, XScore+4, YScore+4, WScore-7, HScore-7, PatCopy);
  BitBlt(PaintDC, XScore+12, YScore+35, 18, 18, StonesDC, 50, 246, SrcCopy);
  Str(Score, Txt);
  Text3D(PaintDC, XScore+(WScore Div 2), YScore+4, Txt);
  Str(FourWays, Txt);
  Text3D(PaintDC, XScore+(WScore Div 2), YScore+30, Txt);
  SelectObject(PaintDC, OldBrush);
End;

Procedure TIshidoWin.DrawShape;
Var
  XS, YS: Integer;
  OldBrush: HBrush;
Begin
  If aStone.Shape>0 Then
  Begin
    YS:=(aStone.Color-1)*41;
    XS:=(aStone.Shape-1)*34;
    BitBlt(PaintDC, X, Y, 33, 40, StonesDC, XS, YS, SrcCopy);
  End Else
  Begin
    OldBrush:=SelectObject(PaintDC, GetStockObject(LTGRAY_BRUSH));
    PatBlt(PaintDC, X, Y, 33, 40, PatCopy);
    SelectObject(PaintDC, OldBrush);
  End;
End;

Procedure TIshidoWin.DrawStone;
Var
  XP, YP: Word;
  Beyond: Boolean;
  OldBrush: HBrush;
Begin
  Beyond:=(X=1) Or (X=XSize) Or (Y=1) Or (Y=YSize);
  XP:=XBoard+(X-1)*XField;
  YP:=YBoard+(Y-1)*YField;
  If EraseBkgrd Then
  Begin
    OldBrush:=SelectObject(PaintDC, GetStockObject(LTGRAY_BRUSH));
    PatBlt(PaintDC, XP, YP, XField, YField, PatCopy);
    SelectObject(PaintDC, OldBrush);
  End;
  If Board[X, Y].Shape=0 Then
  Begin
    Rahmen(PaintDC, XP, YP, XP+XField-1, YP+YField-1, False, 1);
    If ShowMoves And Hints[X, Y] Then
      BitBlt(PaintDC, XP+8, YP+10, 24, 24, StonesDC, 0, 246, SrcCopy);
  End Else
  Begin
    Rahmen(PaintDC, XP, YP, XP+XField-1, YP+YField-1, True, 2);
    DrawShape(PaintDC, XP+3, YP+3, Board[X, Y]);
  End;
End;

Procedure TIshidoWin.DrawPouch;
Var X, Y, P: Byte;
Begin
  P:=1;
  For Y:=1 To 6 Do
    For X:=1 To 11 Do
    Begin
      If All Or (Abs(P-PouchCnt)<2) Then
        BitBlt(PaintDC, XPouch+7+(X-1)*8, YPouch+7+(Y-1)*12, 8, 11,
          StonesDC, 30, 246+Byte(P<PouchCnt)*12, SrcCopy);
      Inc(P); 
    End;    
End;

Procedure TIshidoWin.Paint;
Var
  Rect: TRect;
  X, Y: Byte;
Begin
  GetClientRect(hWindow, Rect);
  With Rect Do
  Begin
    Text3D(PaintDC, 558, 15, AppName);
    Rahmen(PaintDC, 0, 0, Right-1, Bottom-1, True, 6);
    Rahmen(PaintDC, XScore, YScore, XScore+WScore, YScore+HScore, True, 4);
    DrawScore(PaintDC);
    Rahmen(PaintDC, XTouchStone, YTouchStone, XTouchStone+WTouchStone, YTouchStone+HTouchStone, False, 4);
    DrawTouchStone(PaintDC);
    Rahmen(PaintDC, XPouch, YPouch, XPouch+WPouch, YPouch+HPouch, False, 4);
    DrawPouch(PaintDC, True);  
    Rahmen(PaintDC, XBoard-4, YBoard-4, XBoard+XField*XSize+4, YBoard+YField*YSize+4, True, 4);
    For X:=1 To XSize Do
      For Y:=1 To YSize Do
        DrawStone(PaintDC, X, Y, False);
  End;
End;

Procedure TIshidoWin.WMLButtonDown;
Var
  X, Y: Integer;
  Matches: Byte;
  DC: HDC;
Begin
  Matches:=0;
  X:=(Msg.lParamLo-XBoard) Div XField+1;
  Y:=(Msg.lParamHi-YBoard) Div YField+1;
  If (X>=1) And (X<=XSize) And
     (Y>=1) And (Y<=YSize) And
     (Board[X, Y].Shape=0) Then
  Begin
    Matches:=CheckPosition(X, Y);
    If Matches>0 Then
    Begin
      { Rückgängig-Informationen sichern }
      LastMove.X:=X;
      LastMove.Y:=Y;
      LastScore:=Score;
      LastFourWays:=FourWays;
      { Rückgängig ist verfügbar } 
      EnableMenuItem(Attr.Menu, cm_Backup, mf_Enabled);
      { Stein setzen }
      Board[X, Y]:=Stone;
      DC:=GetDC(hWindow);
      DrawStone(DC, X, Y, False);
      Inc(Score, ScoreFunc(X, Y, Matches));
      DrawScore(DC);
      Stone:=Pouch[PouchCnt];
      Inc(PouchCnt);
      DrawTouchStone(DC);
      If PouchCnt=68 Then
      Begin
        PossibleMoves:=0;
        Inc(Score, 1000);
        DrawScore(DC);
        MessageBox(hWindow, GetString(3), AppName, MB_OK Or MB_ICONEXCLAMATION);
        EnableMenuItem(Attr.Menu, cm_Backup, mf_Disabled Or mf_Grayed);
        EndGame;
      End Else
      Begin     
        If Stone.Shape=0 Then
          MessageBox(hWindow, 'FEHLER: Pouch defekt !', AppName, MB_OK);
        GetHints(DC, False);
        DrawPouch(DC, False);
        If PossibleMoves=0 Then
        Begin
          Case 68-PouchCnt Of
            2: Inc(Score, 100);
            1: Inc(Score, 500);
          End;
          DrawScore(DC);
          MessageBox(hWindow, GetString(4), AppName,
            MB_OK Or MB_ICONEXCLAMATION);
          EnableMenuItem(Attr.Menu, cm_Backup, mf_Disabled Or mf_Grayed);
          EndGame;
        End;
      End;
      ReleaseDC(hWindow, DC);
    End;
  End Else
  With Msg Do
  If (lParamLo>=XPouch) And (lParamHi>=YPouch) And
     (lParamLo<=XPouch+WPouch) And (lParamHi<=YPouch+HPouch) Then
  Begin
    Matches:=1;
    CMShowPouch(Msg);
  End;  
  If (Matches=0) And Sound Then MessageBeep(0);
End;

Procedure TIshidoWin.CMNew;
Begin
  If EndGame Then
  Begin
    InitGame;
    InvalidateRect(hWindow, nil, True);
  End;
End;

Procedure TIshidoWin.CMBeenden;
Begin
  CloseWindow;
End;

Procedure TIshidoWin.CMBackup;
Var
  DC: HDC;
Begin
  Score:=LastScore;
  If FourWays<>LastFourWays Then ScoreFactor:=ScoreFactor Div 2;
  FourWays:=LastFourWays;
  With LastMove Do
  Begin
    Dec(PouchCnt);
    Stone:=Pouch[PouchCnt-1];
    Board[X, Y].Shape:=0;
    DC:=GetDC(hWindow);
    DrawStone(DC, X, Y, True);
    DrawScore(DC);
    DrawTouchStone(DC);
    DrawPouch(DC, False);
    GetHints(DC, False);
    ReleaseDC(hWindow, DC);
  End;
  EnableMenuItem(Attr.Menu, cm_Backup, mf_Disabled Or mf_Grayed);
End;

Procedure TIshidoWin.CMSound;
Var C: Word;
Begin
  Sound:=Not Sound;
  If Sound Then C:=mf_Checked Else C:=mf_UnChecked;
  CheckMenuItem(Attr.Menu, cm_Sound, C);
End;

Procedure TIshidoWin.CMShowMoves;
Var
  C: Word;
  DC: HDC;
  NewS: Boolean;
Begin
  If Not HighScoreAdded Then
    If MessageBox(hWindow, GetString(5), AppName,
      MB_OKCANCEL Or MB_ICONEXCLAMATION)<>ID_OK Then Exit;
  HighScoreAdded:=True;
  NewS:=Not ShowMoves;
  If NewS Then C:=mf_Checked Else C:=mf_UnChecked;
  CheckMenuItem(Attr.Menu, cm_ShowMoves, C);
  ShowMoves:=True;
  DC:=GetDC(hWindow);
  GetHints(DC, Not NewS);
  ReleaseDC(hWindow, DC);
  ShowMoves:=NewS;
End;

Procedure TIshidoWin.WMInfoCancel;
Begin
  InfoCancel:=True;
End;

Function FileExist(FName: String): Boolean;
Var F: File;
Begin
  {$I-}
  Assign(F, FName);
  Reset(F);
  FileExist:=IOResult=0;
  Close(F);
  {$I+}
End;

Procedure TIshidoWin.CMInfo;
Var
  D: PInfoDlg;
  T, C: Word;
Begin
  C:=GetPrivateProfileInt(AppName, 'ScrollSpeed', 0, IniName);
  If C=0 Then
  Begin
    C:=100;
    WritePrivateProfileString(AppName, 'ScrollSpeed', '60', IniName);
  End;
  New(D, Init(@Self, PChar(100)));
  Application^.MakeWindow(D);
  ShowWindow(D^.hWindow, sw_Show);
  InfoCancel:=False;
  T:=0;
  While Not InfoCancel Do
  Begin
    D^.DoYield;
    If T=0 Then
    Begin
      D^.DoScroll;
      T:=C;
    End Else
      Dec(T);
  End;
  Dispose(D, Done);
End;

Procedure TIshidoWin.CMHighScores;
Var
  D: PHighScoreDlg;
Begin
  New(D, Init(@Self, PChar(101)));
  D^.Highs:=@HighScores;
  Application^.ExecDialog(D);
End;

Procedure TIshidoWin.CMShowPouch;
Var W: PPouchDlg;
Begin
  If Not HighScoreAdded Then
    If MessageBox(hWindow, GetString(6), AppName,
      MB_OKCANCEL Or MB_ICONEXCLAMATION)<>ID_OK Then Exit;
  HighScoreAdded:=True;
  New(W, Init(@Self, PChar(102)));
  Application^.ExecDialog(W);
End;

Procedure TIshidoWin.CMHelp;
Begin
  WinHelp(hWindow, HelpName, HELP_INDEX, 0);
End;

Var
  App: TIshidoApp;

Begin
  App.Init(AppName);
  App.Run;
  App.Done;
End.