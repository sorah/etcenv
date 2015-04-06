require 'optparse'
require 'thread'
require 'openssl'
require 'etcd'
require 'uri'
require 'etcenv/dockerenv_file'
require 'etcenv/dotenv_file'
require 'etcenv/watcher'

module Etcenv
  class Cli
    def initialize(*argv)
      @argv = argv
      @options = {
        etcd: URI.parse("http://localhost:2379"),
        format: DotenvFile,
        perm: 0600,
        mode: :oneshot,
      }
      parse!
    end

    attr_reader :argv, :options

    def run
      parse!

      case options[:mode]
      when :oneshot
        oneshot
      when :watch
        watch
      else
        raise "[BUG] unknown mode"
      end
    end

    def parse!
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: etcenv [options] key ..."

        opts.on("-h", "--help", "show this help") do
          puts opts
          exit 0
        end

        opts.on("--watch", "-w", "continuous update mode") do
          options[:mode] = :watch
        end

        opts.on("-o PATH", "--output PATH", "save to speciifed file") do |path|
          options[:output] = path
        end

        opts.on("-m MODE", "--mode MODE", "mode (permission) to use when creating --output file, in octal. Default: 0600") do |perm|
          options[:perm] = perm.to_i(8)
        end

        opts.on("--docker", "use docker env-file format instead of dotenv.gem format") do
          options[:format] = DockerenvFile
        end

        opts.on("--etcd URL", "URL of etcd to connect; Any paths are ignored.") do |url|
          options[:etcd] = URI.parse(url)
        end

        opts.on("--etcd-ca-file PATH", "Path to CA certificate file (PEM) of etcd server") do |path|
          options[:etcd_ca_file] = path
        end

        opts.on("--etcd-cert-file PATH", "Path to client certificate file (PEM) for etcd server") do |path|
          options[:etcd_tls_cert] = OpenSSL::X509::Certificate.new(File.read(path))
        end

        opts.on("--etcd-key-file PATH", "Path to private key file for client certificate for etcd server") do |path|
          options[:etcd_tls_key] = OpenSSL::PKey::RSA.new(File.read(path))
        end
      end
      parser.parse!(argv)
    end

    def etcd
      @etcd ||= Etcd.client(
        host: options[:etcd].host,
        port: options[:etcd].port,
        use_ssl: options[:etcd].scheme == 'https',
        ca_file: options[:etcd_ca_file],
        ssl_cert: options[:etcd_tls_cert],
        ssl_key: options[:etcd_tls_key],
      )
    end

    def oneshot
      if argv.empty?
        $stderr.puts "error: no KEY specified. See --help for detail"
        return 1
      end
      env = argv.inject(nil) do |env, key|
        new_env = Environment.new(etcd, key).env
        env ? env.merge(new_env) : new_env
      end
      dump_env(env)

      0
    end

    def watch
      if argv.empty?
        $stderr.puts "error: no KEY specified. See --help for detail"
        return 1
      end

      envs = argv.map { |key| Environment.new(etcd, key) }

      watchers = envs.map { |env| Watcher.new(env, verbose: true) }
      Thread.abort_on_exception = true

      dumper_ch = Queue.new
      dumper = Thread.new do
        loop do
          $stderr.puts "[dumper] dumping env"
          env = envs.inject(nil) do |result, env|
            result ? result.merge(env.env) : env.env
          end
          dump_env(env)
          dumper_ch.pop
        end
      end

      watchers.map do |watcher|
        Thread.new do
          watcher.auto_reload_loop do
            dumper_ch << true
          end
        end
      end

      loop { sleep 1 }
    end

    private

    def dump_env(env)
      env_file = options[:format].new(env)
      if options[:output]
        open(options[:output], "w", options[:perm]) do |io|
          io.puts env_file.to_s
        end
      else
        $stdout.puts env_file.to_s
      end
    end
  end
end
