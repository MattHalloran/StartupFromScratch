# Argument Handling Utility

This project uses a centralized argument handling utility located in `scripts/utils/arguments.sh`. This utility standardizes command-line argument parsing across all scripts.

## Using the Utility in Scripts

Here's how to use the argument handling utility in your scripts:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Load the argument handling utility
source "${HERE}/../utils/arguments.sh"

# Register arguments
arg_reset

arg_register \
  --name "name" \
  --flag "n" \
  --desc "Name to greet" \
  --type "value" \
  --default "World"

arg_register \
  --name "verbose" \
  --flag "v" \
  --desc "Enable verbose output" \
  --type "value" \
  --options "yes|no" \
  --default "no"

arg_register \
  --name "count" \
  --flag "c" \
  --desc "Number of greetings" \
  --type "value" \
  --default "1"

# Parse arguments
arg_parse "$@" >/dev/null

# Get argument values
name=$(arg_get "name")
count=$(arg_get "count")

# Check if a flag is enabled
if arg_is_enabled "verbose"; then
    echo "Running in verbose mode"
fi

# Use the arguments
for ((i=1; i<=count; i++)); do
    echo "Hello, $name!"
done
```

## Available Functions

### arg_reset

Resets all registered arguments. Call this before registering arguments.

```bash
arg_reset
```

### arg_register

Registers a new argument with a readable, named parameter format.

```bash
arg_register \
  --name "target" \
  --flag "t" \
  --desc "Target environment" \
  --type "value" \
  --options "native-linux|native-macos|docker|k8s" \
  --default "native-linux" \
  --required "yes"
```

Parameters:
- `--name`: Long option name (for `--name`)
- `--flag`: Short option flag (for `-f`)
- `--desc`: Help text for the argument
- `--type`: One of `value` (single value) or `array` (multiple values)
- `--options`: Available options displayed in the help text (e.g., "option1|option2|option3")
- `--default`: Default value if not specified
- `--required`: Whether the argument is required (`yes` or `no`)
- `--no-value`: Set to "yes" for flags that don't need a value (like `--help`)

All arguments accept values by default. For boolean flags, use "yes"/"no" values unless specifying `--no-value "yes"`.

Examples:
```bash
# Required argument with a default and displayed options
arg_register \
  --name "target" \
  --flag "t" \
  --desc "Target environment" \
  --type "value" \
  --options "native-linux|native-macos|docker|k8s" \
  --default "native-linux" \
  --required "yes"

# Boolean flag (takes yes/no)
arg_register \
  --name "verbose" \
  --flag "v" \
  --desc "Enable verbose output" \
  --type "value" \
  --options "yes|no" \
  --default "no"

# Standard help flag that doesn't require a value
arg_register \
  --name "help" \
  --flag "h" \
  --desc "Show this help message" \
  --type "value" \
  --default "no" \
  --no-value "yes"

# Array argument that can take multiple values
arg_register \
  --name "files" \
  --flag "f" \
  --desc "Files to process" \
  --type "array"
```

### arg_parse

Parses command line arguments according to registered arguments. Special handling is built in for the help flag.

```bash
arg_parse "$@"
```

When the help flag is detected, this function will automatically display usage information and exit.

### arg_get

Gets the value of a specific argument.

```bash
value=$(arg_get "name")
```

### arg_is_enabled

Checks if a value-based argument is enabled (has value "yes", "true", "1", or "on").

```bash
if arg_is_enabled "verbose"; then
    # Do verbose stuff
fi
```

### arg_usage

Generates and prints a usage message.

```bash
arg_usage "Script description text"
```

The generated help text will include available options if specified:

```
Usage: myscript.sh [OPTIONS]
A simple script description

Options:
  -t, --target <native-linux|native-macos|docker|k8s>  Target environment (default: native-linux) [REQUIRED]
  -v, --verbose <yes|no>                              Enable verbose output (default: no)
  -f, --files <value>                                 Files to process
  -h, --help                                          Show this help message (default: no)
```

Notice how the help flag doesn't show `<value>` because it's registered with `--no-value "yes"`.

### arg_export

Exports all argument values as environment variables.

```bash
# Export with default names (uppercase)
arg_export

# Export with a prefix (e.g., MYAPP_NAME)
arg_export "myapp"
```

## Command Line Usage

With the standardized approach, most arguments require values (except those with --no-value "yes"):

```bash
# Regular arguments with values
$ ./script.sh --verbose yes --name John --count 3

# Flag-style arguments (those registered with --no-value "yes")
$ ./script.sh --help
```

## Benefits of Using This Utility

1. **Consistency**: All scripts use the same argument format and parsing logic
2. **Readability**: The multi-line format makes argument registration easy to read
3. **Standardization**: Most arguments take values, making it easier to pass args between scripts
4. **Self-Documenting**: Help text is generated automatically with available options and descriptions
5. **Validation**: Automatic validation of required arguments and argument types
6. **Flexibility**: Special handling for help flags that don't need values

## Migrating Existing Scripts

To migrate an existing script to use this utility:

1. Source the arguments.sh utility file
2. Replace default value declarations with `arg_register` calls using the new format
3. Add the `--options` parameter to show available choices in the help text
4. Use `--no-value "yes"` for flag-style arguments like help
5. Replace the `parse_arguments` function with a call to `arg_parse`
6. Note that help flag handling is automatic
7. Replace variable access with `arg_get` and `arg_is_enabled` calls
8. Replace your usage function with `arg_usage`
9. Update most flag arguments to use yes/no values unless they use `--no-value` 