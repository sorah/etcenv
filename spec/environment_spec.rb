require 'spec_helper'
require 'etcd'
require 'etcenv/environment'

describe Etcenv::Environment do
  def generate_etcd_tree(tree, path = [])
    Hash[tree.map do |k,v|
      new_path = path + [k]
      case v
      when Hash
        [k.to_s, generate_etcd_tree(v, new_path)]
      else
        [k.to_s, double("etcd-node #{new_path.join(?/)}",
          key: "/#{new_path.join(?/)}",
          value: v,
          dir: false,
          modified_index: 0,
        )]
      end
    end]
  end

  def generate_etcd_dir(tree, path)
    children = tree.map do |k,v|
      case v
      when Hash
        generate_etcd_dir(v, path + [k])
      else
        v
      end
    end

    double("etcd dir #{path.join(?/)}",
           key: "/#{path.join(?/)}",
           children: children,
           value: nil,
           dir: true,
          )
  end

  def generate_etcd_double(tree)
    double('etcd').tap do |etcd|
      allow(etcd).to receive(:get) do |key|
        path = key.split(?/).tap(&:shift)
        raw_value = path.inject(tree) do |head, path_part|
          head && head[path_part]
        end

        if raw_value
          node = case raw_value
                 when Hash
                   generate_etcd_dir(raw_value,path)
                 else
                   raw_value
                 end

          double('etcd response',
            node: node,
            value: node.value,
          )
        else
          raise Etcd::KeyNotFound
        end
      end
    end
  end

  def mock_etcd(tree)
    generate_etcd_double(generate_etcd_tree(tree))
  end


  let(:tree) do
    {
    }
  end

  let(:etcd) { mock_etcd(tree) }
  let(:root_key) { '/a' }
  subject(:environment) { described_class.new(etcd, root_key) }

  subject { environment.env }

  context "with simple namespace" do
    let(:tree) do
      {
        a: {
          FOO: "foo",
          BAR: "bar",
        }
      }
    end

    it { is_expected.to eq("FOO" => "foo", "BAR" => "bar",) }
  end

  context "with one including" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          FOO: "foo",
          BAR: "bar",
        },
        b: {
          BAZ: "baz",
        }
      }
    end

    it { is_expected.to eq("FOO" => "foo", "BAR" => "bar", "BAZ" => "baz",) }
  end

  context "with including (conflict)" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          FOO: "foo",
          BAR: "bar",
        },
        b: {
          BAR: "baz",
        }
      }
    end

    it { is_expected.to eq("FOO" => "foo", "BAR" => "bar",) }
  end

  context "with complex including" do
    let(:tree) do
      {
        a: {
          ".include" => "b0",
          A0: "a0",
        },
        b0: {
          ".include" => "c0,c1,c2,d1",
          B0: "b0",
        },
        c0: {
          ".include" => "d0",
          C0: "c0",
        },
        c1: {
          ".include" => "d0",
          C1: "c1",
        },
        c2: {
          ".include" => "d0,d1",
          C2: "c2",
        },
        d0: {
          D0: "d0",
        },
        d1: {
          D1: "d1",
        },
      }
    end

    it { is_expected.to eq("A0" => "a0", "B0" => "b0", "C0" => "c0", "C1" => "c1", "C2" => "c2", "D0" => "d0", "D1" => "d1",) }
  end

  context "with nested including (conflict)" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          A: "a",
        },
        b: {
          ".include" => "c",
          A: "b",
          B: "b",
        },
        c: {
          A: "c",
          B: "c",
          C: "c",
        },
      }
    end

    it {
      is_expected.to eq(
        "A" => "a",
        "B" => "b",
        "C" => "c",
      )
    }
  end

  context "with complex nested including (conflict)" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          A: "a",
        },
        b: {
          ".include" => "c,d",
          A: "b",
          B: "b",
          D: "b",
        },
        c: {
          ".include" => "d",
          A: "c",
          B: "c",
          C: "c",
          D: "c",
        },
        d: {
          D: "d",
        }
      }
    end

    it {
      is_expected.to eq(
        "A" => "a",
        "B" => "b",
        "C" => "c",
        "D" => "b",
      )
    }
  end

  context "with too deep including" do
    let(:tree) do
      {
        a: { ".include" => "b", A: "0", },
        b: { ".include" => "c", A: "1", },
        c: { ".include" => "d", A: "2", },
        d: { ".include" => "e", A: "3", },
        e: { ".include" => "f", A: "4", },
        f: { ".include" => "g", A: "5", },
        g: { ".include" => "h", A: "6", },
        h: { ".include" => "i", A: "7", },
        i: { ".include" => "j", A: "8", },
        j: { ".include" => "k", A: "9", },
        k: { A: "10", },
      }
    end

    specify {
      expect { subject }.to raise_error(Etcenv::Environment::DepthLimitError)
    }
  end

  context "with looped including" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          A: "a",
        },
        b: {
          ".include" => "a",
          B: "b",
        },
      }
    end

    specify {
      expect { subject }.to raise_error(Etcenv::Environment::LoopError)
    }
  end

  context "with nested looped including" do
    let(:tree) do
      {
        a: {
          ".include" => "b",
          A: "a",
        },
        b: {
          ".include" => "c",
        },
        c: {
          ".include" => "a",
          C: "c",
        },
      }
    end

    specify {
      expect { subject }.to raise_error(Etcenv::Environment::LoopError)
    }
  end
end
