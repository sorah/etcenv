require 'spec_helper'
require 'etcenv/dotenv_file'

describe Etcenv::DotenvFile do
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

    context "for env contains multiple lines" do
      let(:env) { {'KEY' => "a\nb"} }

      it { is_expected.to eq 'KEY="a\nb"' + "\n" }
    end

    context "for env contains #" do
      let(:env) { {'KEY' => "a#b"} }

      it { is_expected.to eq 'KEY="a#b"' + "\n" }
    end

    context 'for env contains "' do
      let(:env) { {'KEY' => 'a"b'} }

      it { is_expected.to eq 'KEY="a\"b"' + "\n" }
    end

    context 'for env contains $(..)' do
      let(:env) { {'KEY' => 'a$(..)'} }

      it { is_expected.to eq 'KEY="a$(..)"' + "\n" }
    end

    context 'for env contains ${..}' do
      let(:env) { {'KEY' => 'var', 'KEY2' => '${KEY}'} }

      it { is_expected.to eq "KEY=var\nKEY2=var\n" }
    end

    context 'for env contains $..' do
      let(:env) { {'KEY' => 'var', 'KEY2' => '$KEY'} }

      it { is_expected.to eq "KEY=var\nKEY2=var\n" }
    end

    context 'for env contains \${..}' do
      let(:env) { {'KEY' => 'a\${XX}'} } 

      it { is_expected.to eq 'KEY="a\${XX}"' + "\n" }
    end

    context 'for env contains \$..' do
      let(:env) { {'KEY' => 'a\$FOO'} }

      it { is_expected.to eq 'KEY="a\$FOO"' + "\n" }
    end

    context 'for env contains \$(..)' do
      let(:env) { {'KEY' => 'a\$(..)'} }

      it { is_expected.to eq 'KEY="a\$(..)"' + "\n" }
    end
  end
end
