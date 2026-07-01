$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$r='wmjwmj100/gradence-code-install';$a='gradence-code-windows-x64.zip'
$d=Join-Path $env:LOCALAPPDATA 'Programs\GradenceCode'
$t=Join-Path $env:TEMP ('gradence-code-'+[guid]::NewGuid().ToString('N'))
$z=Join-Path $t $a;$s=Join-Path $t "$a.sha256";$x=Join-Path $t 'x'
New-Item -ItemType Directory -Force -Path $t|Out-Null
$b="https://github.com/$r/releases/latest/download"
Invoke-WebRequest "$b/$a" -OutFile $z -UseBasicParsing
Invoke-WebRequest "$b/$a.sha256" -OutFile $s -UseBasicParsing
$e=([regex]::Match((Get-Content $s -Raw),'[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
$h=(Get-FileHash $z -Algorithm SHA256).Hash.ToLowerInvariant()
if($e -ne $h){throw 'Checksum mismatch'}
Expand-Archive $z -DestinationPath $x -Force
New-Item -ItemType Directory -Force -Path $d|Out-Null
Copy-Item (Get-ChildItem $x -Recurse -Filter wecode.exe|Select-Object -First 1).FullName (Join-Path $d 'wecode.exe') -Force
try{Unblock-File (Join-Path $d 'wecode.exe')}catch{}
$p=[Environment]::GetEnvironmentVariable('Path','User')
if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',(($p,$d|?{$_}) -join ';'),'User')}
$env:Path="$d;$env:Path"
Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
wecode --version