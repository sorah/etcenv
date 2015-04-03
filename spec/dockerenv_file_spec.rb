require 'spec_helper'
require 'etcenv/dockerenv_file'
require 'etcenv/variable_expander'

describe Etcenv::DockerenvFile do
  let(:env) { {'KEY' => 'VALUE'} }
  subject(:dotenv_file) { described_class.new(env) }

  describe "#to_s" do
    subject { dotenv_file.to_s.lines.sort_by { |_| _.split(?=,2)[0] }.join }

    before do
      expect(Etcenv::VariableExpander).to receive(:expand).with(env).and_call_original
    end

    context "for normal env" do
      let(:env) { {'KEY' => 'VALUE'} }

      it { is_expected.to eq "KEY=VALUE\n" }
    end

    context "for multiple env" do
      let(:env) { {'KEY' => 'VALUE', 'KEY2' => 'VALUE2'} }

      it { is_expected.to eq "KEY=VALUE\nKEY2=VALUE2\n" }
    end

    context "with variable expansion" do
      let(:env) { {'KEY2' => "KEY is ${KEY}", 'KEY' => 'value'} }

      it { is_expected.to eq "KEY=value\nKEY2=KEY is value\n" }
    end

    context "with escaped variable expansion" do
      let(:env) { {'KEY2' => '\${KEY}', 'KEY' => 'value'} }

      it { is_expected.to eq "KEY=value\nKEY2=${KEY}\n" }
    end

    context "with nested variable expansion" do
      # Place KEY2 earlier so ensure it doesn't depend on order
      let(:env) { {'KEY2' => '${KEY}', 'KEY' => 'value', 'KEY3' => 'KEY is ${KEY2}'} }

      it { is_expected.to eq "KEY=value\nKEY2=value\nKEY3=KEY is value\n" }
    end
  end
end
