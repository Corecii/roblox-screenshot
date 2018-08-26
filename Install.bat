npm install
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /V "%~dp0\node_modules\screenshot-desktop\lib\win32\screenCapture.exe" /T REG_SZ /D ~DPIUNAWARE /F
REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /V "%~dp0\node_modules\screenshot-desktop\lib\win32\screenCapture.exe" /T REG_SZ /D ~DPIUNAWARE /F