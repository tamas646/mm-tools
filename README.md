# Migration Manager tools

## What is it?

It's a migration manager package for web projects based on **php** and **mysql**.

## How to setup

1. Copy the following files and folders into your project:

- **migrate.sh**, **migrate.ps1**, **migrate.bat** - these are the migrate scripts for both Linux and Windows platforms
- **reset.sh**, **reset.ps1**, **reset.bat** - these are the reset script used to rollback all changes
- **migrations/** - this is the folder when the tool stores the migration status and temporary backups, also this is the directory where you have to create your migrations
- **.gitignore** - tells git to ignore the global config file (config.php)

2. Check the **regex pattern** which identifies the databases for your project to make sure the script will find and manage only the corresponding databases!
It can be found at the begining of **4 files**: *migrate.sh*, *migrate.ps1*, *reset.sh* and *reset.ps1*. You have to change the pattern in all files.
The default pattern identifies all databases except: ***mysql***, ***sys***, ***information_schema***, ***performance_schema*** and ***phpmyadmin***.
It is highly recommended to change this pattern to filter **only** the databases used by your project.

3. Check out the ["how to use"](migrations/README.md) section

## License and usability

This tool is published under the [GNU General Public License v3.0](LICENSE)

Use at your own risk!

If you find any problem, [check out the issue tickets](https://github.com/tamas646/mm-tools/issues) or [create one](https://github.com/tamas646/mm-tools/issues/new).

The base of the mysql backup creation code: [myphp-backup](https://github.com/daniloaz/myphp-backup) by [daniloaz](https://github.com/daniloaz)
