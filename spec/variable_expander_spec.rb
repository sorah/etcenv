require 'spec_helper'
require 'etcenv/variable_expander'

describe Etcenv::VariableExpander do
  let(:string) { '' }
  let(:variables) { { 'VAR' => 'var', 'STR' => string } }
  subject(:result) { described_class.expand(variables) }

  describe "single expansion" do
    subject { result['STR'] }

    context "no variables" do
      it { is_expected.to eq '' }
    end

    context "with variable" do
      let(:string) { "$VAR" }

      it { is_expected.to eq 'var' }
    end

    context "with {variable}" do
      let(:string) { "${VAR}" }

      it { is_expected.to eq 'var' }
    end

    context "with unexist variable" do
      let(:string) { "$NOVAR" }

      it { is_expected.to eq '' }
    end

    context "with string including variable" do
      let(:string) { "foo $VAR baz" }

      it { is_expected.to eq "foo var baz" }
    end

    context "with string including variable" do
      let(:string) { "foo ${VAR} baz" }

      it { is_expected.to eq "foo var baz" }
    end

    context "with multiple variable expansions" do
      let(:string) { "${VAR}${VAR}" }

      it { is_expected.to eq "varvar" }
    end

    context "with multiple variables expansions" do
      let(:variables) { { 'VAR' => 'var', 'VAR2' => 'var2', 'STR' => string } }
      let(:string) { "${VAR}${VAR2}" }

      it { is_expected.to eq "varvar2" }
    end

    context "with multiple variables expansions" do
      let(:variables) { { 'VAR' => 'var', 'VAR2' => 'var2', 'STR' => string } }
      let(:string) { "${VAR}${VAR2}" }

      it { is_expected.to eq "varvar2" }
    end

    context "with escaped variable" do
      let(:string) { "\\$VAR" }

      it { is_expected.to eq "$VAR" }
    end

    context "with escaped {variable}" do
      let(:string) { "\\${VAR}" }

      it { is_expected.to eq "${VAR}" }
    end

    context "with escaped variable and variable" do
      let(:string) { "$VAR \\$VAR $VAR" }

      it { is_expected.to eq "var $VAR var" }
    end
  end

  describe "multiple expansions" do
    let(:variables) do
      {
        'VAR2' => '${VAR}',
        'VAR' => 'var'
      }
    end

    it "resolves correctly" do
      expect(subject['VAR']).to eq 'var'
      expect(subject['VAR2']).to eq 'var'
    end
  end

  describe "nested multiple expansions" do
    # VALUE
    #   VAR
    #     FOO, BAZ
    #       BAR
    #     VAR2
    let(:variables) do
      {
        'VAR2' => '${VAR}',
        'BAR' => '${FOO} bar ${BAZ}',
        'VAR' => '${VALUE}',
        'FOO' => 'foo ${VAR}',
        'BAZ' => 'baz ${VAR}',
        'VALUE' => 'var'
      }
    end

    it "resolves correctly" do
      expect(result).to eq(
        'VALUE' => 'var',
        'VAR' => 'var',
        'FOO' => 'foo var',
        'BAZ' => 'baz var',
        'BAR' => 'foo var bar baz var',
        'VAR2' => 'var',
      )
    end
  end

  context "looped multiple expansions with root" do
    # VAR
    #   VAR2
    let(:variables) do
      {
        'ROOT' => '${VAR}',
        'VAR2' => '${VAR}',
        'VAR' => '${VAR2}',
      }
    end

    it "raises error" do
      expect { subject }.to raise_error(Etcenv::VariableExpander::LoopError)
    end
  end


  context "looped multiple expansions" do
    # VAR
    #   VAR2
    let(:variables) do
      {
        'VAR2' => '${VAR}',
        'VAR' => '${VAR2}',
      }
    end

    it "raises error" do
      expect { subject }.to raise_error(Etcenv::VariableExpander::LoopError)
    end
  end

  context "nested looped multiple expansions" do
    # VAR
    #   VAR2
    #     VAR3
    let(:variables) do
      {
        'VAR' => '${VAR2}',
        'VAR2' => '${VAR3}',
        'VAR3' => '${VAR}',
      }
    end

    it "raises error" do
      expect { subject }.to raise_error(Etcenv::VariableExpander::LoopError)
    end
  end

  context "exceed max_depth" do
    # VAR
    #   VAR2
    #     VAR3
    let(:variables) do
      Hash[(1..50).map do |i|
        ["VAR#{i}", (1...i).map { |_| "${VAR#{_}}" }.join]
      end]
    end

    it "raises error" do
      expect { subject }.to raise_error(Etcenv::VariableExpander::DepthLimitError)
    end
  end

  context "empty" do
    let(:variables) do
      {}
    end

    it { is_expected.to eq({}) }
  end
end
