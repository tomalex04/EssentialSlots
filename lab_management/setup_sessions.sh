#!/bin/bash

# Database configuration
DB_USER="root"
DB_PASS="phpmyadmin"
DB_NAME="lab_management"

# Display configuration
echo "Using database: $DB_NAME"
echo "Using user: $DB_USER"

# Check if MySQL is running
if ! pgrep mysqld > /dev/null
then
    echo "Error: MySQL is not running"
    exit 1
fi

# Execute the SQL file
echo "Applying database updates..."
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < add_sessions_table.sql

# Check if the command was successful
if [ $? -eq 0 ]
then
    echo "Database updates applied successfully"
    exit 0
else
    echo "Error: Failed to apply database updates"
    exit 1
fi
