$ErrorActionPreference = "Stop"
if($PSDefaultParameterValues -ne $null) { $PSDefaultParameterValues['*:Encoding'] = 'utf8' }
if($PSScriptRoot -eq $null) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$MM_DIR = "$($PSScriptRoot)/migrations/"
$MM_DBPTN = '^(?!mysql$|sys$|information_schema$|performance_schema$|phpmyadmin$)'

[console]::ForegroundColor = 'blue'

Write-Host "Are you sure you want to reset your repository? " -NoNewLine
Write-Host "[y/N] " -f 'darkblue' -NoNewLine
[console]::ForegroundColor = 'darkblue'
$answer = $Host.UI.ReadLine()
[console]::ForegroundColor = 'blue'
if("$answer" -ne "y" -or "$answer" -ne "Y")
{
    Write-Host "Aborting..." -f 'darkblue'
    [console]::ForegroundColor = 'white'
    exit 3
}

Write-Host ""

if(Test-Path -Path "$($PSScriptRoot)/config.php")
{
    Write-Host "Deleting databases..." -f 'darkred'
    php -r "include '$($PSScriptRoot)/config.php';`$m=new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD);`$q=`$m->query('SHOW DATABASES');while(`$d=`$q->fetch_assoc())if(preg_match('/$($MM_DBPTN)/',`$d['Database']))`$m->query('DROP DATABASE ``'.`$d['Database'].'``');"
    if($LastExitCode -ne 0) { exit $LastExitCode }
}
else
{
    Write-Host "Warning: Cannot delete databases: config.php not found" -f 'darkgray'
}

Write-Host "Deleting files..." -f 'darkred'
foreach($filename in Get-ChildItem -Path "$($PSScriptRoot)/" -Filter ".gitignore" -Recurse -Force)
{
    if($filename.FullName -eq (Resolve-Path -Path "$($MM_DIR)/.gitignore").Path)
    {
        continue
    }
    foreach($line in Get-Content "$($filename.FullName)")
    {
        $line = $line.Trim()
        if($line -ne "")
        {
            if(Test-Path -Path "$($filename.Directory)/$($line)" -PathType Container)
            {
                rm -r -fo "$($filename.Directory)/$($line)"
            }
            elseif(Test-Path -Path "$($filename.Directory)/$($line)" -PathType Leaf)
            {
                rm -fo "$($filename.Directory)/$($line)"
            }
        }
    }
}

if(Test-Path -Path "$($MM_DIR)/.info")
{
    Write-Host "Deleting info file..." -f 'darkred'
    rm -fo "$($MM_DIR)/.info"
}

if(Test-Path -Path "$($MM_DIR)/.backup/")
{
    Write-Host "Deleting backup folder..." -f 'darkred'
    rm -r -fo "$($MM_DIR)/.backup/"
}

[console]::ForegroundColor = 'white'
