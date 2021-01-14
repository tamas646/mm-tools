#!/bin/bash
set -e
echo -n -e "\e[34m"
function reset_colors { echo -n -e "\e[0m" ; }
trap reset_colors EXIT

MM_DIR="`dirname "$0"`/migrations/"
MM_DBPTN='^(?!mysql$|sys$|information_schema$|performance_schema$|phpmyadmin$)'

if [[ "$OSTYPE" == "msys" ]]
then
	reset_colors
	echo "This script is not capable of running perfectly on Windows."
	echo -e "Please run \e[1mreset.bat\e[22m or \e[1mreset.ps1\e[22m instead."
	echo ""
	echo -n "Press any key to continue..." ; read
	exit 100
fi

echo "Are you sure you want to reset your repository?"
echo -ne "This will delete all data including gitignored files! \e[1m[y/N] "
read answer
echo -ne "\e[22m"
if [[ "$answer" != "y" && "$answer" != "Y" ]]
then
	echo -e "\e[1mAborting...\e[22m"
	echo -ne "\e[0m"
	exit 3
fi

echo ""

if [[ -f "`dirname "$0"`/config.php" ]]
then
	echo -e "\e[1m\e[31mDeleting databases...\e[34m\e[22m"
	php -r "include '`dirname "$0"`/config.php';\$m=new mysqli(MYSQL_HOST,MYSQL_USER,MYSQL_PASSWORD);\$q=\$m->query('SHOW DATABASES');while(\$d=\$q->fetch_assoc())if(preg_match('/${MM_DBPTN}/',\$d['Database']))\$m->query('DROP DATABASE \`'.\$d['Database'].'\`');"
else
	echo -e "\e[90m\e[1mWarning: \e[22mCannot delete databases: config.php not found\e[34m"
fi

echo -e "\e[1m\e[31mDeleting files...\e[34m\e[22m"
while IFS='' read -r -d '' filename
do
	if [[ "$(realpath "$filename")" == "$(realpath "${MM_DIR}/.gitignore")" ]]
	then
		continue
	fi
	while read -r line
	do
		line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		if [[ "$line" != "" ]]
		then
			if [[ -d "`dirname "$filename"`/${line}" ]]
			then
				rm -R "`dirname "$filename"`/${line}"
			elif [[ -f "`dirname "$filename"`/${line}" ]]
			then
				rm "`dirname "$filename"`/${line}"
			fi
		fi
	done < "$filename"
done < <(find "`dirname "$0"`/" -type f -name ".gitignore" -print0)

if [[ -f "${MM_DIR}/.info" ]]
then
	echo -e "\e[1m\e[31mDeleting info file...\e[34m\e[22m"
	rm "${MM_DIR}/.info"
fi

if [[ -d "${MM_DIR}/.backup/" ]]
then
	echo -e "\e[1m\e[31mDeleting backup folder...\e[34m\e[22m"
	rm -R "${MM_DIR}/.backup/"
fi

echo -ne "\e[0m"
