module Etcenv
  class VariableExpander
    class LoopError < StandardError; end
    class DepthLimitError < StandardError; end

    MAX_DEPTH_DEFAULT = 50

    def self.expand(variables, max = MAX_DEPTH_DEFAULT)
      new(variables).expand(max)
    end

    def initialize(variables)
      @variables = variables.dup.freeze
    end

    attr_reader :variables

    def expand(max = MAX_DEPTH_DEFAULT)
      detect_loop!

      result = {}
      solve_order(max).map do |x|
        result[x] = single_expand(@variables[x], result)
      end
      result
    end

    def variable_with_deps
      @variables.map { |k, v| [k, [v, detect_variables(v)]] }
    end

    def dependees_by_variable
      @dependees_by_variable ||= variable_with_deps.inject({}) do |r, x|
        k, v, deps = x[0], x[1][0], x[1][1]

        deps.each do |dep|
          r[dep] ||= []
          r[dep] << k
        end
        r
      end.freeze
    end

    def root_variables
      @root_variables ||= variable_with_deps.inject([]) do |r, x|
        k, v, deps = x[0], x[1][0], x[1][1]
        if deps.empty?
          r << k
        end
        r
      end + (variables.keys - dependees_by_variable.keys)
    end

    def detect_loop!
      if root_variables.empty?
        raise LoopError, "there's no possible root variables (variables which don't have dependee)"
      else
        dependees_by_variable.each do |k, deps|
          deps.each do |dep|
            if (dependees_by_variable[dep] || []).include?(k)
              raise LoopError, "There's a loop between $#{dep} and $#{k}"
            end
          end
        end
      end
    end

    def solve_order(max_depth = 10)
      order = []
      solve = nil
      solve = ->(vs, depth = 0) do
        raise DepthLimitError if depth.succ > max_depth
        vs.each do |x|
          order.concat solve.call(dependees_by_variable[x] || [], depth.succ) + [x]
        end
      end
      solve.call(root_variables)

      uniq_with_keeping_first_appearance(order).reverse
    end

    private

    VARIABLE = /
      (?<escape>\\?)
      \$
      (
        {(?<name>[a-zA-Z0-9_]+)}
      |
        \g<name>
      )
    /x

    def detect_variables(str)
      result = []

      pos = 0
      while match = str.match(VARIABLE, pos)
        pos = match.end(0)
        next if match['escape'] == '\\'

        result << match['name']
      end

      result
    end

    def single_expand(str, variables)
      str.gsub(VARIABLE) do |variable|
        match = $~

        if match['escape'] == '\\'
          variable[1..-1]
        else
          variables[match['name']].to_s
        end
      end
    end

    def uniq_with_keeping_first_appearance(array)
      set = {}
      result = []
      array.each do |x|
        next if set[x]
        result.push x
        set[x] = true
      end
      result
    end
  end
end
