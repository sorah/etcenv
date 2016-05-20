require 'thread'

module Etcenv
  class Watcher
    WATCH_TIMEOUT = 120

    def initialize(env, verbose: false)
      @env = env
      @verbose = verbose
      @indices = {}
      @lock = Mutex.new
    end

    attr_reader :env, :verbose

    def etcd
      env.etcd
    end

    def watch
      ch = Queue.new
      threads = env.modified_indices.map do |key, index|
        Thread.new(ch, key, index, &method(:watch_thread)).tap do |th|
          th.abort_on_exception = true
        end
      end
      report = ch.pop
      threads.each(&:kill)
      report
    end

    def auto_reload_loop
      loop do
        begin
          watch
          $stderr.puts "[watcher] reloading env #{env.root_key}" if verbose
          env.load
          yield env if block_given?
        rescue => e
          $stderr.puts "[watcher][error] Failed to reload env #{env.root_key}: #{e.inspect}"
          $stderr.puts "\t#{e.backtrace.join("\n\t")}"
        end
      end
    end

    private

    def watch_thread(ch, key, index)
      tries = 0
      loop do
        if try_watch(key, index)
          ch << key
          break
        end
        interval = (2 ** tries) * 0.1
        $stderr.puts "[watcher] RETRYING; #{key.inspect} watch will resume after #{'%.2f' % interval} sec"
        sleep interval
        tries += 1
      end
    end

    def try_watch(key, index)
      $stderr.puts "[watcher] waiting for change on #{key} (index: #{index.succ})" if verbose
      index = [@indices[key], index].compact.max
      index += 1 if index
      response = etcd.watch(key, recursive: true, index: index, timeout: WATCH_TIMEOUT)
      @lock.synchronize do
        # Record modified_index in watcher itself; Because the latest index may be hidden in normal response
        # e.g. unlisted keys, removed keys
        @indices[key] = response.node.modified_index
      end
      $stderr.puts "[watcher] dir #{key} has updated" if verbose
      ch << key
      return true
    rescue Etcd::EventIndexCleared => e
      $stderr.puts "[watcher] #{e.inspect} on key #{key.inspect}, trying to get X-Etcd-Index"
      @lock.synchronize do
        @indices[key] = etcd.get(key).etcd_index
      end
      $stderr.puts "[watcher] Updated #{key.inspect} index to #{@indices[key]}"
      return nil
    rescue Net::ReadTimeout
      $stderr.puts "[watcher] #{e.inspect} on key #{key.inspect}"
      return nil
    end
  end
end
