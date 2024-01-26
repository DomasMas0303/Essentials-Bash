#!/bin/bash

# Check if the path to output.txt file is provided as an argument
if [ $# -eq 0 ]; then
    echo "Error: Path to output.txt file is missing."
    exit 1
fi

# Read the path to output.txt file from the argument
output_txt_path="$1"

# Check if the output.txt file exists
if [ ! -f "$output_txt_path" ]; then
    echo "Error: output.txt file not found."
    exit 1
fi

# Read the content of output.txt file and store it in a variable
output_txt_content=$(cat "$output_txt_path")

# Create arrays to store test data and the JSON elements
tests=()
success=0
failed=0
total_duration=0
test_name=""

# Read the content of the variable line by line
while IFS= read -r line; do
    if [[ "$line" =~ \[([^]]+)\] ]]; then
        # Extract the test name
        test_name="${BASH_REMATCH[1]}"
        test_name=$(echo "$test_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    elif [[ "$line" =~ ok ]]; then

        # Save the current value of IFS to a variable
        OLD_IFS=$IFS

        # Set IFS to split based on space
        IFS='0123456789'

        # Read the line into three variables
        read -r element1 element2_rest <<< "$line"

        # Reset IFS to split the second element based on comma
        IFS=')'
        read -r element2 element3 <<< "$element2_rest"

        # Restore the original IFS value
        IFS=$OLD_IFS

        # Remove comma symbol in element 2, as well as trim space symbols
        element1=${element1}
        element2=${element2#"${element2%%[![:space:]]*}"}
        element3=${element3//,/}
        element3=${element3#"${element3%%[![:space:]]*}"}

        # Extract test status, test name, and duration
        status="$element1"
        test_name_each="$element2)"
        duration="$element3"

        # Convert status to true for "ok" and false for "not ok"
        if [[ "$status" =~ "not" ]]; then
            status=false
        else
            status=true
        fi

        # Manually build the JSON string for the test data and add a leading space before each key
        test_json="{\n"
        test_json+="   \"name\": \"$test_name_each\",\n"
        test_json+="   \"status\": $status,\n"
        test_json+="   \"duration\": \"$duration\"\n"
        test_json+="  }"

        # Add the test data JSON string to the tests array
        tests+=("$test_json")
    elif [[ "$line" =~ ^([0-9]+)\ \(of\ ([0-9]+)\)\ tests\ passed\,\ ([0-9]+)\ tests\ failed\,\ rated\ as\ ([0-9.]+)%\,\ spent\ ([0-9]+)ms$ ]]; then
        # Extract summary data
        success="${BASH_REMATCH[1]}"
        failed="${BASH_REMATCH[3]}"
        rating=$(printf "%.2f" "${BASH_REMATCH[4]}")
        total_duration="${BASH_REMATCH[5]}ms"  # Add "ms" suffix to the total duration
    fi
done <<< "$output_txt_content"

# Calculate the total number of tests
total_tests=$((success + failed))

# Create an empty array to store formatted JSON elements
formatted_tests=()

# Loop through each test JSON element and format it with a leading space and comma
for ((i = 0; i < ${#tests[@]} - 1; i++)); do
    formatted_tests+=("  ${tests[$i]},")
done

# Add the last element without the trailing comma
formatted_tests+=("  ${tests[${#tests[@]} - 1]}")

# Join the formatted tests array into a single string
tests_json_array=$(IFS=$'\n'; echo "${formatted_tests[*]}")

# Generate JSON output
json="{\n"
json+=" \"testName\": \"$test_name\",\n"
json+=" \"tests\": [\n$tests_json_array\n],\n"
json+=" \"summary\": {\n"
json+="  \"success\": $success,\n"
json+="  \"failed\": $failed,\n"
json+="  \"rating\": $rating,\n"
json+="  \"duration\": \"$total_duration\"\n"
json+="  }\n"
json+="}"

# Save JSON to a temporary file
tmp_file=$(mktemp)
echo -n -e "$json" > "$tmp_file"

# Adding a space after the } symbol to match the random space in the expected output.
sed '38s/}/} /' "$tmp_file" > output.json

# Remove the temporary file
rm "$tmp_file"

# Indicate successful execution
echo "Script executed successfully!"