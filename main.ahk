; Config
SetTitleMatchMode, RegEx

;DebugMode = True

Ignored := [ "ahk_exe \\Code\.exe$"
            ,"ahk_exe \\ConEmu64\.exe$"
            ,"ahk_exe \\steamapps\\"
            ,"ahk_exe \\Minecraft\\.*\\javaw.exe$"]

Browser := [ "ahk_exe \\Explorer\.EXE$"
            ,"ahk_exe \\chrome\.exe$"]

;GroupAdd, Ignored, ahk_exe \\Code\.exe$
;GroupAdd, Ignroed, ahk_exe \\ConEmu64\.exe$
;GroupAdd, Ignored, ahk_exe \\steamapps\\
;GroupAdd, Ignored, ahk_exe \\Minecraft\\.*\\javaw.exe$

; Mapping impls
#InstallKeybdHook
#UseHook

For, Index, Element in Ignored
    GroupAdd, Ignored, % Element
For, Index, Element in Browser
    GroupAdd, Browser, % Element

SetKeyDelay 0

; From https://github.com/karakaram/alt-ime-ahk/blob/master/IME.ahk
ImeSet(SetSts, WinTitle="A")    {
    ControlGet,hwnd,HWND,,,%WinTitle%
    if    (WinActive(WinTitle))    {
        ptrSize := !A_PtrSize ? 4 : A_PtrSize
        VarSetCapacity(stGTI, cbSize:=4+4+(PtrSize*6)+16, 0)
        NumPut(cbSize, stGTI,  0, "UInt")   ;    DWORD   cbSize;
        hwnd := DllCall("GetGUIThreadInfo", Uint,0, Uint,&stGTI)
                 ? NumGet(stGTI,8+PtrSize,"UInt") : hwnd
    }

    return DllCall("SendMessage"
          , UInt, DllCall("imm32\ImmGetDefaultIMEWnd", Uint,hwnd)
          , UInt, 0x0283  ;Message : WM_IME_CONTROL
          ,  Int, 0x006   ;wParam  : IMC_SETOPENSTATUS
          ,  Int, SetSts) ;lParam  : 0 or 1
}

^q::Suspend, Toggle
^j::Send, {vkF3sc029}
!j::ImeSet(False)
+!j::ImeSet(True)

;;
#If DebugMode
F5::
    Reload
    Return

;;
#If WinActive("ahk_group Browser")
#Include, browser.ahk

;;
#If Not WinActive("ahk_group Ignored")
#Include, generic.ahk
