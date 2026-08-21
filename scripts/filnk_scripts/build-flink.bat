@echo off
chcp 65001 >nul
setlocal

:: 이 파일이 scripts\flink_scripts\ 안에 있으므로 log_gen 루트까지 두 단계 위로 올라가야 함
set "ROOT=%~dp0..\.."
set "FLINK_DIR=%ROOT%\flink"

where mvn >nul 2>nul
if errorlevel 1 (
  echo ERROR: Maven mvn이 필요합니다. JDK 17 + Maven을 설치한 뒤 다시 실행하세요.
  exit /b 1
)

if not exist "%FLINK_DIR%" (
  echo ERROR: FLINK_DIR 경로를 찾을 수 없습니다: %FLINK_DIR%
  exit /b 1
)

echo [1/2] Build Flink application package
pushd "%FLINK_DIR%"
if errorlevel 1 (
  echo ERROR: pushd 실패, FLINK_DIR 확인 필요: %FLINK_DIR%
  exit /b 1
)

call mvn clean package
if errorlevel 1 (
  popd
  exit /b 1
)
popd

if not exist "%FLINK_DIR%\target\flink-silver.zip" (
  echo ERROR: Flink 배포 ZIP이 생성되지 않았습니다.
  exit /b 1
)

echo [2/2] Build complete
echo %FLINK_DIR%\target\flink-silver.zip

endlocal