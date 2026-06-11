# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "samovar/flags"

describe Samovar::Flags do
	let(:flags) {subject.new("-f/--flag")}
	
	it "can count flags" do
		expect(flags.count).to be == 1
	end
	
	it "returns nil when no match" do
		result = flags.parse(["--other"])
		expect(result).to be_nil
	end
end

describe Samovar::BooleanFlag do
	let(:flag) {Samovar::Flag.parse("--[no]-color")}
	
	it "can check prefix" do
		expect(flag.prefix?("--color")).to be == true
		expect(flag.prefix?("--no-color")).to be == true
		expect(flag.prefix?("--other")).to be == false
	end
end

describe Samovar::ValueFlag do
	let(:flag) {Samovar::Flag.parse("--config <path>")}
	
	it "parses a value provided with an equals sign" do
		input = ["--config=app.yml"]
		expect(flag.parse(input)).to be == "app.yml"
		expect(input).to be(:empty?)
	end
	
	it "splits on the first equals sign only" do
		expect(flag.parse(["--config=a=b"])).to be == "a=b"
	end
	
	it "ignores tokens that do not match the prefix" do
		input = ["--other=value"]
		expect(flag.parse(input)).to be_nil
		expect(input).to be == ["--other=value"]
	end
	
	it "does not parse the equals sign form for a flag that takes no value" do
		boolean = Samovar::Flag.parse("--verbose")
		input = ["--verbose=x"]
		expect(boolean.parse(input)).to be_nil
		expect(input).to be == ["--verbose=x"]
	end
end
