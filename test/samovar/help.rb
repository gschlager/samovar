# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Gerhard Schlager.

require "samovar"

module HelpExamples
	class Convert < Samovar::Command
		one :type, "The thing to convert."
	end
	
	class ConvertRequired < Samovar::Command
		one :type, "The thing to convert.", required: true
	end
	
	class ConvertWithHelp < Samovar::Command
		options do
			option "-h/--help", "Show help."
		end
		
		one :type, "The thing to convert."
	end
	
	class ConvertRequiredWithHelp < Samovar::Command
		options do
			option "-h/--help", "Show help."
		end
		
		one :type, "The thing to convert.", required: true
	end
	
	class ConvertWithSplit < Samovar::Command
		one :type, "The thing to convert."
		split :argv, "Arguments passed through."
	end
	
	class Serve < Samovar::Command
		options do
			option "-h/--hostname <name>", "The hostname to bind to."
		end
	end
	
	class Verbose < Samovar::Command
		options do
			option "--verbose", "Verbose output."
			option "--config <path>", "The configuration file.", required: true
		end
	end
	
	class Parent < Samovar::Command
		nested :command, {
			"convert" => Convert,
			"convert-required" => ConvertRequired,
			"serve" => Serve,
		}
	end
end

describe Samovar::Help do
	def parse_help(command_class, input)
		command_class.new(input)
	rescue Samovar::Help => help
		return help
	end
	
	it "is raised for an undeclared --help" do
		help = parse_help(HelpExamples::Convert, ["--help"])
		
		expect(help).to be_a(Samovar::Help)
		expect(help.command).to be_a(HelpExamples::Convert)
	end
	
	it "takes precedence over positional arguments" do
		help = parse_help(HelpExamples::Convert, ["--help"])
		
		# The positional argument did not swallow the help token:
		expect(help.command.type).to be_nil
	end
	
	it "takes precedence over required positional arguments" do
		help = parse_help(HelpExamples::ConvertRequired, ["--help"])
		
		expect(help).to be_a(Samovar::Help)
	end
	
	it "is raised even when --help is declared as an option" do
		help = parse_help(HelpExamples::ConvertWithHelp, ["--help"])
		
		expect(help).to be_a(Samovar::Help)
		
		# Parsing stopped before the options were parsed:
		expect(help.command.options).to be_nil
	end
	
	it "is recognized after positional arguments" do
		help = parse_help(HelpExamples::ConvertWithHelp, ["discourse", "--help"])
		
		expect(help).to be_a(Samovar::Help)
		expect(help.command.type).to be == "discourse"
	end
	
	it "takes precedence over required positional arguments when --help is declared" do
		help = parse_help(HelpExamples::ConvertRequiredWithHelp, ["--help"])
		
		expect(help).to be_a(Samovar::Help)
	end
	
	it "takes precedence over required options" do
		help = parse_help(HelpExamples::Verbose, ["--help"])
		
		expect(help).to be_a(Samovar::Help)
	end
	
	it "is recognized after other options" do
		help = parse_help(HelpExamples::Verbose, ["--verbose", "--help"])
		
		expect(help).to be_a(Samovar::Help)
		expect(help.command.options[:verbose]).to be == true
	end
	
	with "nested commands" do
		it "is routed to the nested command" do
			help = parse_help(HelpExamples::Parent, ["convert", "--help"])
			
			expect(help.command).to be_a(HelpExamples::Convert)
			expect(help.command.name).to be == "convert"
			expect(help.command.parent).to be_a(HelpExamples::Parent)
		end
		
		it "is routed to the nested command with required arguments" do
			help = parse_help(HelpExamples::Parent, ["convert-required", "--help"])
			
			expect(help.command).to be_a(HelpExamples::ConvertRequired)
		end
		
		it "is raised for the parent command when given before a nested command" do
			help = parse_help(HelpExamples::Parent, ["--help"])
			
			expect(help.command).to be_a(HelpExamples::Parent)
		end
	end
	
	with "-h" do
		it "is treated as a help request when unclaimed" do
			help = parse_help(HelpExamples::Convert, ["-h"])
			
			expect(help).to be_a(Samovar::Help)
		end
		
		it "is treated as a help request when claimed by the help option" do
			help = parse_help(HelpExamples::ConvertWithHelp, ["-h"])
			
			expect(help).to be_a(Samovar::Help)
		end
		
		it "is not treated as a help request when claimed by another option" do
			command = HelpExamples::Serve.new(["-h", "localhost"])
			
			expect(command.options[:hostname]).to be == "localhost"
		end
		
		it "does not affect --help when -h is claimed by another option" do
			help = parse_help(HelpExamples::Serve, ["--help"])
			
			expect(help).to be_a(Samovar::Help)
		end
		
		it "is claimed per command" do
			# The parent command does not claim -h, so it is a help request there:
			help = parse_help(HelpExamples::Parent, ["-h"])
			expect(help.command).to be_a(HelpExamples::Parent)
			
			# The nested command claims -h, so it is parsed as an option there:
			parent = HelpExamples::Parent.new(["serve", "-h", "localhost"])
			expect(parent.command.options[:hostname]).to be == "localhost"
		end
	end
	
	with "-- boundary" do
		it "does not treat --help after -- as a help request" do
			command = HelpExamples::ConvertWithSplit.new(["discourse", "--", "--help"])
			
			expect(command.type).to be == "discourse"
			expect(command.argv).to be == ["--help"]
		end
		
		it "passes --help through as data even without positional arguments" do
			command = HelpExamples::ConvertWithSplit.new(["--", "--help"])
			
			expect(command.type).to be_nil
			expect(command.argv).to be == ["--help"]
		end
		
		it "does not treat --help after -- as a help request without a split" do
			expect do
				HelpExamples::Convert.new(["--", "--help"])
			end.to raise_exception(Samovar::InvalidInputError, message: be(:include?, "--"))
		end
	end
	
	with ".token?" do
		it "recognizes --help without a command" do
			expect(Samovar::Help.token?("--help")).to be == true
		end
		
		it "does not recognize -h without a command" do
			expect(Samovar::Help.token?("-h")).to be == false
		end
		
		it "does not recognize nil" do
			expect(Samovar::Help.token?(nil)).to be == false
			expect(Samovar::Help.token?(nil, HelpExamples::Convert.new)).to be == false
		end
	end
	
	with "Command.call" do
		it "prints usage to the command's output and returns the command" do
			error_output = StringIO.new
			help_output = StringIO.new
			
			begin
				original_output = $stdout
				$stdout = help_output
				
				result = HelpExamples::Convert.call(["--help"], output: error_output)
			ensure
				$stdout = original_output
			end
			
			expect(result).to be_a(HelpExamples::Convert)
			expect(error_output.string).to be == ""
			expect(help_output.string).to be(:include?, "<type>")
		end
		
		it "prints usage for the nested command" do
			help_output = StringIO.new
			
			begin
				original_output = $stdout
				$stdout = help_output
				
				result = HelpExamples::Parent.call(["convert", "--help"])
			ensure
				$stdout = original_output
			end
			
			expect(result).to be_a(HelpExamples::Convert)
			expect(help_output.string).to be(:include?, "convert <type>")
		end
	end
end
