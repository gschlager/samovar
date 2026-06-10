# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2025, by Samuel Williams.

require_relative "table"
require_relative "options"
require_relative "nested"
require_relative "one"
require_relative "many"
require_relative "split"


require_relative "output"

require_relative "error"

module Samovar
	# Represents a command in the command-line interface.
	# 
	# Commands are the main building blocks of Samovar applications. Each command is a class that can parse command-line arguments, options, and sub-commands.
	class Command
		# Parse and execute the command with the given input.
		#
		# This is the high-level entry point for CLI applications. It handles errors gracefully by printing usage and returning nil.
		#
		# If help is requested (e.g. `--help`), usage information for the most specific command resolved so far is printed to that command's output (defaults to `$stdout`) and the parsed command is returned without being executed. This allows a binary to distinguish help (truthy result) from errors (nil result), e.g. `exit(1) unless MyCommand.call`.
		#
		# @parameter input [Array(String)] The command-line arguments to parse.
		# @parameter output [IO] The output stream for error messages.
		# @returns [Object | Command | Nil] The result of the command's call method, the parsed command if help was requested, or nil if parsing/execution failed.
		def self.call(input = ARGV, output: $stderr)
			self.parse(input).call
		rescue Help => help
			help.command.print_usage
			
			return help.command
		rescue Error => error
			error.command.print_usage(output: output) do |formatter|
				formatter.map(error)
			end
			
			return nil
		end
		
		# Parse the command-line input and create a command instance.
		#
		# This is the low-level parsing primitive. It raises {Error} exceptions on parsing failures.
		# For CLI applications, use {call} instead which handles errors gracefully.
		#
		# @parameter input [Array(String)] The command-line arguments to parse.
		# @returns [Command] The parsed command instance.
		# @raises [Error] If parsing fails.
		# @raises [Help] If help is requested, e.g. by `--help`.
		def self.parse(input)
			self.new(input)
		end
		
		# Create a new command instance with the given arguments.
		# 
		# This is a convenience method for creating command instances with explicit arguments.
		# 
		# @parameter input [Array(String)] The command-line arguments to parse.
		# @parameter options [Hash] Additional options to pass to the command.
		# @returns [Command] The command instance.
		def self.[](*input, **options)
			self.new(input, **options)
		end
		
		class << self
			# A description of the command's purpose.
			# 
			# @attribute [String]
			attr_accessor :description
		end
		
		# The table of rows for parsing command-line arguments.
		# 
		# @returns [Table] The table of parsing rows.
		def self.table
			@table ||= Table.nested(self)
		end
		
		# Append a row to the parsing table.
		# 
		# @parameter row The row to append to the table.
		def self.append(row)
			if method_defined?(row.key, false)
				raise ArgumentError, "Method for key #{row.key} is already defined!"
			end
			
			attr_accessor(row.key) if row.respond_to?(:key)
			
			self.table << row
		end
		
		# Define command-line options for this command.
		# 
		# @parameter arguments [Array] The arguments for the options.
		# @parameter options [Hash] Additional options.
		# @yields {|...| ...} A block that defines the options using {Options}.
		def self.options(*arguments, **options, &block)
			append Options.parse(*arguments, **options, &block)
		end
		
		# Define a nested sub-command.
		# 
		# @parameter arguments [Array] The arguments for the nested command.
		# @parameter options [Hash] A hash mapping command names to command classes.
		def self.nested(*arguments, **options)
			append Nested.new(*arguments, **options)
		end
		
		# Define a single required positional argument.
		# 
		# @parameter arguments [Array] The arguments for the positional parameter.
		# @parameter options [Hash] Additional options.
		def self.one(*arguments, **options)
			append One.new(*arguments, **options)
		end
		
		# Define multiple positional arguments.
		# 
		# @parameter arguments [Array] The arguments for the positional parameters.
		# @parameter options [Hash] Additional options.
		def self.many(*arguments, **options)
			append Many.new(*arguments, **options)
		end
		
		# Define a split point in the argument list (typically `--`).
		# 
		# @parameter arguments [Array] The arguments for the split.
		# @parameter options [Hash] Additional options.
		def self.split(*arguments, **options)
			append Split.new(*arguments, **options)
		end
		
		# Generate usage information for this command.
		# 
		# @parameter rows [Output::Rows] The rows to append usage information to.
		# @parameter name [String] The name of the command.
		def self.usage(rows, name)
			rows.nested(name, self) do |rows|
				return unless table = self.table.merged
				
				table.each do |row|
					if row.respond_to?(:usage)
						row.usage(rows)
					else
						rows << row
					end
				end
			end
		end
		
		# Generate a command-line usage string.
		#
		# @parameter name [String] The name of the command.
		# @returns [String] The command-line usage string.
		def self.command_line(name)
			table = self.table.merged
			
			return "#{name} #{table.usage}"
		end
		
		# Find the option that handles the given flag token, if any.
		#
		# @parameter token [String] The flag token, e.g. `-h`.
		# @returns [Option | Nil] The option that claims the given flag.
		def self.option_for(token)
			self.table.merged.each do |row|
				if row.is_a?(Options) and option = row[token]
					return option
				end
			end
			
			return nil
		end
		
		# Check if the given token is a help request for this command.
		#
		# `--help` is always reserved as a help request, even if an option declares it. `-h` is only treated as a help request if no option claims it for another purpose (e.g. `-h/--hostname`), or if it is claimed by the help option itself (e.g. `-h/--help`).
		#
		# @parameter token [String | Nil] The token to check.
		# @returns [Boolean] True if the token requests help.
		def self.help_token?(token)
			case token
			when "--help"
				true
			when "-h"
				option = self.option_for(token)
				option.nil? || option.key == :help
			else
				false
			end
		end
		
		# Initialize a new command instance.
		# 
		# @parameter input [Array(String) | Nil] The command-line arguments to parse.
		# @parameter name [String] The name of the command (defaults to the script name).
		# @parameter parent [Command | Nil] The parent command, if this is a nested command.
		# @parameter output [IO | Nil] The output stream for usage information.
		def initialize(input = nil, name: File.basename($0), parent: nil, output: nil)
			@name = name
			@parent = parent
			@output = output
			
			parse(input) if input
		end
		
		# The output stream for usage information.
		# 
		# @attribute [IO]
		attr :output
		
		# The output stream for usage information, defaults to `$stdout`.
		# 
		# @returns [IO] The output stream.
		def output
			@output || $stdout
		end
		
		# Generate a string representation of the command.
		# 
		# @returns [String] The class name.
		def to_s
			self.class.name
		end
		
		# The name of the command.
		# 
		# @attribute [String]
		attr :name
		
		# The parent command, if this is a nested command.
		# 
		# @attribute [Command | Nil]
		attr :parent
		
		# Duplicate the command with additional arguments.
		# 
		# @parameter input [Array(String)] The additional command-line arguments to parse.
		# @returns [Command] The duplicated command instance.
		def [](*input)
			self.dup.tap{|command| command.parse(input)}
		end
		
		# Check if the given token is a help request for this command.
		#
		# @parameter token [String | Nil] The token to check.
		# @returns [Boolean] True if the token requests help.
		def help_token?(token)
			self.class.help_token?(token)
		end
		
		# Parse the command-line input.
		#
		# @parameter input [Array(String)] The command-line arguments to parse.
		# @returns [Command] The command instance.
		# @raises [Help] If help is requested, e.g. by `--help`.
		# @raises [InvalidInputError] If the input could not be completely parsed.
		def parse(input)
			self.class.table.merged.parse(input, self)
			
			if input.empty?
				return self
			elsif Help.token?(input.first, self)
				raise Help.new(self)
			else
				raise InvalidInputError.new(self, input)
			end
		end
		
		# Print usage information for this command.
		# 
		# @parameter output [IO] The output stream to print to.
		# @parameter formatter [Class] The formatter class to use for output.
		# @yields {|formatter| ...} A block to customize the output.
		def print_usage(output: self.output, formatter: Output::UsageFormatter, &block)
			rows = Output::Rows.new
			
			self.class.usage(rows, @name)
			
			formatter.print(rows, output, &block)
		end
	end
end
