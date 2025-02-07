@@REM ********************************************************************************
@@REM  Copyright (c) 2018,2024 OFFIS e.V.
@@REM
@@REM  This program and the accompanying materials are made available under the
@@REM  terms of the Eclipse Public License 2.0 which is available at
@@REM  http://www.eclipse.org/legal/epl-2.0.
@@REM
@@REM  SPDX-License-Identifier: EPL-2.0
@@REM
@@REM  Contributors:
@@REM     Jörg Walter - initial implementation
@@REM  *******************************************************************************/
@@cd %~dp0 & %WINDIR%\system32\windowspowershell\v1.0\powershell.exe -Command Invoke-Expression $([String]::Join(';',(Get-Content %~nx0) -notmatch '^^@@.*$')) & goto :EOF

if ("$PWD" -match ".*\\etc$") {
	cd ..
}

if (-not (Test-Path "bin\sh.exe")) {
	$baseurl = "https://sourceforge.net/projects/fordiac/files/4diac-fbe"
	$release='2025-01'
	$releasehash='db64ce7b7a5cbb1ba7919c502f7318779447f7c5fca6fac0f750c7d1de5af4fd'

	$triplet="x86_64-w64-mingw32"
	$downloaddir="$Env:CGET_DOWNLOADS_DIR"
	if ("$downloaddir" -eq "") {
		$downloaddir="$PWD"
	}
	$installer="4diac-fbe-installer-v1-$triplet.zip"
	$installerhash='c2cb45de2b0bf0d1954152c136f697353929a7ba95ab55a89cfda5e668b8ebd5'
	if (-not (Test-Path "$downloaddir\$installer")) {
		$downloaddir="$Env:CGET_CACHE_DIR"
		if ("$downloaddir" -eq "") {
			$downloaddir="$PWD\download-cache"
		}
		$downloaddir="$downloaddir\sha256-$installerhash"
		cmd /c "mkdir ""$downloaddir"" 2>nul"
	}

	if (-not (Test-Path "$downloaddir\$installer")) {
		"Downloading $baseurl/installer/$installer/download..."
		Invoke-WebRequest -UserAgent "curl/7.54.1" "$baseurl/installer/$installer/download" -OutFile "$downloaddir\$installer"
	}

	if ((Get-FileHash "$downloaddir\$installer").Hash -ne "$installerhash") {
		"ERROR: Downloaded file does not match expected hash value. Maybe the download failed?"
		Read-Host -Prompt "Press Enter to exit"
		Move-Item -Force "$downloaddir\$installer" -Destination "$downloaddir\$installer.broken"
		exit 1
	}

	"Extracting installer environment..."
	cmd /c "rmdir /s /q installer 2> nul"
	cmd /c "mkdir installer"

	$shap = New-Object -com Shell.Application
	$src = $shap.NameSpace("$downloaddir\$installer")
	$dest = $shap.NameSpace("$PWD\installer")
	$dest.CopyHere($src.Items(), 0x510)

	cmd /c "rmdir /s /q bin 2> nul"
	cmd /c "mkdir bin"
	cmd /c "copy C:\Windows\system32\cmd.exe bin\cmd.exe > nul"

	installer\bin\busybox.exe --install installer\bin\
	installer\bin\env.exe PATH="$PWD/installer/bin" installer/bin/sh installer/etc/bootstrap/install.sh "$triplet" "$release" "$releasehash"
	if (-not $?) {
		""
		""
		Read-Host -Prompt "Installation failed. Press Enter to exit"
		exit 1
	}

	cmd /c "rmdir /s /q installer 2> nul"
}

""
""
Read-Host -Prompt "Installation successful. Press Enter to exit"
