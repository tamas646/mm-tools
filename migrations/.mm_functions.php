<?php

error_reporting(E_ALL);
function mm_error_handler($errno, $errstr, $errfile, $errline)
{
	echo 'PHP Fatal error: '.$errstr.' in '.$errfile.' on line '.$errline.PHP_EOL;
	debug_print_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS);
	exit(55);
}
set_error_handler('mm_error_handler');
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function mm_add_config($name, $value, $prompt = '', $password = false, $numeric = false)
{
	if($prompt != '')
	{
		if($password)
			$temp = mm_read_password($prompt.': ');
		else
			$temp = mm_readline($prompt.': ');
		if($temp != '')
			$value = $temp;
		if($numeric && !is_numeric($value))
			trigger_error('\''.$name.'\' config entry is not numeric', E_USER_ERROR);
	}
	if(!file_exists(__DIR__.'/../config.php'))
	{
		trigger_error('config file not found', E_USER_ERROR);
	}
	$lines = explode(PHP_EOL, file_get_contents(__DIR__.'/../config.php'));
	$content = '';
	$count = count($lines);
	for($i = 0; $i < $count - 1; ++$i)
	{
		$content .= $lines[$i].PHP_EOL;
	}
	if($numeric)
		$content .= 'define(\''.$name.'\', '.$value.');'.PHP_EOL;
	else
		$content .= 'define(\''.$name.'\', \''.$value.'\');'.PHP_EOL;
	$content .= $lines[$i];
	if(file_put_contents(__DIR__.'/../config.php', $content) === false)
	{
		trigger_error('Could not write changes to the config file', E_USER_ERROR);
	}
	return $value;
}

function mm_readline($prompt = '')
{
	echo $prompt;
	return stream_get_line(STDIN, 1024, PHP_EOL);
}

function mm_read_password($prompt = '')
{
	echo $prompt;
	if(PHP_OS_FAMILY == 'Windows')
		exec('powershell -Command "$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(($Host.UI.ReadLineAsSecureString()))); if(!$?) { Write-Host $password ; exit 1 }; Write-Host $password"'."\r\n".'IF %errorlevel% NEQ 0 ( exit 1 )', $output, $exitcode);
	else
	{
		exec('password="$(/bin/bash -c "read -s password 2>&1 ; if [[ "$?" != "0" ]] ; then exit 1 ; fi ; echo \$password")" ; if [ "$?" -ne "0" ] ; then echo $password ; exit 1 ; fi ; echo $password', $output, $exitcode);
		echo PHP_EOL;
	}
	if($exitcode != 0)
	{
		trigger_error('Password read error: '.implode(PHP_EOL, $output), E_USER_ERROR);
	}
	return $output[0];
}

function mm_multi_query(&$conn, $sql, $return = false)
{
	if(!$return)
	{
		$conn->multi_query($sql);
		while($conn->more_results())
			if(!$conn->next_result())
				trigger_error('Error in SQL multi query: '.$conn->error, E_USER_ERROR);
	}
	else
	{
		$conn->multi_query($sql);
		$result = [];
		do $result[] = $conn->store_result();
		while($conn->more_results() && ($conn->next_result() || trigger_error('Error in SQL multi query: '.$conn->error, E_USER_ERROR)));
		return $result;
	}
}

function mm_rename($path, $dest)
{
	if(!rename($path, $dest))
	{
		trigger_error('Cannot rename \''.$path.'\' to \''.$dest.'\'', E_USER_ERROR);
	}
}

function mm_copy($path, $dest, $recurse = false)
{
	if(!$recurse)
	{
		if(!copy($path, $dest))
		{
			trigger_error('Cannot copy \''.$path.'\' to \''.$dest.'\'', E_USER_ERROR);
		}
		return;
	}

	$dir = opendir($path);
	if(!file_exists($dest))
	{
		if(!mkdir($dest))
		{
			trigger_error('Cannot create directory \''.$dest.'\'', E_USER_ERROR);
		}
	}
	while($file = readdir($dir))
	{
		if($file != '.' && $file != '..')
		{
			if(is_dir($path.'/'.$file))
			{
				mm_copy($path.'/'.$file, $dest.'/'.$file, true);
			}
			else
			{
				if(!copy($path.'/'.$file, $dest.'/'.$file))
				{
					trigger_error('Cannot copy \''.$path.'/'.$file.'\' to \''.$dest.'/'.$file.'\'', E_USER_ERROR);
				}
			}
		}
	}
	closedir($dir);
}

function mm_mkdir($path)
{
	if(!mkdir($path))
	{
		trigger_error('Cannot create directory \''.$path.'\'', E_USER_ERROR);
	}
}

function mm_remove($path)
{
	if(file_exists($path))
	{
		if(is_dir($path))
		{
			foreach(scandir($path) as $node)
				if(!in_array($node, ['.', '..']))
					ez_remove($node);
			if(!rmdir($path))
			{
				trigger_error('Cannot remove directory at \''.$path.'\'', E_USER_ERROR);
			}
		}
		else if(!unlink($path))
		{
			trigger_error('Cannot remove file at \''.$path.'\'');
		}
	}
}
