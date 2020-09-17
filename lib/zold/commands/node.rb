# frozen_string_literal: true

# Copyright (c) 2018-2020 Zerocracy, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'open3'
require 'slop'
require 'shellwords'
require 'backtrace'
require 'fileutils'
require 'zache'
require 'concurrent'
require 'zold/score'
require_relative 'thread_badge'
require_relative '../version'
require_relative '../age'
require_relative '../metronome'
require_relative '../thread_pool'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../hungry_wallets'
require_relative '../remotes'
require_relative '../verbose_thread'
require_relative '../node/farmers'
require_relative '../node/entrance'
require_relative '../node/safe_entrance'
require_relative '../node/spread_entrance'
require_relative '../node/async_entrance'
require_relative '../node/sync_entrance'
require_relative '../node/nodup_entrance'
require_relative '../node/nospam_entrance'
require_relative '../node/pipeline'
require_relative '../node/journaled_pipeline'
require_relative '../node/front'
require_relative '../node/trace'
require_relative '../node/farm'
require_relative 'pull'
require_relative 'push'
require_relative 'pay'
require_relative 'remote'

# NODE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # NODE command
  class Node
    prepend ThreadBadge

    def initialize(wallets:, remotes:, copies:, log: Log::NULL)
      @remotes = remotes
      @copies = copies
      @log = log
      @wallets = wallets
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = 'Usage: zold node [options]'
        o.string '--invoice',
          'The invoice you want to collect money to or the wallet ID',
          required: true
        o.integer '--port',
          "TCP port to announce in Zold Network (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.integer '--bind-port',
          "TCP port to listen on, which may differ from --port if you are behind a proxy (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.string '--host',
          'Host name (will attempt to auto-detect it, if not specified)'
        o.integer '--strength',
          "The strength of the score (default: #{Score::STRENGTH})",
          default: Score::STRENGTH
        o.integer '--threads',
          "How many threads to use for scores finding (default: #{[Concurrent.processor_count / 2, 2].max})",
          default: [Concurrent.processor_count / 2, 2].max
        o.bool '--dump-errors',
          'Make HTTP front-end errors visible in the log (false by default)',
          default: false
        o.bool '--standalone',
          'Never communicate with other nodes (mostly for testing)',
          default: false
        o.bool '--ignore-score-weakness',
          'Ignore score weakness of incoming requests and register those nodes anyway',
          default: false
        o.bool '--tolerate-edges',
          'Don\'t fail if only "edge" (not "master" ones) nodes accepted/have the wallet',
          default: false
        o.integer '--tolerate-quorum',
          'The minimum number of nodes required for a successful fetch (default: 4)',
          default: 4
        o.boolean '--nohup',
          'Run it in background, rebooting when a higher version is available in the network',
          default: false
        o.string '--nohup-command',
          'The command to run in server "nohup" mode (default: "gem install zold")',
          default: 'gem install zold'
        o.string '--nohup-log',
          'The file to log output into (default: zold.log)',
          default: 'zold.log'
        o.string '--nohup-log-rotate',
          'Frequency of the log file rotation (daily, weekly or monthly)'
        o.integer '--nohup-log-truncate',
          'The maximum amount of bytes to keep in the file, and truncate it in half if it grows bigger',
          default: 1024 * 1024
        o.string '--halt-code',
          'The value of HTTP query parameter "halt," which will cause the front-end immediate termination',
          default: ''
        o.integer '--trace-length',
          'Maximum length of the trace to keep in memory (default: 4096)',
          default: 4096
        o.string '--save-pid',
          'The file to save process ID into right after start (only in NOHUP mode)'
        o.bool '--never-reboot',
          'Don\'t reboot when a new version shows up in the network',
          default: false
        o.bool '--routine-immediately',
          'Run all routines immediately, without waiting between executions (for testing mostly)',
          default: false
        o.bool '--no-cache',
          'Skip caching of front JSON pages (will seriously slow down, mostly useful for testing)',
          default: false
        o.boolean '--skip-audit',
          'Don\'t report audit information to the console every minute',
          default: false
        o.boolean '--skip-reconnect',
          'Don\'t reconnect to the network every minute (for testing)',
          default: false
        o.boolean '--not-hungry',
          'Don\'t do hugry pulling of missed nodes (mostly for testing)',
          default: false
        o.bool '--allow-spam',
          'Don\'t filter the incoming spam via PUT requests (duplicate wallets)',
          default: false
        o.bool '--ignore-empty-remotes',
          'Don\'t fail if the list of remotes is empty (for testing mostly)',
          default: false
        o.bool '--skip-oom',
          'Skip Out Of Memory check and never exit, no matter how much RAM is consumed',
          default: false
        o.integer '--oom-limit',
          "Maximum amount of memory we can consume, quit if we take more than that, in Mb (default: #{oom_limit})",
          default: oom_limit
        o.integer '--queue-limit',
          'The maximum number of wallets to be accepted via PUSH and stored in the queue (default: 256)',
          default: 256
        o.bool '--skip-gc',
          'Don\'t run garbage collector and never remove any wallets from the disk',
          default: false
        o.integer '--gc-age',
          'Maximum time in seconds to keep an empty and unused wallet on the disk',
          default: 60 * 60 * 24 * 10
        o.string '--expose-version',
          "The version of the software to expose in JSON (default: #{VERSION})",
          default: VERSION
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          default: '~/.ssh/id_rsa'
        o.string '--network',
          "The name of the network (default: #{Wallet::MAINET})",
          default: Wallet::MAINET
        o.integer '--nohup-max-cycles',
          'Maximum amount of nohup re-starts (-1 by default, which means forever)',
          default: -1
        o.string '--home',
          "Home directory (default: #{Dir.pwd})",
          default: Dir.pwd
        o.bool '--no-metronome',
          'Don\'t run the metronome',
          default: false
        o.bool '--disable-push',
          'Prohibit all PUSH requests',
          default: false
        o.bool '--disable-fetch',
          'Prohibit all FETCH requests',
          default: false
        o.string '--alias',
          'The alias of the node (default: host:port)'
        o.string '--farmer',
          'The name of the farmer, e.g. "plain", "spawn", "fork" (default: "plain")',
          default: 'plain'
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise '--invoice is mandatory' unless opts['invoice']
      if opts['nohup']
        if @remotes.all.empty? && !opts['standalone'] && !opts['ignore-empty-remotes']
          raise 'There are no remote nodes in the list and you are not running in --standalone mode;
the node won\'t connect to the network like that; try to do "zold remote reset" first'
        end
        pid = nohup(opts)
        IO.write(opts['save-pid'], pid) if opts['save-pid']
        @log.debug("Process ID #{pid} saved into \"#{opts['save-pid']}\"")
        @log.info(pid)
        return
      end
      @log = Trace.new(@log, opts['trace-length'])
      Front.set(:log, @log)
      Front.set(:logger, @log)
      Front.set(:trace, @log)
      Front.set(:nohup_log, opts['nohup-log']) if opts['nohup-log']
      Front.set(:protocol, Zold::PROTOCOL)
      Front.set(:logging, @log.debug?)
      home = File.expand_path(opts['home'])
      Front.set(:home, home)
      @log.info("Time: #{Time.now.utc.iso8601}; CPUs: #{Concurrent.processor_count}")
      @log.info("Home directory: #{home}")
      @log.info("Ruby version: #{RUBY_VERSION}/#{RUBY_PLATFORM}")
      @log.info("Zold gem version: #{Zold::VERSION}")
      @log.info("Zold protocol version: #{Zold::PROTOCOL}")
      @log.info("Network ID: #{opts['network']}")
      @log.info('Front caching is disabled via --no-cache') if opts['no-cache']
      host = opts[:host] || ip
      port = opts[:port]
      address = "#{host}:#{port}".downcase
      @log.info("Node location: #{address}")
      @log.info("Local address: http://127.0.0.1:#{opts['bind-port']}/")
      @log.info("Remote nodes (#{@remotes.all.count}): \
#{@remotes.all.map { |r| "#{r[:host]}:#{r[:port]}" }.join(', ')}")
      @log.info("Wallets at: #{@wallets.path}")
      if opts['standalone']
        @remotes = Remotes::Empty.new
        @log.info('Running in standalone mode! (will never talk to other remotes)')
      elsif @remotes.exists?(host, port)
        Remote.new(remotes: @remotes).run(['remote', 'remove', host, port.to_s])
        @log.info("Removed current node (#{address}) from list of remotes")
      end
      if File.exist?(@copies)
        FileUtils.rm_rf(@copies)
        @log.info("Directory #{@copies} deleted")
      end
      wts = @wallets
      if opts['not-hungry']
        @log.info('Hungry pulling disabled because of --not-hungry')
      else
        hungry = ThreadPool.new('hungry', log: @log)
        wts = HungryWallets.new(@wallets, @remotes, @copies, hungry, log: @log, network: opts['network'])
      end
      Front.set(:zache, Zache.new(dirty: true))
      Front.set(:wallets, wts)
      Front.set(:remotes, @remotes)
      Front.set(:copies, @copies)
      Front.set(:address, address)
      Front.set(:root, home)
      ledger = File.join(home, 'ledger.csv')
      Front.set(:ledger, ledger)
      Front.set(:opts, opts)
      Front.set(:dump_errors, opts['dump-errors'])
      Front.set(:port, opts['bind-port'])
      async_dir = File.join(home, '.zoldata/async-entrance')
      FileUtils.mkdir_p(async_dir)
      Front.set(:async_dir, async_dir)
      journal_dir = File.join(home, '.zoldata/journal')
      FileUtils.mkdir_p(journal_dir)
      Front.set(:journal_dir, journal_dir)
      Front.set(:node_alias, node_alias(opts, address))
      entrance = SafeEntrance.new(
        NoSpamEntrance.new(
          NoDupEntrance.new(
            AsyncEntrance.new(
              SpreadEntrance.new(
                SyncEntrance.new(
                  Entrance.new(
                    wts,
                    JournaledPipeline.new(
                      Pipeline.new(
                        @remotes, @copies, address,
                        ledger: ledger,
                        network: opts['network']
                      ),
                      journal_dir
                    ),
                    log: @log
                  ),
                  File.join(home, '.zoldata/sync-entrance'),
                  log: @log
                ),
                wts, @remotes, address,
                log: @log,
                ignore_score_weakeness: opts['ignore-score-weakness'],
                tolerate_edges: opts['tolerate-edges']
              ),
              async_dir,
              log: @log,
              queue_limit: opts['queue-limit']
            ),
            wts,
            log: @log
          ),
          period: opts['allow-spam'] ? 0 : 60 * 60,
          log: @log
        ),
        network: opts['network']
      )
      entrance.start do |ent|
        Front.set(:entrance, ent)
        farm = Farm.new(
          invoice(opts), File.join(home, 'farm'),
          log: @log, farmer: farmer(opts), strength: opts[:strength]
        )
        farm.start(host, opts[:port], threads: opts[:threads]) do |f|
          Front.set(:farm, f)
          metronome(f, opts, host, port).start do |metronome|
            Front.set(:metronome, metronome)
            @log.info("Starting up the web front at http://#{host}:#{opts[:port]}...")
            Front.run!
            @log.info("The web front stopped at http://#{host}:#{opts[:port]}")
          end
        end
      end
      hungry.kill unless opts['not-hungry']
      @log.info('Thanks for helping Zold network!')
    end

    private

    def invoice(opts)
      invoice = opts['invoice']
      unless invoice.include?('@')
        require_relative 'invoice'
        invoice = Invoice.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
          ['invoice', invoice, "--network=#{Shellwords.escape(opts['network'])}"] +
          ["--tolerate-quorum=#{Shellwords.escape(opts['tolerate-quorum'])}"] +
          (opts['tolerate-edges'] ? ['--tolerate-edges'] : [])
        )
      end
      invoice
    end

    def node_alias(opts, address)
      a = opts[:alias] || address
      unless a.eql?(address) || a =~ /^[A-Za-z0-9]{4,16}$/
        raise "Alias should be a 4 to 16 char long alphanumeric string: #{a}"
      end
      a
    end

    def farmer(opts)
      case opts['farmer'].downcase.strip
      when 'plain'
        @log.debug('"Plain" farmer is used, only one CPU core will be utilized')
        Farmers::Plain.new
      when 'fork'
        @log.debug('"Fork" farmer is used')
        Farmers::Fork.new(log: @log)
      when 'spawn'
        @log.debug('"Spawn" farmer is used')
        Farmers::Spawn.new(log: @log)
      else
        raise "Farmer name is not recognized: #{opts['farmer']}"
      end
    end

    # Returns exit code
    def exec(cmd, nohup_log)
      start = Time.now
      Open3.popen2e({ 'MALLOC_ARENA_MAX' => '2' }, cmd) do |stdin, stdout, thr|
        nohup_log.print("Started process ##{thr.pid} from process ##{Process.pid}: #{cmd}\n")
        stdin.close
        until stdout.eof?
          begin
            line = stdout.gets
          rescue IOError => e
            line = Backtrace.new(e).to_s
          end
          nohup_log.print(line)
        end
        nohup_log.print("Nothing else left to read from ##{thr.pid}\n")
        code = thr.value.to_i
        nohup_log.print("Exit code of process ##{thr.pid} is #{code}, was alive for #{Age.new(start)}: #{cmd}\n")
        code
      end
    end

    def nohup(opts)
      pid = fork do
        nohup_log =
          if opts['nohup-log-rotate']
            NohupLogRotate.new(opts['nohup-log'], opts['nohup-log-rotate'])
          else
            NohupLog.new(opts['nohup-log'], opts['nohup-log-truncate'])
          end
        Signal.trap('HUP') do
          Thread.new { nohup_log.print("Received HUP, ignoring...\n") }.join
        end
        Signal.trap('TERM') do
          Thread.new { nohup_log.print("Received TERM, terminating...\n") }.join
          exit(-1)
        end
        myself = File.expand_path($PROGRAM_NAME)
        args = ARGV.delete_if { |a| a.start_with?('--home') || a == '--nohup' }
        cycle = 0
        loop do
          begin
            code = exec("#{myself} #{args.join(' ')}", nohup_log)
            raise "Exit code is #{code}" if code != 0
            exec(opts['nohup-command'], nohup_log)
          rescue StandardError => e
            nohup_log.print(Backtrace.new(e).to_s)
            if cycle < opts['nohup-max-cycles']
              nohup_log.print("Let's wait for a minutes, because of the exception...")
              sleep(60)
            end
          end
          next if opts['nohup-max-cycles'].negative?
          cycle += 1
          if cycle > opts['nohup-max-cycles']
            nohup_log.print("There are no more nohup cycles left, after the cycle no.#{cycle}")
            break
          end
          nohup_log.print("Going for nohup cycle no.#{cycle}")
        end
      end
      Process.detach(pid)
      pid
    end

    def metronome(farm, opts, host, port)
      metronome = Metronome.new(@log)
      if opts['no-metronome']
        @log.info("Metronome hasn't been started because of --no-metronome")
        return metronome
      end
      if opts['skip-gc']
        @log.info('Garbage collection is disabled because of --skip-gc')
      else
        require_relative 'routines/gc'
        metronome.add(Routines::Gc.new(opts, @wallets, log: @log))
      end
      if opts['skip-audit']
        @log.info('Audit is disabled because of --skip-audit')
      else
        require_relative 'routines/audit'
        metronome.add(Routines::Audit.new(opts, @wallets, log: @log))
      end
      unless opts['standalone']
        if opts['skip-reconnect']
          @log.info('Reconnect is disabled because of --skip-reconnect')
        else
          require_relative 'routines/reconnect'
          metronome.add(Routines::Reconnect.new(opts, @remotes, farm, log: @log))
        end
      end
      require_relative 'routines/spread'
      metronome.add(Routines::Spread.new(opts, @wallets, @remotes, @copies, log: @log))
      require_relative 'routines/retire'
      metronome.add(Routines::Retire.new(opts, log: @log))
      if @remotes.master?(host, port)
        require_relative 'routines/reconcile'
        metronome.add(Routines::Reconcile.new(opts, @wallets, @remotes, @copies, "#{host}:#{port}", log: @log))
      else
        @log.info('This is not master, no need to reconcile')
      end
      @log.info('Metronome started (use --no-metronome to disable it)')
      metronome
    end

    def ip
      addr = Socket.ip_address_list.detect do |i|
        i.ipv4? && !i.ipv4_loopback? && !i.ipv4_multicast? && !i.ipv4_private?
      end
      raise 'Can\'t detect your IP address, you have to specify it in --host' if addr.nil?
      addr.ip_address
    end

    def oom_limit
      require 'total'
      Total::Mem.new.bytes / (1024 * 1024) / 2
    rescue Total::CantDetect => e
      @log.error(e.message)
      512
    end

    # Log facility for nohup
    class NohupLog
      def initialize(file, max)
        @file = file
        raise "Truncation size is too small (#{max}), should be over 10Kb" if max < 10 * 1024
        @max = max
      end

      def print(data)
        File.open(@file, 'a') { |f| f.print(data) }
        return if File.size(@file) < @max
        temp = Tempfile.new
        total = copy(@file, temp)
        unit = File.size(@file) / total
        tail = total - @max / (2 * unit)
        copy(temp, @file, tail)
        File.delete(temp)
        File.open(@file, 'a') do |f|
          f.print("The file was truncated, because it was over the quota of #{@max} bytes, \
#{tail} lines left out of #{total}, average line length was #{unit} bytes\n\n")
        end
      end

      def copy(source, target, start = 0)
        total = 0
        File.open(target, 'w') do |t|
          File.open(source, 'r').each do |line|
            next unless total >= start
            t.print(line)
            total += 1
          end
        end
        total
      end
    end

    # Rotated log facility for nohup
    class NohupLogRotate
      def initialize(file_path, rotation_age = 'daily')
        @logger = ::Logger.new(file_path, rotation_age)
      end

      def print(data)
        @logger << data
      end
    end
  end
end
