#!/bin/bash

# Check if the input file path is passed as an argument
if [ $# -eq 0 ]; then
    echo "Error: Input file path not provided. Usage: $0 <input_file>"
    exit 1
fi

# Get the input file path from the first argument
input_file="$1"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file not found: $input_file"
    exit 1
fi

# Specify the output file path
output_file="accounts_new.csv"
regex_test=""

if grep -q '"' "$input_file"; then
    regex_test=$(sed -E 's/("[^"]*")|,/\1|/g' "$input_file")
else
    regex_test=$(sed -E 's/,/|/g' "$input_file")
fi

# Replace three consecutive pipe symbols with two consecutive pipe symbols
regex_test=$(echo "$regex_test" | sed -E 's/\|\|\|/||/g')

# Update column names
updated_column_names=$(echo "$regex_test" | awk 'BEGIN { FS="|"; OFS="|" } { if (NR == 1) { print } else { for (i=1; i<=NF; i++) { gsub("_", " ", $i); $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2)) } } }')

# Update email column and capitalize names
updated_email_column=$(echo "$regex_test" | awk 'BEGIN { FS="|"; OFS="|" } { if (NR == 1) { print } else { split($3, name, " "); email = tolower(substr(name[1], 1, 1)) tolower(substr(name[2], 1)) "@abc.com"; $5 = email; $3 = toupper(substr(name[1], 1, 1)) tolower(substr(name[1], 2)) " " toupper(substr(name[2], 1, 1)) tolower(substr(name[2], 2)); print } }')

# Split name row into first element and part after hyphen
split_name_row=$(echo "$updated_email_column" | awk 'BEGIN { FS="|"; OFS="|" } { if (NR > 1) { if (index($3, "-") > 0) { split($3, name, "-"); $6 = $4; $3 = name[1]; $4 = toupper(substr(name[2], 1, 1)) substr(name[2], 2); $3 = $3 "-" $4; $4 = $6; $6=null } } print }')

# Write the updated email column to a temporary file
echo "$updated_column_names" > "$output_file"
echo "$split_name_row" >> "$output_file"

# Check duplicates and add location ID
awk 'BEGIN { FS=OFS="|" }
    NR == FNR { if (FNR > 1) seen[$5]++; next }
    FNR > 1 {
        if (seen[$5] > 1) {
            split($3, name, " ");
            $5 = tolower(substr(name[1], 1, 1)) tolower(substr(name[2], 1)) $2 "@abc.com"
            $3 = toupper(substr(name[1], 1, 1)) tolower(substr(name[1], 2)) " " toupper(substr(name[2], 1, 1)) tolower(substr(name[2], 2))
        }
        print
    }' "$output_file" "$output_file" > temp_file && mv temp_file "$output_file"

# Replace pipe symbols with commas
sed -E 's/\|/,/g' "$output_file" > temp_file && mv temp_file "$output_file"

# Store the content of the output file
output=$(cat "$output_file")

echo "$output"
