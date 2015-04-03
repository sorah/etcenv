require 'etcenv/variable_expander'

module Etcenv
  class DotenvFile
    def initialize(env)
      @env = env
    end

    attr_reader :env

    def expanded_env
      VariableExpander.expand @env
    end

    def lines
      expanded_env.map { |k, v| make_dotenv_line(k, v) }
    end

    def to_s
      lines.join(?\n) + ?\n
    end

    private

    SHOULD_QUOTE = /\n|"|#|\$/
    def make_dotenv_line(k,v)
      if v.match(SHOULD_QUOTE)
        v.gsub!('"', '\"')
        v.gsub!("\n", '\n')
        v.gsub!(/\$([^(])/, '\$\1')
        "#{k}=\"#{v}\""
      else
        "#{k}=#{v}"
      end
    end
  end
end
