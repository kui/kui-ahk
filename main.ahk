;DebugMode := True
DebugMode := False

; DPI Awareness設定（高DPI環境でのスケーリング対応）
; -4 = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
; 各モニターのDPI設定に個別に対応し、システムとクライアント領域の両方でスケーリングを自動処理
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

SetKeyDelay(0)

; マウス座標をスクリーン全体の絶対座標で取得するように設定
; デフォルトだとアクティブなモニターの相対座標になるため実装が複雑になる
CoordMode("Mouse", "Screen")

; グローバル変数
global LastImeStatus := -1
global LastMouseX := 0
global LastMouseY := 0
global CurrentMouseX := 0
global CurrentMouseY := 0

; 定数
global MOUSE_INDICATOR_OFFSET := 20
global MOUSE_MOVE_THRESHOLD := 500  ; マウス移動の閾値（ピクセル）

; IME状態の定期チェックとマウス移動チェック（500msごと）
; Pollingではなくイベント駆動型が望ましいが、アクティブウィンドウの変更をフックして
; さらにアクティブウィンドウ内でもIME制御ウィンドウを持つコンポーネントにフォーカスが当たってるか確認し、
; さらにその中でIMEの変化まで制御するとなるとかなり複雑になるため、ここでは簡易的にポーリングで実装する。
SetTimer(CheckAndUpdateImeStatus, 500)

; IME状態をチェックして更新、およびマウス移動チェック
CheckAndUpdateImeStatus() {
    global LastImeStatus, LastMouseX, LastMouseY, CurrentMouseX, CurrentMouseY
    local currentStatus := ImeGet()

    ; 現在のマウス座標を更新（すべての機能で共有）
    MouseGetPos(&CurrentMouseX, &CurrentMouseY)

    ; IME状態の変更チェック
    if (currentStatus != LastImeStatus) {
        LastImeStatus := currentStatus
        UpdateMouseIndicatorStatus(currentStatus)

        ; IME状態変更時はマウス位置をリセット（英字切替判定用）
        LastMouseX := CurrentMouseX
        LastMouseY := CurrentMouseY
    }

    ; マウス移動チェック（日本語入力モード時のみ）
    if (LastImeStatus == 1) {
        ; マウス移動距離を計算（ユークリッド距離）
        local deltaX := CurrentMouseX - LastMouseX
        local deltaY := CurrentMouseY - LastMouseY
        local distance := Sqrt(deltaX * deltaX + deltaY * deltaY)

        ; 閾値を超えた場合は英数モードに切り替え
        if (distance > MOUSE_MOVE_THRESHOLD) {
            ImeSet(0)  ; 英数モードに切り替え
            ; 位置を更新（連続して切り替わることを防ぐ）
            LastMouseX := CurrentMouseX
            LastMouseY := CurrentMouseY
        }
    }

    ; インジケーター位置の更新（日本語入力モード時のみ）
    if (LastImeStatus == 1) {
        UpdateMouseIndicatorPosition()
    }
}

; 現在のIME状態を取得
ImeGet(windowTitle := "A") {
    local hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        local ptrSize := A_PtrSize ? A_PtrSize : 4
        local cbSize := 4 + 4 + (ptrSize * 6) + 16
        local stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }
    local result := DllCall("SendMessage",
        "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Int", 0x005,   ;wParam  : IMC_GETOPENSTATUS
        "Int", 0)       ;lParam  : 0
    return result
}

ImeSet(status, windowTitle := "A") {
    global LastMouseX, LastMouseY
    local hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        local ptrSize := A_PtrSize ? A_PtrSize : 4
        local cbSize := 4 + 4 + (ptrSize * 6) + 16
        local stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }
    local result := DllCall("SendMessage",
        "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Int", 0x006,   ;wParam  : IMC_SETOPENSTATUS
        "Int", status)  ;lParam  : 0 or 1
    ShowImeStatus(status)

    ; マウスカーソル近くのインジケーターも更新
    global LastImeStatus := status
    UpdateMouseIndicatorStatus(status)

    MouseGetPos(&LastMouseX, &LastMouseY)

    return result
}

; マウスカーソル近くのインジケーターをIME状態に応じて更新
UpdateMouseIndicatorStatus(status) {
    if (status) {
        ; 日本語入力モード: インジケーターを表示
        try {
            ImeMouseGui.Destroy()
        }

        global ImeMouseGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        ImeMouseGui.BackColor := "0x4CAF50"
        ImeMouseGui.SetFont("s20 bold cWhite", "メイリオ")
        ImeMouseGui.Add("Text", "Center w50 h35", "あ")

        ; 初期位置を設定してから表示
        UpdateMouseIndicatorPosition()
    } else {
        ; 英数モード: インジケーターを削除
        try {
            ImeMouseGui.Destroy()
        }
    }
}

; マウスカーソル近くのインジケーター位置だけを更新
UpdateMouseIndicatorPosition() {
    global CurrentMouseX, CurrentMouseY
    try {
        if (IsSet(ImeMouseGui)) {
            ; グローバルに管理されている現在のマウス座標を使用
            local mouseX := CurrentMouseX
            local mouseY := CurrentMouseY

            ; マウスカーソルがどのモニターにあるかを判定
            local monitorIndex := MonitorFromPoint(mouseX, mouseY)
            local monLeft, monTop, monRight, monBottom
            MonitorGet(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)

            ; インジケーターの実際のサイズを取得
            local guiWidth, guiHeight
            ImeMouseGui.GetPos(, , &guiWidth, &guiHeight)

            ; DPIスケーリングを取得して適用
            ; 96 = 標準DPI (100%スケーリング)
            ; A_ScreenDPI / 96 でスケール係数を計算 (例: 120/96=1.25 は 125%スケーリング)
            local dpiScale := A_ScreenDPI / 96
            guiWidth := guiWidth * dpiScale
            guiHeight := guiHeight * dpiScale

            ; 表示位置を決定
            ; デフォルトは右下（マウスの右下）
            local indicatorX := mouseX + MOUSE_INDICATOR_OFFSET
            local indicatorY := mouseY + MOUSE_INDICATOR_OFFSET

            ; 右端に近い場合は左側に表示
            if (indicatorX + guiWidth > monRight)
                indicatorX := mouseX - guiWidth - MOUSE_INDICATOR_OFFSET

            ; 下端に近い場合は上側に表示
            if (indicatorY + guiHeight > monBottom)
                indicatorY := mouseY - guiHeight - MOUSE_INDICATOR_OFFSET

            ImeMouseGui.Show("x" . indicatorX . " y" . indicatorY . " AutoSize NoActivate")
        }
    }
}

; IMEステータスを画面中央に表示
ShowImeStatus(status) {
    ; 既存のGUIを破棄
    try {
        if (IsSet(ImeGuiList)) {
            for guiItem in ImeGuiList {
                guiItem.Destroy()
            }
        }
    }

    ; 各モニターにGUIを作成して表示
    global ImeGuiList := []
    loop MonitorGetCount() {
        local monitorIndex := A_Index
        local monLeft, monTop, monRight, monBottom
        MonitorGetWorkArea(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)

        ; 新しいGUI（中央表示用）を作成
        local imeGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        imeGui.BackColor := status ? "0x4CAF50" : "0x2196F3"
        imeGui.SetFont("s48 bold cWhite", "メイリオ")

        local statusText := status ? "あ" : "_A"
        imeGui.Add("Text", "Center w120 h80", statusText)

        ; GUIのサイズを取得するため一旦表示
        imeGui.Show("AutoSize Hide")
        local guiWidth, guiHeight
        imeGui.GetPos(, , &guiWidth, &guiHeight)

        ; モニターの中央座標を計算
        local centerX := monLeft + (monRight - monLeft - guiWidth) // 2
        local centerY := monTop + (monBottom - monTop - guiHeight) // 2

        imeGui.Show("x" . centerX . " y" . centerY . " NoActivate")
        ImeGuiList.Push(imeGui)
    }

    ; 1秒後にすべてのGUIを破棄
    SetTimer(() => DestroyAllImeGui(), -1000)
}

; すべてのIME GUIを破棄
DestroyAllImeGui() {
    global ImeGuiList
    try {
        if (IsSet(ImeGuiList)) {
            for guiItem in ImeGuiList {
                guiItem.Destroy()
            }
            ImeGuiList := []
        }
    }
}

; マウス座標からモニター番号を取得
MonitorFromPoint(x, y) {
    global DebugMode
    local debugMsg := ""
    if (DebugMode) {
        debugMsg := "Checking monitors for point (" . x . ", " . y . "):`n"
    }

    loop MonitorGetCount() {
        local monLeft, monTop, monRight, monBottom
        MonitorGet(A_Index, &monLeft, &monTop, &monRight, &monBottom)

        if (DebugMode) {
            debugMsg .= "Monitor " . A_Index . ": L=" . monLeft . " T=" . monTop . " R=" . monRight . " B=" . monBottom
            if (x >= monLeft && x < monRight && y >= monTop && y < monBottom) {
                debugMsg .= " [MATCH]`n"
            } else {
                debugMsg .= "`n"
            }
        }

        if (x >= monLeft && x < monRight && y >= monTop && y < monBottom) {
            if (DebugMode) {
                ToolTip(debugMsg)
                SetTimer(() => ToolTip(), -3000)
            }
            return A_Index
        }
    }

    if (DebugMode) {
        debugMsg .= "No match found, returning 1"
        ToolTip(debugMsg)
        SetTimer(() => ToolTip(), -3000)
    }
    return 1  ; デフォルトはプライマリモニター
}

; F18 Modifier Key Mappings
#HotIf GetKeyState("F18", "P")

; カーソル移動
h:: Send "{Left}"
j:: Send "{Down}"
k:: Send "{Up}"
l:: Send "{Right}"

; 削除
s:: Send "{Backspace}"
d:: Send "{Delete}"

; Ctrl + キャレット移動
^h:: Send "^{Left}"  ; 単語ジャンプ左
^l:: Send "^{Right}" ; 単語ジャンプ右
^j:: Send "{PgDn}"   ; ページダウン
^k:: Send "{PgUp}"   ; ページアップ

; Alt + キャレット移動
!h:: Send "{Home}"  ; 行頭へジャンプ
!l:: Send "{End}"   ; 行末へジャンプ
!j:: Send "^{End}"  ; 最下部へジャンプ
!k:: Send "^{Home}" ; 最上部へジャンプ

; 選択
a:: Send "+{Home}"  ; キャレット左から行頭までを選択
f:: Send "+{End}"   ; キャレット右から行末までを選択

; 編集
z:: Send "^z"       ; Undo
+z:: Send "^y"      ; Redo
x:: Send "^x"       ; 切り取り
c:: Send "^c"       ; コピー
v:: Send "^v"       ; 貼り付け

; IME切り替え
Space:: ImeSet(0)   ; 英数入力
+Space:: ImeSet(1)  ; 日本語入力

; ブラウザナビゲーション
[:: Send "{Browser_Back}"    ; ブラウザバック
]:: Send "{Browser_Forward}" ; ブラウザフォワード

; 未定義のキーを無効化（定義済みのホットキー以外）
b:: return
e:: return
g:: return
i:: return
m:: return
n:: return
o:: return
p:: return
q:: return
r:: return
t:: return
u:: return
w:: return
y:: return
0:: return
1:: return
2:: return
3:: return
4:: return
5:: return
6:: return
7:: return
8:: return
9:: return
-:: return
^:: return
\:: return
@:: return
SC027:: return  ; ; キー (セミコロン)
,:: return
.:: return
/:: return
F1:: return
F2:: return
F3:: return
F4:: return
F5:: return
F6:: return
F7:: return
F8:: return
F9:: return
F10:: return
F11:: return
F12:: return
Tab:: return
Enter:: return
Esc:: return
BackSpace:: return
Delete:: return
Home:: return
End:: return
PgUp:: return
PgDn:: return
Insert:: return
PrintScreen:: return
ScrollLock:: return
Pause:: return
Left:: return
Right:: return
Up:: return
Down:: return

#HotIf