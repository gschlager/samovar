# Getting Started

This guide explains how to use `samovar` to build command-line tools and applications.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add samovar
~~~

Or install it yourself as:

~~~ bash
$ gem install samovar
~~~

## Core Concepts

Samovar provides a declarative class-based DSL for building command-line parsers. The main concepts include:

- **Commands**: Classes that represent specific functions in your program, inheriting from {ruby Samovar::Command}.
- **Options**: Command-line flags and arguments that can be parsed using the `options` block.
- **Nested Commands**: Sub-commands that can be composed using the `nested` method.
- **Tokens**: Positional arguments parsed using `one` and `many` methods.
- **Splits**: Separating arguments at a specific delimiter (e.g., `--`) using the `split` method.

## Usage

Create `Command` classes that represent specific functions in your program. The top level command might look something like this:

~~~ ruby
require "samovar"

class List < Samovar::Command
	self.description = "List the current directory"
	
	def call
		system("ls -lah")
	end
end

class Application < Samovar::Command
	nested :command, {
		"list" => List
	}, default: "list"
	
	def call
		@command.call
	end
end

Application.call # Defaults to ARGV.
~~~

Note that you don't need to declare or handle `--help` yourself — see [Help](#help) below.

### Basic Options

Options allow you to parse command-line flags and arguments:

~~~ ruby
require "samovar"

class Application < Samovar::Command
	options do
		option "-f/--frobulate <text>", "Frobulate the text"
		option "-x | -y", "Specify either x or y axis.", key: :axis
		option "-F/--yeah/--flag", "A boolean flag with several forms."
		option "--things <a,b,c>", "A list of things" do |value|
			value.split(/\s*,\s*/)
		end
	end
end

application = Application.new(["-f", "Algebraic!"])
application.options[:frobulate] # 'Algebraic!'

application = Application.new(["-x", "-y"])
application.options[:axis] # :y

application = Application.new(["-F"])
application.options[:flag] # true

application = Application.new(["--things", "x,y,z"])
application.options[:things] # ['x', 'y', 'z']
~~~

### Nested Commands

You can create sub-commands that are nested within your main application:

~~~ ruby
require "samovar"

class Create < Samovar::Command
	def invoke(parent)
		puts "Creating"
	end
end

class Application < Samovar::Command
	nested "<command>",
		"create" => Create
	
	def invoke(program_name: File.basename($0))
		if @command
			@command.invoke
		else
			print_usage(program_name)
		end
	end
end

Application.new(["create"]).invoke
~~~

### ARGV Splits

You can split arguments at a delimiter (typically `--`):

~~~ ruby
require "samovar"

class Application < Samovar::Command
	many :packages
	split :argv
end

application = Application.new(["foo", "bar", "baz", "--", "apples", "oranges", "feijoas"])
application.packages # ['foo', 'bar', 'baz']
application.argv # ['apples', 'oranges', 'feijoas']
~~~

### Parsing Tokens

You can parse positional arguments using `one` and `many`:

~~~ ruby
require "samovar"

class Application < Samovar::Command
	self.description = "Mix together your favorite things."
	
	one :fruit, "Name one fruit"
	many :cakes, "Any cakes you like"
end

application = Application.new(["apple", "chocolate cake", "fruit cake"])
application.fruit # 'apple'
application.cakes # ['chocolate cake', 'fruit cake']
~~~

### Explicit Commands

Given a custom `Samovar::Command` subclass, you can instantiate it with options:

~~~ ruby
application = Application["--root", path]
~~~

You can also duplicate an existing command instance with additions/changes:

~~~ ruby
concurrent_application = application["--threads", 12]
~~~

These forms can be useful when invoking one command from another, or in unit tests.

## Help

Samovar treats `--help` as a first-class request: commands don't need to declare it as an option or check for it in `call`. When a help token is encountered during parsing, {ruby Samovar::Help} is raised before any required arguments or options are validated, and {ruby Samovar::Command.call} handles it by printing usage information for the most specific command resolved so far:

~~~ ruby
Application.call(["--help"]) # Prints usage for Application.
Application.call(["list", "--help"]) # Prints usage for the `list` sub-command.
~~~

The rules are:

- `--help` is always reserved as a help request, even if a command declares it as an option.
- `-h` is only treated as a help request if no option claims it — an option like `-h/--hostname` takes precedence, while `-h/--help` still works as expected.
- Arguments after a `--` split are never treated as help requests, e.g. `application -- --help` passes `--help` through as data.
- Help takes precedence over validation, so `application --help` prints usage even when required options or arguments are missing.

Usage information is printed to the command's output (defaults to `$stdout`), while errors are printed to the error output (defaults to `$stderr`). When help is requested, {ruby Samovar::Command.call} returns the parsed command without executing it, so a typical binary can use the result to compute a successful exit status:

~~~ ruby
exit(1) unless Application.call
~~~

If you need custom behaviour, use {ruby Samovar::Command.parse} and rescue {ruby Samovar::Help} yourself.

## Error Handling

Samovar provides two entry points with different error handling behaviors:

### `call()` - High-Level Entry Point

Use `call()` for CLI applications. It handles parsing errors gracefully by printing usage information:

~~~ ruby
# Automatically handles errors and prints usage
Application.call(ARGV)
~~~

If parsing fails or the command raises a {ruby Samovar::Error}, it will:
- Print the usage information with the error highlighted
- Return `nil` instead of raising an exception

### `parse()` - Low-Level Parsing

Use `parse()` when you need explicit error handling or for testing:

~~~ ruby
begin
  app = Application.parse(["--unknown-flag"])
rescue Samovar::InvalidInputError => error
  # Handle the error yourself
  puts "Invalid input: #{error.message}"
end
~~~

The `parse()` method raises exceptions on parsing errors, giving you full control over error handling.

### Error Types

Samovar defines several error types:

- {ruby Samovar::InvalidInputError}: Raised when unexpected command-line input is encountered
- {ruby Samovar::MissingValueError}: Raised when required arguments or options are missing
- {ruby Samovar::Help}: Raised when help is requested (e.g. `--help`) — not a failure, but a request to print usage

