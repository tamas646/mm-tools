$ErrorActionPreference = "Stop"
if($PSDefaultParameterValues -ne $null) { $PSDefaultParameterValues['*:Encoding'] = 'utf8' }
if($PSScriptRoot -eq $null) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
[console]::ForegroundColor = 'blue'
cd "$($PSScriptRoot)"

$MM_DIR = "./migrations/"
$MM_DBPTN = '^(?!mysql$|sys$|information_schema$|performance_schema$|phpmyadmin$)'

$TEST_MIGRATE = $False
if($args[0] -eq "/t")
{
    $TEST_MIGRATE = $True
}

if(!(Test-Path -Path $MM_DIR))
{
    mkdir "$($MM_DIR)" | Out-Null
}
if(!(Test-Path -Path $MM_DIR/.info))
{
    $LAST = ".php"
}
else
{
    $LAST = (type "$($MM_DIR)/.info")
}

if(!(Test-Path -Path "config.php"))
{
    Write-Host "Creating config file..." -f 'darkblue'
    $r_host = Read-Host 'MySQL host (default: localhost)'
    if("$r_host" -eq "")
    {
        $r_host = 'localhost'
    }
    $r_user = Read-Host 'MySQL user (default: root)'
    if("$r_user" -eq "")
    {
        $r_user = 'root'
    }
    $r_password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'MySQL password' -AsSecureString)))
    [System.IO.File]::WriteAllLines("config.php", "<?php

define('MYSQL_HOST', '$($r_host)');
define('MYSQL_USER', '$($r_user)');
define('MYSQL_PASSWORD', '$($r_password)');
", (New-Object System.Text.UTF8Encoding $False))
    Write-Host "Config file created" -f 'darkblue'
    echo ""
}

$MYSQLUSER = (php -r "include 'config.php';echo MYSQL_USER;")
if($LastExitCode -ne 0) { exit $LastExitCode }
$MYSQLPASSWORD = (php -r "include 'config.php';echo MYSQL_PASSWORD;")
if($LastExitCode -ne 0) { exit $LastExitCode }
$MYSQLHOST = (php -r "include 'config.php';echo MYSQL_HOST;")
if($LastExitCode -ne 0) { exit $LastExitCode }

attrib /d +H "$($MM_DIR)/.*"
if($LastExitCode -ne 0) { exit $LastExitCode }
$PHPFILES = @()
foreach($line in @(ls "$($MM_DIR)"))
{
    if($line.Name -ne "README.md")
    {
        $PHPFILES += ,$line
    }
}

function create_backup
{
    $databases = (php -r "include 'config.php';`$s='';`$q=(new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD))->query('SHOW DATABASES');while(`$d=`$q->fetch_assoc())if(preg_match('/$($MM_DBPTN)/',`$d['Database']))`$s.=`$d['Database'].' ';echo trim(`$s);")
    if($LastExitCode -ne 0) { exit 1 }
    if(Test-Path -Path "$($MM_DIR)/.backup/")
    {
        rm -r -fo "$($MM_DIR)/.backup/"
    }
    mkdir "$($MM_DIR)/.backup/" | Out-Null
    mkdir "$($MM_DIR)/.backup/databases/" | Out-Null
    mkdir "$($MM_DIR)/.backup/files/" | Out-Null
    Write-Host "Backing up files..." -f 'darkgray'
    foreach($filename in Get-ChildItem -Path "./" -Filter ".gitignore" -Recurse -Force)
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
                $dirname = "$($filename.Directory -replace [regex]::Escape($PSScriptRoot))"
                if(!(Test-Path -Path "$($filename.Directory)/$($line)"))
                {
                    Write-Host "Warning: '$($dirname)/$($line)' not found and will be ignored" -f 'darkgray'
                    continue
                }
                if(!(Test-Path -Path (Split-Path "$($MM_DIR)/.backup/files/$($dirname)/$($line)" -Parent)))
                {
                    New-Item (Split-Path "$($MM_DIR)/.backup/files/$($dirname)/$($line)" -Parent) -ItemType Directory | Out-Null
                }

                cp -Recurse -Force "$($filename.Directory)/$($line)" "$($MM_DIR)/.backup/files/$($dirname)/$($line)"
            }
        }
    }
    if("$($databases)" -ne "")
    {
        $databases = $databases.Split(" ")
        for($j = 0; $j -lt $databases.Length; ++$j)
        {
            Write-Host "Backing up ``$($databases[$j])``..." -f 'darkgray'
            php -r "define(\`"DB_USER\`",'$($MYSQLUSER)');
                define(\`"DB_PASSWORD\`",'$($MYSQLPASSWORD)');
                define(\`"DB_NAME\`",'$($databases[$j])');
                define(\`"DB_HOST\`",'$($MYSQLHOST)');
                define(\`"BACKUP_DIR\`",'$($MM_DIR)/.backup/databases');
                define(\`"TABLES\`",'*');
                define(\`"BACKUP_TRIGGERS\`",true);
                define(\`"CHARSET\`",'utf8mb4');
                define(\`"GZIP_BACKUP_FILE\`",false);
                define(\`"DISABLE_FOREIGN_KEY_CHECKS\`",true);
                define(\`"BATCH_SIZE\`",1000);
                class Backup_Database{var `$host;var `$username;var `$passwd;var `$dbName;var `$charset;var `$conn;var `$backupDir;var `$backupFile;var `$gzipBackupFile;var `$output;var `$disableForeignKeyChecks;var `$batchSize;public function __construct(`$host,`$username,`$passwd,`$dbName,`$charset='utf8'){`$this->host=`$host;`$this->username=`$username;`$this->passwd=`$passwd;`$this->dbName=`$dbName;`$this->charset=`$charset;`$this->conn=`$this->initializeDatabase();`$this->backupDir=BACKUP_DIR?BACKUP_DIR:'.';`$this->backupFile=`$this->dbName.'.sql';`$this->gzipBackupFile=defined('GZIP_BACKUP_FILE')?GZIP_BACKUP_FILE:true;`$this->disableForeignKeyChecks=defined('DISABLE_FOREIGN_KEY_CHECKS')?DISABLE_FOREIGN_KEY_CHECKS:true;`$this->batchSize=defined('BATCH_SIZE')?BATCH_SIZE:1000;`$this->output='';}protected function initializeDatabase(){try{`$conn=mysqli_connect(`$this->host,`$this->username,`$this->passwd,`$this->dbName);if(mysqli_connect_errno()){throw new Exception('ERROR connecting database: '.mysqli_connect_error());die(55);}}catch(Exception `$e){print_r(`$e->getMessage());die(55);}return `$conn;}public function backupTables(`$tables='*'){try{if(`$tables=='*'){`$tables=array();`$result=mysqli_query(`$this->conn,'SHOW TABLES');while(`$row=mysqli_fetch_row(`$result)){`$tables[]=`$row[0];}}else{`$tables=is_array(`$tables)?`$tables:explode(',',str_replace(' ','',`$tables));}`$sql='CREATE DATABASE IF NOT EXISTS ``'.`$this->dbName.\`"``;\n\n\`";`$sql.='USE ``'.`$this->dbName.\`"``;\n\n\`";if(`$this->disableForeignKeyChecks===true){`$sql.=\`"SET foreign_key_checks = 0;\n\n\`";}foreach(`$tables as `$table){`$this->obfPrint(\`"Backing up ``\`".`$table.\`"`` table...\`".str_repeat('.',50-strlen(`$table)),0,0);`$sql.='DROP TABLE IF EXISTS ``'.`$table.'``;';`$row=mysqli_fetch_row(mysqli_query(`$this->conn,'SHOW CREATE TABLE ``'.`$table.'``'));`$sql.=\`"\n\n\`".`$row[1].\`";\n\n\`";`$row=mysqli_fetch_row(mysqli_query(`$this->conn,'SELECT COUNT(*) FROM ``'.`$table.'``'));`$numRows=`$row[0];`$numBatches=intval(`$numRows/`$this->batchSize)+1;for(`$b=1;`$b<=`$numBatches;`$b++){`$query='SELECT * FROM ``'.`$table.'`` LIMIT '.(`$b*`$this->batchSize-`$this->batchSize).','.`$this->batchSize;`$result=mysqli_query(`$this->conn,`$query);`$realBatchSize=mysqli_num_rows(`$result);`$numFields=mysqli_num_fields(`$result);if(`$realBatchSize!==0){`$sql.='INSERT INTO ``'.`$table.'`` VALUES ';for(`$i=0;`$i<`$numFields;`$i++){`$rowCount=1;while(`$row=mysqli_fetch_row(`$result)){`$sql.='(';for(`$j=0;`$j<`$numFields;`$j++){if(isset(`$row[`$j])){`$row[`$j]=addslashes(`$row[`$j]);`$row[`$j]=str_replace(\`"\n\`",\`"\\n\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\r\`",\`"\\r\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\f\`",\`"\\f\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\t\`",\`"\\t\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\v\`",\`"\\v\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\a\`",\`"\\a\`",`$row[`$j]);`$row[`$j]=str_replace(\`"\b\`",\`"\\b\`",`$row[`$j]);if(`$row[`$j]=='true'or `$row[`$j]=='false'or preg_match('/^-?[0-9]+`$/',`$row[`$j])or `$row[`$j]=='NULL'or `$row[`$j]=='null'){`$sql.=`$row[`$j];}else{`$sql.='\`"'.`$row[`$j].'\`"';}}else{`$sql.='NULL';}if(`$j<(`$numFields-1)){`$sql.=',';}}if(`$rowCount==`$realBatchSize){`$rowCount=0;`$sql.=\`");\n\`";}else{`$sql.=\`"),\n\`";}`$rowCount++;}}`$this->saveFile(`$sql);`$sql='';}}`$sql.=\`"\n\n\`";`$this->obfPrint('OK');}if(`$this->disableForeignKeyChecks===true){`$sql.=\`"SET foreign_key_checks = 1;\n\`";}`$this->saveFile(`$sql);if(defined('BACKUP_TRIGGERS')&&BACKUP_TRIGGERS===true){`$sql=`$this->backupTriggers();`$this->saveFile(`$sql);}if(`$this->gzipBackupFile){`$this->gzipBackupFile();}else{`$this->obfPrint('Backup file succesfully saved to '.`$this->backupDir.'/'.`$this->backupFile,1,1);}}catch(Exception `$e){print_r(`$e->getMessage());return false;}return true;}protected function backupTriggers(){`$sql=\`"\n\n\`";`$result=`$this->conn->query('SHOW TRIGGERS');while(`$row=`$result->fetch_assoc()){`$this->obfPrint(\`"Backing up \`".`$row['Trigger'].\`" trigger...\`".str_repeat('.',50-strlen(`$row['Trigger'])),0,0);`$sql.='DROP TRIGGER IF EXISTS '.`$row['Trigger'].';';`$sql.=\`"\n\n\`";`$sql.='CREATE TRIGGER '.`$row['Trigger'].' '.`$row['Timing'].' '.`$row['Event'].' ON ``'.`$row['Table'].'`` FOR EACH ROW'.\`"\n\t\t\`".`$row['Statement'].';';`$sql.=\`"\n\n\n\`";`$this->obfPrint(\`"OK\`");}`$result->close();return `$sql;}protected function saveFile(&`$sql){if(!`$sql)return false;try{if(!file_exists(`$this->backupDir)){mkdir(`$this->backupDir,0777,true);}file_put_contents(`$this->backupDir.'/'.`$this->backupFile,`$sql,FILE_APPEND|LOCK_EX);}catch(Exception `$e){print_r(`$e->getMessage());return false;}return true;}protected function gzipBackupFile(`$level=9){if(!`$this->gzipBackupFile){return true;}`$source=`$this->backupDir.'/'.`$this->backupFile;`$dest=`$source.'.gz';`$this->obfPrint('Gzipping backup file to '.`$dest.'... ',1,0);`$mode='wb'.`$level;if(`$fpOut=gzopen(`$dest,`$mode)){if(`$fpIn=fopen(`$source,'rb')){while(!feof(`$fpIn)){gzwrite(`$fpOut,fread(`$fpIn,1024*256));}fclose(`$fpIn);}else{return false;}gzclose(`$fpOut);if(!unlink(`$source)){return false;}}else{return false;}`$this->obfPrint('OK');return `$dest;}public function obfPrint(`$msg='',`$lineBreaksBefore=0,`$lineBreaksAfter=1){if(!`$msg){return false;}if(`$msg!='OK'and `$msg!='KO'){`$msg=date(\`"Y-m-d H:i:s\`").' - '.`$msg;}`$output='';if(php_sapi_name()!=\`"cli\`"){`$lineBreak=\`"<br />\`";}else{`$lineBreak=\`"\n\`";}if(`$lineBreaksBefore>0){for(`$i=1;`$i<=`$lineBreaksBefore;`$i++){`$output.=`$lineBreak;}}`$output.=`$msg;if(`$lineBreaksAfter>0){for(`$i=1;`$i<=`$lineBreaksAfter;`$i++){`$output.=`$lineBreak;}}`$this->output.=str_replace('<br />','\n',`$output);echo `$output;if(php_sapi_name()!=\`"cli\`"){if(ob_get_level()>0){ob_flush();}}`$this->output.=\`" \`";flush();}public function getOutput(){return `$this->output;}}error_reporting(E_ALL);set_time_limit(900);if(php_sapi_name()!=\`"cli\`"){echo '<div style=\`"font-family: monospace;\`">';}`$backupDatabase=new Backup_Database(DB_HOST,DB_USER,DB_PASSWORD,DB_NAME,CHARSET);`$result=`$backupDatabase->backupTables(TABLES,BACKUP_DIR)?'OK':'KO';`$backupDatabase->obfPrint('Backup result: '.`$result,1);if(`$result=='KO')exit(55);`$output=`$backupDatabase->getOutput();if(php_sapi_name()!=\`"cli\`"){echo '</div>';}" | Out-Null
            if($LastExitCode -ne 0) { exit 1 }
        }
    }
}

function restore_backup
{
    Write-Host "Restoring files..." -f 'darkgray'
    if(Test-Path -Path "$($MM_DIR)/.backup/files/")
    {
        foreach($filename in Get-ChildItem -Path "./" -Filter ".gitignore" -Recurse -Force)
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

                    if(!(Test-Path -Path "$($MM_DIR)/.backup/files/$($dirname)/$($line)"))
                    {
                        continue
                    }
                    if(!(Test-Path -Path (Split-Path "$($filename.Directory)/$($line)" -Parent)))
                    {
                        New-Item (Split-Path "$($filename.Directory)/$($line)" -Parent) -ItemType Directory | Out-Null
                    }

                    cp -Recurse -Force "$($MM_DIR)/.backup/files/$($dirname)/$($line)" (Split-Path "$($filename.Directory)/$($line)" -Parent)
                }
            }
        }
    }
    php -r "include 'config.php';`$m=new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD);`$q=`$m->query('SHOW DATABASES');while(`$d=`$q->fetch_assoc())if(preg_match('/$($MM_DBPTN)/',`$d['Database']))`$m->query('DROP DATABASE ``'.`$d['Database'].'``');"
    if($LastExitCode -ne 0) { exit $LastExitCode }
    if(Test-Path "$($MM_DIR)/.backup/databases/")
    {
        $databases = @(Get-ChildItem "$($MM_DIR)/.backup/databases/*.sql")
        for($j = 0; $j -lt $databases.Length; ++$j)
        {
            Write-Host "Restoring ``$($databases[$j].Name.Substring(0,$databases[$j].Name.Length-4))``..." -f 'darkgray'
            php -r "define(\`"DB_USER\`",'$($MYSQLUSER)');
                define(\`"DB_PASSWORD\`",'$($MYSQLPASSWORD)');
                define(\`"DB_NAME\`",'$($databases[$j].Name.Substring(0,$databases[$j].Name.Length-4))');
                define(\`"DB_HOST\`",'$($MYSQLHOST)');
                define(\`"BACKUP_DIR\`",'$($MM_DIR)/.backup/databases/');
                define(\`"BACKUP_FILE\`",'$($databases[$j].Name)');
                define(\`"CHARSET\`",'utf8mb4');
                define(\`"DISABLE_FOREIGN_KEY_CHECKS\`",true);
                class Restore_Database{var `$host;var `$username;var `$passwd;var `$dbName;var `$charset;var `$conn;var `$disableForeignKeyChecks;function __construct(`$host,`$username,`$passwd,`$dbName,`$charset='utf8'){`$this->host=`$host;`$this->username=`$username;`$this->passwd=`$passwd;`$this->dbName=`$dbName;`$this->charset=`$charset;`$this->disableForeignKeyChecks=defined('DISABLE_FOREIGN_KEY_CHECKS')?DISABLE_FOREIGN_KEY_CHECKS:true;`$this->conn=`$this->initializeDatabase();`$this->backupDir=defined('BACKUP_DIR')?BACKUP_DIR:'.';`$this->backupFile=defined('BACKUP_FILE')?BACKUP_FILE:null;}function __destructor(){if(`$this->disableForeignKeyChecks===true){mysqli_query(`$this->conn,'SET foreign_key_checks = 1');}}protected function initializeDatabase(){try{`$conn=mysqli_connect(`$this->host,`$this->username,`$this->passwd);if(mysqli_connect_errno()){throw new Exception('ERROR connecting database: '.mysqli_connect_error());die(55);}if(`$this->disableForeignKeyChecks===true){mysqli_query(`$conn,'SET foreign_key_checks = 0');}}catch(Exception `$e){print_r(`$e->getMessage());die(55);}return `$conn;}public function restoreDb(){try{`$sql='';`$multiLineComment=false;`$backupDir=`$this->backupDir;`$backupFile=`$this->backupFile;`$backupFileIsGzipped=substr(`$backupFile,-3,3)=='.gz'?true:false;if(`$backupFileIsGzipped){if(!`$backupFile=`$this->gunzipBackupFile()){throw new Exception(\`"ERROR: couldn't gunzip backup file \`".`$backupDir.'/'.`$backupFile);}}`$handle=fopen(`$backupDir.'/'.`$backupFile,\`"r\`");if(`$handle){while((`$line=fgets(`$handle))!==false){if(strlen(ltrim(rtrim(`$line)))>1){`$lineIsComment=false;if(preg_match('/^\/\*/',`$line)){`$multiLineComment=true;`$lineIsComment=true;}if(`$multiLineComment or preg_match('/^\/\//',`$line)){`$lineIsComment=true;}if(!`$lineIsComment){`$sql.=`$line;if(preg_match('/;`$/',`$line)){if(mysqli_query(`$this->conn,`$sql)){if(preg_match('/^CREATE TABLE ``([^``]+)``/i',`$sql,`$tableName)){`$this->obfPrint(\`"Table succesfully created: ``\`".`$tableName[1].\`"``\`");}else if(preg_match('/^CREATE TRIGGER ([^ ]+)/i',`$sql,`$triggerName)){`$this->obfPrint(\`"Trigger succesfully created: \`".`$triggerName[1]);}`$sql='';}else{throw new Exception(\`"ERROR: SQL execution error: \`".mysqli_error(`$this->conn));}}}else if(preg_match('/\*\/`$/',`$line)){`$multiLineComment=false;}}}fclose(`$handle);}else{throw new Exception(\`"ERROR: couldn't open backup file \`".`$backupDir.'/'.`$backupFile);}}catch(Exception `$e){print_r(`$e->getMessage());return false;}if(`$backupFileIsGzipped){unlink(`$backupDir.'/'.`$backupFile);}return true;}protected function gunzipBackupFile(){`$bufferSize=4096;`$error=false;`$source=`$this->backupDir.'/'.`$this->backupFile;`$dest=`$this->backupDir.'/'.date(\`"Ymd_His\`",time()).'_'.substr(`$this->backupFile,0,-3);`$this->obfPrint('Gunzipping backup file '.`$source.'... ',1,1);if(file_exists(`$dest)){if(!unlink(`$dest)){return false;}}if(!`$srcFile=gzopen(`$this->backupDir.'/'.`$this->backupFile,'rb')){return false;}if(!`$dstFile=fopen(`$dest,'wb')){return false;}while(!gzeof(`$srcFile)){if(!fwrite(`$dstFile,gzread(`$srcFile,`$bufferSize))){return false;}}fclose(`$dstFile);gzclose(`$srcFile);return str_replace(`$this->backupDir.'/','',`$dest);}public function obfPrint(`$msg='',`$lineBreaksBefore=0,`$lineBreaksAfter=1){if(!`$msg){return false;}`$msg=date(\`"Y-m-d H:i:s\`").' - '.`$msg;`$output='';if(php_sapi_name()!=\`"cli\`"){`$lineBreak=\`"<br />\`";}else{`$lineBreak=\`"\n\`";}if(`$lineBreaksBefore>0){for(`$i=1;`$i<=`$lineBreaksBefore;`$i++){`$output.=`$lineBreak;}}`$output.=`$msg;if(`$lineBreaksAfter>0){for(`$i=1;`$i<=`$lineBreaksAfter;`$i++){`$output.=`$lineBreak;}}if(php_sapi_name()==\`"cli\`"){`$output.=\`"\n\`";}echo `$output;if(php_sapi_name()!=\`"cli\`"){ob_flush();}flush();}}error_reporting(E_ALL);set_time_limit(900);if(php_sapi_name()!=\`"cli\`"){echo '<div style=\`"font-family: monospace;\`">';}`$restoreDatabase=new Restore_Database(DB_HOST,DB_USER,DB_PASSWORD,DB_NAME);`$result=`$restoreDatabase->restoreDb(BACKUP_DIR,BACKUP_FILE)?'OK':'KO';`$restoreDatabase->obfPrint(\`"Restoration result: \`".`$result,1);if(`$result=='KO')exit(55);if(php_sapi_name()!=\`"cli\`"){echo '</div>';}" | Out-Null
            if($LastExitCode -ne 0) { exit $LastExitCode }
        }
    }
}

function delete_backup
{
    if(Test-Path -Path "$($MM_DIR)/.backup/")
    {
        rm -r -fo "$($MM_DIR)/.backup/"
    }
}

for($i = 0; $i -lt $PHPFILES.Length; ++$i)
{
    if($PHPFILES[$i].Name -gt $LAST)
    {
        create_backup

        if($TEST_MIGRATE)
        {
            echo ""
            Write-Host "Running test migration '$($PHPFILES[$i].Name)'..." -f 'darkblue'
            [console]::ForegroundColor = 'white'
            php -r "require '$($MM_DIR)/.mm_functions.php'; require 'config.php'; require '$($MM_DIR)/$($PHPFILES[$i].Name)';"
            $exitcode = $LastExitCode
            [console]::ForegroundColor = 'blue'
            echo ""
            if($exitcode -ne 0)
            {
                Write-Host -NoNewline "Test result: " -f 'darkblue'
                Write-Host "Failed" -f 'darkred'
            }
            else
            {
                
                Write-Host -NoNewline "Test result: " -f 'darkblue'
                Write-Host "Done" -f 'darkgreen'
            }
            echo ""
            Write-Host -NoNewline "Press enter to restore backup..." -f 'darkblue'
            Read-Host
            echo ""
            restore_backup
            delete_backup
            [console]::ForegroundColor = 'white'
            exit $exitcode
        }

        $name = $PHPFILES[$i].Name
        echo ""
        Write-Host "Running migration '$($PHPFILES[$i].Name)'..." -f 'darkblue'
        [console]::ForegroundColor = 'white'
        php -r "require '$($MM_DIR)/.mm_functions.php'; require 'config.php'; require '$($MM_DIR)/$($PHPFILES[$i].Name)';"
        $exitcode = $LastExitCode
        [console]::ForegroundColor = 'blue'
        if($exitcode -ne 0)
        {
            echo ""
            Write-Host "Failed" -f 'darkred'
            echo ""
            restore_backup
            delete_backup
            [console]::ForegroundColor = 'white'
            exit $exitcode
        }
        $LAST = $name
        echo $LAST > "$($MM_DIR)/.info"

        delete_backup
    }
}

echo ""
Write-Host "Done" -f 'darkgreen'
echo ""
[console]::ForegroundColor = 'white'
