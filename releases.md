# Releases

## v2.5.0

  - `--help` is now a first-class request: when a help token is encountered during parsing, `Samovar::Help` is raised before any required-argument validation, and `Command.call` prints usage for the most specific command resolved so far (e.g. `command sub --help` prints the sub-command's usage). Commands no longer need to declare `--help` or check for it in `#call`.
  - `--help` is always reserved, even if declared as an option. `-h` is only treated as a help request when it isn't claimed by another option (e.g. `-h/--hostname` keeps working).
  - Help requests are not recognized after a `--` boundary: `command -- --help` passes `--help` through as data. Positional arguments (`Samovar::One`) no longer consume a literal `--`, which is reserved for `Samovar::Split`.
  - Help output is printed to the command's output (defaults to `$stdout`), while errors continue to be printed to the error output (defaults to `$stderr`). When help is requested, `Command.call` returns the parsed command (truthy) instead of `nil`, so binaries can distinguish help (exit 0) from errors (exit 1).
  - Usage formatting no longer suppresses `--help` tokens in `InvalidInputError` messages — help is now handled explicitly.

## v2.4.1

## v2.4.0

  - Fix option parsing and validation: required options are now detected correctly and raise `Samovar::MissingValueError` when missing.
  - Fix flag value parsing: flags that expect a value no longer consume a following flag as their value (e.g. `--config <path>` will not consume `--verbose`).
  - Usage improvements: required options are marked as `(required)` in usage output.

## v2.3.0

  - Add support for `--[no]-thing` explicit boolean flags, allowing users to explicitly enable or disable boolean options.

## v2.2.0

  - Add support for explicit output: commands can now specify an output stream (e.g. `STDOUT`, `STDERR`, or custom IO objects) via the `output:` parameter in `Command.call`.

## v2.1.4

  - `Command#to_s` now returns the class name by default, improving debugging and introspection.
