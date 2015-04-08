require 'spec_helper'
require 'etcenv/dockerenv_file'
require 'etcenv/variable_expander'

describe Etcenv::DockerenvFile do
  let(:env) { {'KEY' => 'VALUE'} }
  subject(:dotenv_file) { described_class.new(env) }

  describe "#to_s" do
    subject { dotenv_file.to_s.lines.sort_by { |_| _.split(?=,2)[0] }.join }

    context "for normal env" do
      let(:env) { {'KEY' => 'VALUE'} }

      it { is_expected.to eq "KEY=VALUE\n" }
    end

    context "for multiple env" do
      let(:env) { {'KEY' => 'VALUE', 'KEY2' => 'VALUE2'} }

      it { is_expected.to eq "KEY=VALUE\nKEY2=VALUE2\n" }
    end
  end
end
