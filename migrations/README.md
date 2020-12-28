# [Migration Manager tools by](https://github.com/tamas646/mm-tools) [*tamas646*](https://ptamas.hu/)

## What is it?

It's a migration manager package for web projects based on **php** and **mysql**.

## How to use

1. Create your migrations in this folder (you can use the built in functions defined in [*.mm_functions.php*](.mm_functions.php)), then run either **migrate.sh** or **migrate.bat** (depending on the OS you use). Remember that you have to create your migrations as **php files** named in **alphabetic order**. (Eg. current date and a short description)

2. If the script ran successfully without errors, you can commit your migration to your repository.

3. Once your collaborator pulled your changes (s)he also has to run the script to apply the migrations.

4. If you want to roll back all migrations, you can use the **reset.sh** or **reset.bat** script to delete all added files or mysql databases.

## config.php

It's the global config file located in the same folder as the migrate and reset scripts. You can define all config entries in this files (such as site url or mail server settings) using the **mm_add_config()** function.

Three config entries (php constants) will be automatically added to your conig file when you first run the migrate script. These are:

- **MYSQL_HOST** - the host of your mysql server
- **MYSQL_USER** - the user which will be used when logging int to the database server
- **MYSQL_PASSWORD** - the mysql user's password

You can use them anywhere in the project, just import the config file.

## Working on multiple branches

If you want to create and use multiple branches in your project, make sure you follow the rules below:

- before you merge, rewrite your migration files to be **alphabetically after** the migrations already existing on the main branch

- if the main branch contains unapplied migrations, run the **reset script** after you merged your branch, then **apply the migrations again** (migrate script)
