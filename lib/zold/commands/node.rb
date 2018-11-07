# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
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
require 'backtrace'
require 'concurrent'
require 'zold/score'
require_relative '../version'
require_relative '../age'
require_relative '../metronome'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../remotes'
require_relative '../verbose_thread'
require_relative '../node/farmers'
require_relative '../node/entrance'
require_relative '../node/safe_entrance'
require_relative '../node/spread_entrance'
require_relative '../node/async_entrance'
require_relative '../node/sync_entrance'
require_relative '../node/nodup_entrance'
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
    def initialize(wallets:, remotes:, copies:, log: Log::Quiet.new)
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
          "TCP port to open for the Net (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.integer '--bind-port',
          "TCP port to listen on (default: #{Remotes::PORT})",
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
        o.boolean '--nohup',
          'Run it in background, rebooting when a higher version is available in the network',
          default: false
        o.string '--nohup-command',
          'The command to run in server "nohup" mode (default: "gem install zold")',
          default: 'gem install zold'
        o.string '--nohup-log',
          'The file to log output into (default: zold.log)',
          default: 'zold.log'
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
        o.string '--expose-version',
          "The version of the software to expose in JSON (default: #{VERSION})",
          default: VERSION
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          default: '~/.ssh/id_rsa'
        o.string '--network',
          "The name of the network (default: #{Wallet::MAIN_NETWORK})",
          require: true,
          default: Wallet::MAIN_NETWORK
        o.integer '--nohup-max-cycles',
          'Maximum amount of nohup re-starts (-1 by default, which means forever)',
          require: true,
          default: -1
        o.string '--home',
          "Home directory (default: #{Dir.pwd})",
          default: Dir.pwd
        o.bool '--no-metronome',
          'Don\'t run the metronome',
          required: true,
          default: false
        o.bool '--disable-push',
          'Prohibit all PUSH requests',
          default: false
        o.bool '--disable-fetch',
          'Prohibit all FETCH requests',
          default: false
        o.string '--alias',
          'The alias of the node (default: host:port)',
          require: false
        o.string '--no-spawn',
          'Don\'t use child processes for the score farm',
          default: false
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise '--invoice is mandatory' unless opts['invoice']
      if opts['nohup']
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
      Front.set(:version, opts['expose-version'])
      Front.set(:protocol, Zold::PROTOCOL)
      Front.set(:logging, @log.debug?)
      Front.set(:halt, opts['halt-code'])
      Front.set(:disable_push, opts['disable-push'])
      Front.set(:disable_fetch, opts['disable-fetch'])
      home = File.expand_path(opts['home'])
      Front.set(:home, home)
      @log.info("Time: #{Time.now.utc.iso8601}")
      @log.info("Home directory: #{home}")
      @log.info("Ruby version: #{RUBY_VERSION}")
      @log.info("Zold gem version: #{Zold::VERSION}")
      @log.info("Zold protocol version: #{Zold::PROTOCOL}")
      @log.info("Network ID: #{opts['network']}")
      host = opts[:host] || ip
      port = opts[:port]
      address = "#{host}:#{port}".downcase
      @log.info("Node location: #{address}")
      @log.info("Local address: http://localhost:#{opts['bind-port']}/")
      @log.info("Remote nodes (#{@remotes.all.count}): \
#{@remotes.all.map { |r| "#{r[:host]}:#{r[:port]}" }.join(', ')}")
      @log.info("Wallets at: #{@wallets.path}")
      if opts['standalone']
        @remotes = Zold::Remotes::Empty.new
        @log.info('Running in standalone mode! (will never talk to other remotes)')
      elsif @remotes.exists?(host, port)
        Zold::Remote.new(remotes: @remotes).run(['remote', 'remove', host, port.to_s])
        @log.info("Removed current node (#{address}) from list of remotes")
      end
      Front.set(:ignore_score_weakness, opts['ignore-score-weakness'])
      Front.set(:network, opts['network'])
      Front.set(:wallets, @wallets)
      Front.set(:remotes, @remotes)
      Front.set(:copies, @copies)
      Front.set(:address, address)
      Front.set(:root, home)
      Front.set(:dump_errors, opts['dump-errors'])
      Front.set(:port, opts['bind-port'])
      Front.set(:reboot, !opts['never-reboot'])
      node_alias = opts[:alias] || address
      unless node_alias.eql?(address) || node_alias =~ /^[A-Za-z0-9]{4,16}$/
        raise "Alias should be a 4 to 16 char long alphanumeric string: #{node_alias}"
      end
      Front.set(:node_alias, node_alias)
      invoice = opts[:invoice]
      unless invoice.include?('@')
        require_relative 'invoice'
        invoice = Invoice.new(
          wallets: @wallets, remotes: @remotes, copies: @copies, log: @log
        ).run(['invoice', invoice, "--network=#{opts['network']}"])
      end
      SafeEntrance.new(
        NoDupEntrance.new(
          AsyncEntrance.new(
            SpreadEntrance.new(
              SyncEntrance.new(
                Entrance.new(
                  @wallets,
                  @remotes, @copies, address,
                  log: @log, network: opts['network']
                ),
                File.join(home, '.zoldata/sync-entrance'),
                log: @log
              ),
              @wallets, @remotes, address,
              log: @log,
              ignore_score_weakeness: opts['ignore-score-weakness']
            ),
            File.join(home, '.zoldata/async-entrance'), log: @log
          ),
          @wallets
        ),
        network: opts['network']
      ).start do |entrance|
        Front.set(:entrance, entrance)
        farmer = opts['no-spawn'] ? Farmers::Plain.new : Farmers::Spawn.new(log: @log)
        Farm.new(invoice, File.join(home, 'farm'), log: @log, farmer: farmer)
          .start(host, opts[:port], threads: opts[:threads], strength: opts[:strength]) do |farm|
          Front.set(:farm, farm)
          metronome(farm, opts).start do |metronome|
            Front.set(:metronome, metronome)
            @log.info("Starting up the web front at http://#{host}:#{opts[:port]}...")
            Front.run!
            @log.info("The web front stopped at http://#{host}:#{opts[:port]}")
            @log.info('Thanks for helping Zold network!')
          end
        end
      end
    end

    private

    # Returns exit code
    def exec(cmd, nohup_log)
      start = Time.now
      Open3.popen2e(cmd) do |stdin, stdout, thr|
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
        nohup_log = NohupLog.new(opts['nohup-log'], opts['nohup-log-truncate'])
        Signal.trap('HUP') do
          nohup_log.print("Received HUP, ignoring...\n")
        end
        Signal.trap('TERM') do
          nohup_log.print("Received TERM, terminating...\n")
          exit(-1)
        end
        myself = File.expand_path($PROGRAM_NAME)
        args = ARGV.delete_if { |a| a.start_with?('--home') || a == '--nohup' }
        cycle = 0
        loop do
          begin
            code = exec("#{myself} #{args.join(' ')}", nohup_log)
            raise "Exit code is #{code}" if code != 0
            Open3.popen3('gem uninstall zold -a --ignore-dependencies') do
              exec(opts['nohup-command'], nohup_log)
            end
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

    def metronome(farm, opts)
      metronome = Metronome.new(@log)
      if opts['no-metronome']
        @log.info('Metronome hasn\'t been started because of --no-metronome')
        return metronome
      end
      # This was a good idea to spread wallets among other nodes,
      # but with the growing number of wallets it's obvious that this
      # doesn't make a lot of sense. We better focus of HungryWallets
      # implementation, where wallets are being pulled if they are missed.
      # require_relative 'routines/spread'
      # metronome.add(Routines::Spread.new(opts, @wallets, @remotes, log: @log))
      unless opts['standalone']
        require_relative 'routines/reconnect'
        metronome.add(Routines::Reconnect.new(opts, @remotes, farm, network: opts['network'], log: @log))
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
  end
end
