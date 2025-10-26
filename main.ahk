; Config
SetTitleMatchMode "RegEx"

DebugMode := True

Ignored := ["ahk_exe \\Code\.exe$", "ahk_exe \\ConEmu64\.exe$", "ahk_exe \\steamapps\\",
    "ahk_exe \\Minecraft\\.*\\javaw\.exe$"]

Browser := ["ahk_exe \\Explorer\.EXE$", "ahk_exe \\chrome\.exe$", "ahk_exe \\firefox\.exe$",
    "ahk_exe \\msedge\.exe$"]

; /Config

SetKeyDelay(0)

ImeSet(SetSts, WinTitle := "A") {
    hwnd := WinExist(WinTitle)
    if WinActive(WinTitle) {
        ptrSize := A_PtrSize ? A_PtrSize : 4
        cbSize := 4 + 4 + (ptrSize * 6) + 16
        stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }

    return DllCall("SendMessage"
        , "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd)
        , "UInt", 0x0283 ;Message : WM_IME_CONTROL
        , "Int", 0x006   ;wParam  : IMC_SETOPENSTATUS
        , "Int", SetSts) ;lParam  : 0 or 1
}

^q:: Suspend(-1)
!j:: ImeSet(0)
+!j:: ImeSet(1)

#HotIf DebugMode
F5:: Reload

for Element in Browser
    GroupAdd("Browser", Element)
#HotIf WinActive("ahk_group Browser")
#Include browser.ahk

for Element in Ignored
    GroupAdd("Ignored", Element)
;#HotIf Not WinActive("ahk_group Ignored")
;#Include generic.ahk
