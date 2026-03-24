@echo off
REM KATA-DRAW Windows EXE ビルドスクリプト
REM 使い方: build_windows.bat
REM 事前に Godot 4.6 のエディタをインストールし、エクスポート用テンプレートをダウンロードしてください。
REM （エディタ: エディタ → エクスポート用テンプレートの管理 からダウンロード）

set PROJECT_DIR=%~dp0
set OUTPUT_EXE=%PROJECT_DIR%KATA-DRAW.exe
REM 別名で出力する場合: set OUTPUT_EXE=%PROJECT_DIR%KatadrawShapeEditor.exe

REM Godot のパス（環境に合わせて変更）
REM 例: 標準インストール
set GODOT=godot

REM 例: 直接パスを指定する場合（コメントを外して使用）
REM set GODOT="C:\Program Files\Godot\Godot_v4.6-stable_win64.exe"

echo プロジェクト: %PROJECT_DIR%
echo 出力先: %OUTPUT_EXE%
echo.

%GODOT% --path "%PROJECT_DIR%" --export-release "Windows Desktop" "%OUTPUT_EXE%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ビルド成功: %OUTPUT_EXE%
) else (
    echo.
    echo ビルド失敗。以下を確認してください:
    echo - Godot 4.6 がインストールされ、PATH に含まれている
    echo - エディタで「エクスポート用テンプレートの管理」から Windows テンプレートをダウンロード済み
    exit /b 1
)
