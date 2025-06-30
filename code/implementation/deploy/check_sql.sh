mysql -h 127.0.0.1 -u root -p -D information_schema -N -e \
"SELECT table_name FROM information_schema.tables WHERE table_schema = 'your_database_name';" \
| while read table; do
    echo "===== $table ====="
    mysql -u root -p -D information_schema -e "SELECT * FROM \`$table\`;"
done

