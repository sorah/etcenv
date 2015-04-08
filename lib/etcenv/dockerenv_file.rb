require 'etcenv/variable_expander'

module Etcenv
  class DockerenvFile
    def initialize(env)
      @env = env
    end

    attr_reader :env

    def lines
      env.map { |k,v| "#{k}=#{v}" }
    end

    def to_s
      lines.join(?\n) + ?\n
    end

    private
  end
end
