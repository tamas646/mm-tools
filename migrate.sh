#!/bin/bash
set -e
export LC_ALL=C
echo -n -e "\e[34m"
function reset_colors { echo -n -e "\e[0m" ; }
trap reset_colors EXIT
cd "`dirname "$0"`"

MM_DIR="./migrations/"
MM_DBPTN='^(?!mysql$|sys$|information_schema$|performance_schema$|phpmyadmin$)'

TEST_MIGRATE=false
if [[ "$1" == "-t" ]]
then
	TEST_MIGRATE=true
fi

if [[ "$OSTYPE" == "msys" ]]
then
	reset_colors
	echo "This script is not capable of running perfectly on Windows."
	echo -e "Please run \e[1mmigrate.bat\e[22m or \e[1mmigrate.ps1\e[22m instead."
	echo ""
	echo -n "Press any key to continue..." ; read
	exit 100
fi

if [[ ! -d "$MM_DIR" ]]
then
	mkdir "$MM_DIR"
fi
if [[ ! -f "${MM_DIR}/.info" ]]
then
	LAST=".php"
else
	LAST=`cat "${MM_DIR}/.info"`
fi

if [[ ! -f "config.php" ]]
then
	echo -e "\e[1mCreating config file...\e[22m"
	echo -n "MySQL host (default: localhost): " ; read r_host
	if [ "$r_host" = "" ]
	then
		r_host='localhost'
	fi
	echo -n "MySQL user (default: root): " ; read r_user
	if [[ "$r_user" == "" ]]
	then
		r_user='root'
	fi
	echo -n "MySQL password: " ; read -s r_password ; echo ""
	echo -n "<?php

define('MYSQL_HOST', '$(echo $r_host)');
define('MYSQL_USER', '$(echo $r_user)');
define('MYSQL_PASSWORD', '$(echo $r_password)');
" > "config.php"
	echo ""
	echo -e "\e[1mConfig file created\e[22m"
	echo ""
fi

MYSQLUSER=`php -r "include 'config.php';echo MYSQL_USER;"`
MYSQLPASSWORD=`php -r "include 'config.php';echo MYSQL_PASSWORD;"`
MYSQLHOST=`php -r "include 'config.php';echo MYSQL_HOST;"`

i=0
while read line
do
	if [[ "$line" != "README.md" ]]
	then
		PHPFILES[$i]="$line"
	fi
	i=$((i+1))
done < <(ls "$MM_DIR")

function create_backup {
	local databases=`php -r "include 'config.php';\\\$s='';\\\$q=(new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD))->query('SHOW DATABASES');while(\\\$d=\\\$q->fetch_assoc())if(preg_match('/${MM_DBPTN}/',\\\$d['Database']))\\\$s.=\\\$d['Database'].' ';echo trim(\\\$s);"`
	if [[ -d "${MM_DIR}/.backup/" ]]
	then
		rm -R "${MM_DIR}/.backup/"
	fi
	mkdir -p "${MM_DIR}/.backup/databases/"
	mkdir -p "${MM_DIR}/.backup/files/"
	echo -e "\e[90mBacking up files...\e[34m"
	while IFS='' read -r -d '' filename
	do
		if [[ "$(realpath "$filename")" == "$(realpath "${MM_DIR}/.gitignore")" ]]
		then
			continue
		fi
		while read -r line
		do
			local line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
			if [[ "$line" != "" ]]
			then
				if [[ ! -f "`dirname "$filename"`/$line" && ! -d "`dirname "$filename"`/$line" ]]
				then
					echo -e "\e[90m\e[1mWarning: \e[22m'`dirname "$filename"`/$line' not found and will be ignored\e[34m"
					continue
				fi
				if [[ ! -d "`dirname "${MM_DIR}/.backup/files/$(dirname "$filename")/$line"`" ]]
				then
					mkdir -p "`dirname "${MM_DIR}/.backup/files/$(dirname "$filename")/$line"`"
				fi

				if [[ -d "`dirname "$filename"`/$line" ]]
				then
					cp -R "`dirname "$filename"`/$line" "${MM_DIR}/.backup/files/`dirname "$filename"`/`dirname $line`"
				else
					cp -R "`dirname "$filename"`/$line" "${MM_DIR}/.backup/files/`dirname "$filename"`/$line"
				fi
			fi
		done < "$filename"
	done < <(find "./" -type f -name ".gitignore" -print0)
	if [[ "$databases" != "" ]]
	then
		local databases=(`echo "$databases"`)
		local j=0
		while [[ $j < ${#databases[@]} ]]
		do
			echo -e "\e[90mBacking up \``echo ${databases[$j]}`\`...\e[34m"
			if [[ -f "${MM_DIR}/.backup/databases/${databases[$j]}.sql" ]]
			then
				rm "${MM_DIR}/.backup/databases/${databases[$j]}.sql"
			fi
			php -r "define(\"DB_USER\",'${MYSQLUSER}');
				define(\"DB_PASSWORD\",'${MYSQLPASSWORD}');
				define(\"DB_NAME\",'${databases[$j]}');
				define(\"DB_HOST\",'${MYSQLHOST}');
				define(\"BACKUP_DIR\",'${MM_DIR}/.backup/databases/');
				define(\"TABLES\",'*');
				define(\"BACKUP_TRIGGERS\",true);
				define(\"CHARSET\",'utf8mb4');
				define(\"GZIP_BACKUP_FILE\",false);
				define(\"DISABLE_FOREIGN_KEY_CHECKS\",true);
				define(\"BATCH_SIZE\",1000);
				class Backup_Database{var \$host;var \$username;var \$passwd;var \$dbName;var \$charset;var \$conn;var \$backupDir;var \$backupFile;var \$gzipBackupFile;var \$output;var \$disableForeignKeyChecks;var \$batchSize;public function __construct(\$host,\$username,\$passwd,\$dbName,\$charset='utf8'){\$this->host=\$host;\$this->username=\$username;\$this->passwd=\$passwd;\$this->dbName=\$dbName;\$this->charset=\$charset;\$this->conn=\$this->initializeDatabase();\$this->backupDir=BACKUP_DIR?BACKUP_DIR:'.';\$this->backupFile=\$this->dbName.'.sql';\$this->gzipBackupFile=defined('GZIP_BACKUP_FILE')?GZIP_BACKUP_FILE:true;\$this->disableForeignKeyChecks=defined('DISABLE_FOREIGN_KEY_CHECKS')?DISABLE_FOREIGN_KEY_CHECKS:true;\$this->batchSize=defined('BATCH_SIZE')?BATCH_SIZE:1000;\$this->output='';}protected function initializeDatabase(){try{\$conn=mysqli_connect(\$this->host,\$this->username,\$this->passwd,\$this->dbName);if(mysqli_connect_errno()){throw new Exception('ERROR connecting database: '.mysqli_connect_error());die(55);}}catch(Exception \$e){print_r(\$e->getMessage());die(55);}return \$conn;}public function backupTables(\$tables='*'){try{if(\$tables=='*'){\$tables=array();\$result=mysqli_query(\$this->conn,'SHOW TABLES');while(\$row=mysqli_fetch_row(\$result)){\$tables[]=\$row[0];}}else{\$tables=is_array(\$tables)?\$tables:explode(',',str_replace(' ','',\$tables));}\$sql='CREATE DATABASE IF NOT EXISTS \`'.\$this->dbName.\"\`;\\n\\n\";\$sql.='USE \`'.\$this->dbName.\"\`;\\n\\n\";if(\$this->disableForeignKeyChecks===true){\$sql.=\"SET foreign_key_checks = 0;\\n\\n\";}foreach(\$tables as \$table){\$this->obfPrint(\"Backing up \`\".\$table.\"\` table...\".str_repeat('.',50-strlen(\$table)),0,0);\$sql.='DROP TABLE IF EXISTS \`'.\$table.'\`;';\$row=mysqli_fetch_row(mysqli_query(\$this->conn,'SHOW CREATE TABLE \`'.\$table.'\`'));\$sql.=\"\\n\\n\".\$row[1].\";\\n\\n\";\$row=mysqli_fetch_row(mysqli_query(\$this->conn,'SELECT COUNT(*) FROM \`'.\$table.'\`'));\$numRows=\$row[0];\$numBatches=intval(\$numRows/\$this->batchSize)+1;for(\$b=1;\$b<=\$numBatches;\$b++){\$query='SELECT * FROM \`'.\$table.'\` LIMIT '.(\$b*\$this->batchSize-\$this->batchSize).','.\$this->batchSize;\$result=mysqli_query(\$this->conn,\$query);\$realBatchSize=mysqli_num_rows(\$result);\$numFields=mysqli_num_fields(\$result);if(\$realBatchSize!==0){\$sql.='INSERT INTO \`'.\$table.'\` VALUES ';for(\$i=0;\$i<\$numFields;\$i++){\$rowCount=1;while(\$row=mysqli_fetch_row(\$result)){\$sql.='(';for(\$j=0;\$j<\$numFields;\$j++){if(isset(\$row[\$j])){\$row[\$j]=addslashes(\$row[\$j]);\$row[\$j]=str_replace(\"\\n\",\"\\\\n\",\$row[\$j]);\$row[\$j]=str_replace(\"\\r\",\"\\\\r\",\$row[\$j]);\$row[\$j]=str_replace(\"\\f\",\"\\\\f\",\$row[\$j]);\$row[\$j]=str_replace(\"\\t\",\"\\\\t\",\$row[\$j]);\$row[\$j]=str_replace(\"\\v\",\"\\\\v\",\$row[\$j]);\$row[\$j]=str_replace(\"\\a\",\"\\\\a\",\$row[\$j]);\$row[\$j]=str_replace(\"\\b\",\"\\\\b\",\$row[\$j]);if(\$row[\$j]=='true'or \$row[\$j]=='false'or preg_match('/^-?[0-9]+\$/',\$row[\$j])or \$row[\$j]=='NULL'or \$row[\$j]=='null'){\$sql.=\$row[\$j];}else{\$sql.='\"'.\$row[\$j].'\"';}}else{\$sql.='NULL';}if(\$j<(\$numFields-1)){\$sql.=',';}}if(\$rowCount==\$realBatchSize){\$rowCount=0;\$sql.=\");\\n\";}else{\$sql.=\"),\\n\";}\$rowCount++;}}\$this->saveFile(\$sql);\$sql='';}}\$sql.=\"\\n\\n\";\$this->obfPrint('OK');}if(\$this->disableForeignKeyChecks===true){\$sql.=\"SET foreign_key_checks = 1;\\n\";}\$this->saveFile(\$sql);if(defined('BACKUP_TRIGGERS')&&BACKUP_TRIGGERS===true){\$sql=\$this->backupTriggers();\$this->saveFile(\$sql);}if(\$this->gzipBackupFile){\$this->gzipBackupFile();}else{\$this->obfPrint('Backup file succesfully saved to '.\$this->backupDir.'/'.\$this->backupFile,1,1);}}catch(Exception \$e){print_r(\$e->getMessage());return false;}return true;}protected function backupTriggers(){\$sql=\"\\n\\n\";\$result=\$this->conn->query('SHOW TRIGGERS');while(\$row=\$result->fetch_assoc()){\$this->obfPrint(\"Backing up \".\$row['Trigger'].\" trigger...\".str_repeat('.',50-strlen(\$row['Trigger'])),0,0);\$sql.='DROP TRIGGER IF EXISTS '.\$row['Trigger'].';';\$sql.=\"\\n\\n\";\$sql.='CREATE TRIGGER '.\$row['Trigger'].' '.\$row['Timing'].' '.\$row['Event'].' ON \`'.\$row['Table'].'\` FOR EACH ROW'.\"\\n\\t\\t\".\$row['Statement'].';';\$sql.=\"\\n\\n\\n\";\$this->obfPrint(\"OK\");}\$result->close();return \$sql;}protected function saveFile(&\$sql){if(!\$sql)return false;try{if(!file_exists(\$this->backupDir)){mkdir(\$this->backupDir,0777,true);}file_put_contents(\$this->backupDir.'/'.\$this->backupFile,\$sql,FILE_APPEND|LOCK_EX);}catch(Exception \$e){print_r(\$e->getMessage());return false;}return true;}protected function gzipBackupFile(\$level=9){if(!\$this->gzipBackupFile){return true;}\$source=\$this->backupDir.'/'.\$this->backupFile;\$dest=\$source.'.gz';\$this->obfPrint('Gzipping backup file to '.\$dest.'... ',1,0);\$mode='wb'.\$level;if(\$fpOut=gzopen(\$dest,\$mode)){if(\$fpIn=fopen(\$source,'rb')){while(!feof(\$fpIn)){gzwrite(\$fpOut,fread(\$fpIn,1024*256));}fclose(\$fpIn);}else{return false;}gzclose(\$fpOut);if(!unlink(\$source)){return false;}}else{return false;}\$this->obfPrint('OK');return \$dest;}public function obfPrint(\$msg='',\$lineBreaksBefore=0,\$lineBreaksAfter=1){if(!\$msg){return false;}if(\$msg!='OK'and \$msg!='KO'){\$msg=date(\"Y-m-d H:i:s\").' - '.\$msg;}\$output='';if(php_sapi_name()!=\"cli\"){\$lineBreak=\"<br />\";}else{\$lineBreak=\"\\n\";}if(\$lineBreaksBefore>0){for(\$i=1;\$i<=\$lineBreaksBefore;\$i++){\$output.=\$lineBreak;}}\$output.=\$msg;if(\$lineBreaksAfter>0){for(\$i=1;\$i<=\$lineBreaksAfter;\$i++){\$output.=\$lineBreak;}}\$this->output.=str_replace('<br />','\\n',\$output);echo \$output;if(php_sapi_name()!=\"cli\"){if(ob_get_level()>0){ob_flush();}}\$this->output.=\" \";flush();}public function getOutput(){return \$this->output;}}error_reporting(E_ALL);set_time_limit(900);if(php_sapi_name()!=\"cli\"){echo '<div style=\"font-family: monospace;\">';}\$backupDatabase=new Backup_Database(DB_HOST,DB_USER,DB_PASSWORD,DB_NAME,CHARSET);\$result=\$backupDatabase->backupTables(TABLES,BACKUP_DIR)?'OK':'KO';\$backupDatabase->obfPrint('Backup result: '.\$result,1);if(\$result=='KO')exit(55);\$output=\$backupDatabase->getOutput();if(php_sapi_name()!=\"cli\"){echo '</div>';}" > /dev/null
			j=$((j+1))
		done
	fi
}

function restore_backup {
	echo -e "\e[90mRestoring files...\e[34m"
	if [[ -d "${MM_DIR}/.backup/files/" ]]
	then
		while IFS='' read -r -d '' filename
		do
			if [[ "$(realpath "$filename")" == "$(realpath "${MM_DIR}/.gitignore")" ]]
			then
				continue
			fi
			while read -r line
			do
				local line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
				if [[ "$line" != "" ]]
				then
					if [[ -d "`dirname "$filename"`/$line" ]]
					then
						rm -R "`dirname "$filename"`/$line"
					elif [[ -f "`dirname "$filename"`/$line" ]]
					then
						rm "`dirname "$filename"`/$line"
					fi

					if [[ ! -f "${MM_DIR}/.backup/files/`dirname "$filename"`/$line" && ! -d "${MM_DIR}/.backup/files/`dirname "$filename"`/$line" ]]
					then
						continue
					fi
					if [[ ! -d "`dirname "$filename"`/`dirname "$line"`" ]]
					then
						mkdir -p "`dirname "$filename"`/`dirname "$line"`"
					fi

					if [[ -d "${MM_DIR}/.backup/files/`dirname "$filename"`/$line" ]]
					then
						cp -R "${MM_DIR}/.backup/files/`dirname "$filename"`/$line" "`dirname "$filename"`/`dirname "$line"`"
					else
						cp -R "${MM_DIR}/.backup/files/`dirname "$filename"`/$line" "`dirname "$filename"`/$line"
					fi
				fi
			done < "$filename"
		done < <(find "./" -type f -name ".gitignore" -print0)
	fi
	php -r "include 'config.php';\$m=new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD);\$q=\$m->query('SHOW DATABASES');while(\$d=\$q->fetch_assoc())if(preg_match('/${MM_DBPTN}/',\$d['Database']))\$m->query('DROP DATABASE \`'.\$d['Database'].'\`');"
	set +e
	local exitcode="`compgen -G "${MM_DIR}/.backup/databases/*.sql" > /dev/null ; echo "$?"`"
	set -e
	if [[ "$exitcode" == "0" ]]
	then
		local databases=(`ls "${MM_DIR}/.backup/databases/"*.sql`)
		local j=0
		while [[ $j < ${#databases[@]} ]]
		do
			local db_temp=`basename "${databases[$j]}"`
			echo -e "\e[90mRestoring \`${db_temp:0:${#db_temp}-4}\`...\e[34m"
			php -r "define(\"DB_USER\",'${MYSQLUSER}');
				define(\"DB_PASSWORD\",'${MYSQLPASSWORD}');
				define(\"DB_NAME\",'${db_temp:0:${#db_temp}-4}');
				define(\"DB_HOST\",'${MYSQLHOST}');
				define(\"BACKUP_DIR\",'${MM_DIR}/.backup/databases/');
				define(\"BACKUP_FILE\",'${db_temp}');
				define(\"CHARSET\",'utf8mb4');
				define(\"DISABLE_FOREIGN_KEY_CHECKS\",true);
				class Restore_Database{var \$host;var \$username;var \$passwd;var \$dbName;var \$charset;var \$conn;var \$disableForeignKeyChecks;function __construct(\$host,\$username,\$passwd,\$dbName,\$charset='utf8'){\$this->host=\$host;\$this->username=\$username;\$this->passwd=\$passwd;\$this->dbName=\$dbName;\$this->charset=\$charset;\$this->disableForeignKeyChecks=defined('DISABLE_FOREIGN_KEY_CHECKS')?DISABLE_FOREIGN_KEY_CHECKS:true;\$this->conn=\$this->initializeDatabase();\$this->backupDir=defined('BACKUP_DIR')?BACKUP_DIR:'.';\$this->backupFile=defined('BACKUP_FILE')?BACKUP_FILE:null;}function __destructor(){if(\$this->disableForeignKeyChecks===true){mysqli_query(\$this->conn,'SET foreign_key_checks = 1');}}protected function initializeDatabase(){try{\$conn=mysqli_connect(\$this->host,\$this->username,\$this->passwd);if(mysqli_connect_errno()){throw new Exception('ERROR connecting database: '.mysqli_connect_error());die(55);}if(\$this->disableForeignKeyChecks===true){mysqli_query(\$conn,'SET foreign_key_checks = 0');}}catch(Exception \$e){print_r(\$e->getMessage());die(55);}return \$conn;}public function restoreDb(){try{\$sql='';\$multiLineComment=false;\$backupDir=\$this->backupDir;\$backupFile=\$this->backupFile;\$backupFileIsGzipped=substr(\$backupFile,-3,3)=='.gz'?true:false;if(\$backupFileIsGzipped){if(!\$backupFile=\$this->gunzipBackupFile()){throw new Exception(\"ERROR: couldn't gunzip backup file \".\$backupDir.'/'.\$backupFile);}}\$handle=fopen(\$backupDir.'/'.\$backupFile,\"r\");if(\$handle){while((\$line=fgets(\$handle))!==false){if(strlen(ltrim(rtrim(\$line)))>1){\$lineIsComment=false;if(preg_match('/^\\/\\*/',\$line)){\$multiLineComment=true;\$lineIsComment=true;}if(\$multiLineComment or preg_match('/^\\/\\//',\$line)){\$lineIsComment=true;}if(!\$lineIsComment){\$sql.=\$line;if(preg_match('/;\$/',\$line)){if(mysqli_query(\$this->conn,\$sql)){if(preg_match('/^CREATE TABLE \`([^\`]+)\`/i',\$sql,\$tableName)){\$this->obfPrint(\"Table succesfully created: \`\".\$tableName[1].\"\`\");}else if(preg_match('/^CREATE TRIGGER ([^ ]+)/i',\$sql,\$triggerName)){\$this->obfPrint(\"Trigger succesfully created: \".\$triggerName[1]);}\$sql='';}else{throw new Exception(\"ERROR: SQL execution error: \".mysqli_error(\$this->conn));}}}else if(preg_match('/\\*\\/\$/',\$line)){\$multiLineComment=false;}}}fclose(\$handle);}else{throw new Exception(\"ERROR: couldn't open backup file \".\$backupDir.'/'.\$backupFile);}}catch(Exception \$e){print_r(\$e->getMessage());return false;}if(\$backupFileIsGzipped){unlink(\$backupDir.'/'.\$backupFile);}return true;}protected function gunzipBackupFile(){\$bufferSize=4096;\$error=false;\$source=\$this->backupDir.'/'.\$this->backupFile;\$dest=\$this->backupDir.'/'.date(\"Ymd_His\",time()).'_'.substr(\$this->backupFile,0,-3);\$this->obfPrint('Gunzipping backup file '.\$source.'... ',1,1);if(file_exists(\$dest)){if(!unlink(\$dest)){return false;}}if(!\$srcFile=gzopen(\$this->backupDir.'/'.\$this->backupFile,'rb')){return false;}if(!\$dstFile=fopen(\$dest,'wb')){return false;}while(!gzeof(\$srcFile)){if(!fwrite(\$dstFile,gzread(\$srcFile,\$bufferSize))){return false;}}fclose(\$dstFile);gzclose(\$srcFile);return str_replace(\$this->backupDir.'/','',\$dest);}public function obfPrint(\$msg='',\$lineBreaksBefore=0,\$lineBreaksAfter=1){if(!\$msg){return false;}\$msg=date(\"Y-m-d H:i:s\").' - '.\$msg;\$output='';if(php_sapi_name()!=\"cli\"){\$lineBreak=\"<br />\";}else{\$lineBreak=\"\\n\";}if(\$lineBreaksBefore>0){for(\$i=1;\$i<=\$lineBreaksBefore;\$i++){\$output.=\$lineBreak;}}\$output.=\$msg;if(\$lineBreaksAfter>0){for(\$i=1;\$i<=\$lineBreaksAfter;\$i++){\$output.=\$lineBreak;}}if(php_sapi_name()==\"cli\"){\$output.=\"\\n\";}echo \$output;if(php_sapi_name()!=\"cli\"){ob_flush();}flush();}}error_reporting(E_ALL);set_time_limit(900);if(php_sapi_name()!=\"cli\"){echo '<div style=\"font-family: monospace;\">';}\$restoreDatabase=new Restore_Database(DB_HOST,DB_USER,DB_PASSWORD,DB_NAME);\$result=\$restoreDatabase->restoreDb(BACKUP_DIR,BACKUP_FILE)?'OK':'KO';\$restoreDatabase->obfPrint(\"Restoration result: \".\$result,1);if(\$result=='KO')exit(55);if(php_sapi_name()!=\"cli\"){echo '</div>';}" > /dev/null
			j=$((j+1))
		done
	fi
}

function delete_backup {
	if [[ -d "${MM_DIR}/.backup/" ]]
	then
		rm -R "${MM_DIR}/.backup/"
	fi
}

i=0
while [[ $i < ${#PHPFILES[@]} ]]
do
	if [[ ${PHPFILES[$i]} > $LAST ]]
	then
		create_backup

		if [[ $TEST_MIGRATE == true ]]
		then
			echo ""
			echo -e "\e[1mRunning test migration '${PHPFILES[$i]}'...\e[22m"
			echo -n -e "\e[97m"
			set +e
			php -r "require '${MM_DIR}/.mm_functions.php'; require 'config.php'; require '${MM_DIR}/${PHPFILES[$i]}';"
			exitcode=$?
			set -e
			echo -n -e "\e[34m"
			echo ""
			if [[ "$exitcode" != "0" ]]
			then
				echo -e "\e[1mTest result: \e[31mFailed\e[34m\e[22m"
			else
				echo -e "\e[1mTest result: \e[32mDone\e[34m\e[22m"
			fi
			echo ""
			echo -n -e "\e[1mPress enter to restore backup...\e[22m" ; read
			echo ""
			restore_backup
			delete_backup
			echo -n -e "\e[0m"
			exit $exitcode
		fi

		echo ""
		echo -e "\e[1mRunning migration '${PHPFILES[$i]}'...\e[22m"
		echo -n -e "\e[97m"
		set +e
		php -r "require '${MM_DIR}/.mm_functions.php'; require 'config.php'; require '${MM_DIR}/${PHPFILES[$i]}';"
		exitcode=$?
		set -e
		echo -n -e "\e[34m"
		if [[ "$exitcode" != "0" ]]
		then
			echo ""
			echo -e "\e[1m\e[31mFailed\e[34m\e[22m"
			echo ""
			restore_backup
			delete_backup
			echo -n -e "\e[0m"
			exit $exitcode
		fi
		LAST="${PHPFILES[$i]}"
		echo $LAST > "${MM_DIR}/.info"

		delete_backup
	fi
	i=$((i+1))
done

echo ""
echo -e "\e[1m\e[32mDone\e[34m\e[22m"
echo ""
echo -n -e "\e[0m"
