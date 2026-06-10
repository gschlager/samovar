# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

module Samovar
	# The base class for all Samovar errors.
	class Error < StandardError
	end
	
	# Raised when invalid input is provided on the command line.
	class InvalidInputError < Error
		# Initialize a new invalid input error.
		# 
		# @parameter command [Command] The command that encountered the error.
		# @parameter input [Array(String)] The remaining input that could not be parsed.
		def initialize(command, input)
			@command = command
			@input = input
			
			super "Could not parse token #{input.first.inspect}"
		end
		
		# The token that could not be parsed.
		# 
		# @returns [String] The first unparsed token.
		def token
			@input.first
		end
		
		# Check if the error was caused by a help request.
		# 
		# @returns [Boolean] True if the token is `--help`.
		def help?
			self.token == "--help"
		end
		
		# The command that encountered the error.
		# 
		# @attribute [Command]
		attr :command
		
		# The remaining input that could not be parsed.
		# 
		# @attribute [Array(String)]
		attr :input
	end
	
	# Raised when help is requested on the command line.
	#
	# This is not a failure: it represents a recognized request to print usage information. It is raised during parsing, before any required-argument validation, so `--help` works even when the command line is incomplete. It inherits from {Error} so that generic error handling still prints usage, however {Command.call} handles it explicitly by printing usage to the command's output without an error message.
	class Help < Error
		# Check if the given token is a help request in the context of the given command.
		#
		# Without a command context, only `--help` is recognized. With a command context, the command decides, e.g. `-h` is only a help request if no other option claims it.
		#
		# @parameter token [String | Nil] The token to check.
		# @parameter command [Command | Nil] The command providing context for the check.
		# @returns [Boolean] True if the token requests help.
		def self.token?(token, command = nil)
			if command and command.respond_to?(:help_token?)
				command.help_token?(token)
			else
				token == "--help"
			end
		end
		
		# Initialize a new help request.
		#
		# @parameter command [Command] The command for which help was requested.
		def initialize(command)
			@command = command
			
			super "Help requested"
		end
		
		# The command for which help was requested.
		#
		# @attribute [Command]
		attr :command
	end
	
	# Raised when a required value is missing.
	class MissingValueError < Error
		# Initialize a new missing value error.
		# 
		# @parameter command [Command] The command that encountered the error.
		# @parameter field [Symbol] The name of the missing field.
		def initialize(command, field)
			@command = command
			@field = field
			
			super "#{field} is required"
		end
		
		# The command that encountered the error.
		# 
		# @attribute [Command]
		attr :command
		
		# The name of the missing field.
		# 
		# @attribute [Symbol]
		attr :field
	end
end
