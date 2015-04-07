module Etcenv
  class Environment
    class NotDirectory < StandardError; end
    class DepthLimitError < StandardError; end
    class LoopError < StandardError; end

    INCLUDE_KEY = '.include'
    MAX_DEPTH_DEFAULT = 10

    def initialize(etcd, root_key, max_depth: MAX_DEPTH_DEFAULT)
      @etcd = etcd
      @root_key = root_key
      @max_depth = max_depth
      @lock = Mutex.new
      load
    end
    
    attr_reader :root_key, :env, :etcd
    attr_accessor :max_depth

    def modified_indices
      @modified_indices ||= {}
    end

    def load
      @lock.synchronize do
        flush
        env = {}
        includes.each do |name|
          env.merge! fetch(name)
        end
        env.delete '.include'
        @env = env
      end
      self
    end

    private

    def flush
      @env = {}
      @includes = nil
      @cache = {}
      @modified_indices = {}
      self
    end

    def includes
      @includes ||= solve_include_order(root_key)
    end

    def default_prefix
      root_key.sub(/^(.*)\/.+?$/, '\1')
    end

    def resolve_key(key)
      if key.start_with?('/')
        key
      else
        default_prefix + '/' + key
      end
    end

    def cache
      @cache ||= {}
    end

    def fetch(name)
      key = resolve_key(name)
      return cache[key] if cache[key]

      node = @etcd.get(key).node

      unless node.dir
        raise NotDirectory, "#{key} is not a directory"
      end

      dir = {}
      index = 0

      node.children.each do |child|
        name = child.key.sub(/^.*\//, '')

        index = [index, child.modified_index].max
        if child.dir
          next
        else
          dir[name] = child.value
        end
      end

      modified_indices[key] = index
      cache[key] = dir
    end

    def solve_include_order(name, path = [])
      if path.include?(name)
        raise LoopError, "Found an include loop at path: #{path.inspect}"
      end

      path = path + [name]
      if max_depth < path.size
        raise DepthLimitError, "Reached maximum depth (path: #{path.inspect})"
      end

      node = fetch(name)

      if node[INCLUDE_KEY]
        node[INCLUDE_KEY].split(/,\s*/).flat_map do |x|
          solve_include_order(x, path)
        end + [name]
      else
        [name]
      end
    end
  end
end
