#!/bin/bash

DB_NAME="lab_management"
MYSQL_USER="root"
MYSQL_PASS="phpmyadmin"

# Export complete database
mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" "$DB_NAME" > lab_management_dump_new.sql

# Show structure
echo "Database Structure:"
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$DB_NAME" -e "
SELECT TABLE_NAME as 'Table', 
       GROUP_CONCAT(CONCAT(COLUMN_NAME, ' (', DATA_TYPE, ')') ORDER BY ORDINAL_POSITION) as 'Columns'
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = '$DB_NAME'
GROUP BY TABLE_NAME;"

echo "Database exported to lab_management_dump_new.sql"
