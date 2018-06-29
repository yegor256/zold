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

require 'csv'
require 'uri'
require 'time'
require 'fileutils'
require_relative 'backtrace'
require_relative 'node/farm'
require_relative 'atomic_file'

# The list of remotes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All remotes
  class Remotes
    # The default TCP port all nodes are supposed to use.
    PORT = 4096

    # At what amount of errors we delete the remote automatically
    TOLERANCE = 8

    # After this limit, the remote runtime must be recorded
    RUNTIME_LIMIT = 16

    # Empty, for standalone mode
    class Empty < Remotes
      def initialize
        # Nothing here
      end

      def all
        []
      end

      def iterate(_)
        # Nothing to do here
      end
    end

    # One remote.
    class Remote
      attr_reader :host, :port
      def initialize(host, port, score, idx, log: Log::Quiet.new, network: 'test')
        @host = host
        raise 'Post must be Integer' unless port.is_a?(Integer)
        @port = port
        raise 'Score must be of type Score' unless score.is_a?(Score)
        @score = score
        raise 'Idx must be of type Integer' unless idx.is_a?(Integer)
        @idx = idx
        raise 'Network can\'t be nil' if network.nil?
        @network = network
        @log = log
      end

      def http(path = '/')
        Http.new("http://#{@host}:#{@port}#{path}", @score, network: @network)
      end

      def to_s
        "#{@host}:#{@port}/#{@idx}"
      end

      def assert_code(code, response)
        msg = response.message.strip
        return if response.code.to_i == code
        @log.debug("#{response.code} \"#{response.message}\" at \"#{response.body}\"")
        raise "Unexpected HTTP code #{response.code}, instead of #{code}" if msg.empty?
        raise "#{msg} (HTTP code #{response.code}, instead of #{code})"
      end

      def assert_valid_score(score)
        raise "Invalid score #{score}" unless score.valid?
        raise "Expired score #{score}" if score.expired?
      end

      def assert_score_ownership(score)
        raise "Masqueraded host #{@host} as #{score.host}: #{score}" if @host != score.host
        raise "Masqueraded port #{@port} as #{score.port}: #{score}" if @port != score.port
      end

      def assert_score_strength(score)
        raise "Score #{score.strength} is too weak (<#{Score::STRENGTH}): #{score}" if score.strength < Score::STRENGTH
      end

      def assert_score_value(score, min)
        raise "Score is too small (<#{min}): #{score}" if score.value < min
      end
    end

    def initialize(file, network: 'test')
      raise 'File can\'t be nil' if file.nil?
      @file = file
      raise 'Network can\'t be nil' if network.nil?
      @network = network
      @mutex = Mutex.new
    end

    def all
      list = load
      max_score = list.map { |r| r[:score] }.max || 0
      max_score = 1 if max_score.zero?
      max_errors = list.map { |r| r[:errors] }.max || 0
      max_errors = 1 if max_errors.zero?
      list.sort_by do |r|
        (1 - r[:errors] / max_errors) * 5 + (r[:score] / max_score)
      end.reverse
    end

    def clean
      save([])
    end

    def reset
      FileUtils.mkdir_p(File.dirname(@file))
      FileUtils.copy(
        File.join(File.dirname(__FILE__), '../../resources/remotes'),
        @file
      )
    end

    def exists?(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Port can\'t be nil' if port.nil?
      !load.find { |r| r[:host] == host.downcase && r[:port] == port }.nil?
    end

    def add(host, port = Remotes::PORT)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Host can\'t be empty' if host.empty?
      raise 'Port can\'t be nil' if port.nil?
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Port can\'t be zero' if port.zero?
      raise 'Port can\'t be negative' if port < 0
      raise 'Port can\'t be over 65536' if port > 0xffff
      raise "#{host}:#{port} already exists" if exists?(host, port)
      list = load
      list << { host: host.downcase, port: port, score: 0 }
      list.uniq! { |r| "#{r[:host]}:#{r[:port]}" }
      save(list)
    end

    def remove(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Port can\'t be nil' if port.nil?
      raise "#{host}:#{port} is absent" unless exists?(host, port)
      list = load
      list.reject! { |r| r[:host] == host.downcase && r[:port] == port }
      save(list)
    end

    def iterate(log, farm: Farm::Empty.new)
      raise 'Log can\'t be nil' if log.nil?
      raise 'Farm can\'t be nil' if farm.nil?
      best = farm.best[0]
      require_relative 'score'
      score = best.nil? ? Score::ZERO : best
      idx = 0
      all.each do |r|
        start = Time.now
        begin
          yield Remotes::Remote.new(r[:host], r[:port], score, idx, log: log, network: @network)
          idx += 1
          raise 'Took too long to execute' if (Time.now - start).round > Remotes::RUNTIME_LIMIT
        rescue StandardError => e
          error(r[:host], r[:port])
          errors = errors(r[:host], r[:port])
          check_for_non_fatal_errors(r[:host], r[:port]).each do |error|
            log.info("#{Rainbow("#{r[:host]}:#{r[:port]}").red}: #{error} \
              in #{(Time.now - start).round}s;")
          end
          log.info("#{Rainbow("#{r[:host]}:#{r[:port]}").red}: #{e.message} \
in #{(Time.now - start).round}s; errors=#{errors}")
          log.debug(Backtrace.new(e).to_s)
          remove(r[:host], r[:port]) if errors > Remotes::TOLERANCE
        end
      end
    end

    def check_for_non_fatal_errors(host, port = Remotes::PORT)
      non_fatal_errors = []
      non_fatal_errors.push("#{host}:#{port} is absent among #{load.count} remotes") unless exists?(host, port)
      non_fatal_errors
    end

    def check_for_fatal_errors(host, port = Remotes::PORT)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Port can\'t be nil' if port.nil?
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
    end

    def errors(host, port = Remotes::PORT)
      check_for_fatal_errors(host, port)
      list = load
      errors = 0
      errors = list.find { |r| r[:host] == host.downcase && r[:port] == port }[:errors] unless exists?(host, port)
      errors
    end

    def error(host, port = Remotes::PORT)
      check_for_fatal_errors(host, port)
      list = load
      list.find { |r| r[:host] == host.downcase && r[:port] == port }[:errors] += 1 unless exists?(host, port)
      save(list)
    end

    def rescore(host, port, score)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Port can\'t be nil' if port.nil?
      raise 'Score can\'t be nil' if score.nil?
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise "#{host}:#{port} is absent" unless exists?(host, port)
      list = load
      list.find { |r| r[:host] == host.downcase && r[:port] == port }[:score] = score
      save(list)
    end

    private

    def load
      @mutex.synchronize do
        raw = CSV.read(file).map do |r|
          {
            host: r[0],
            port: r[1].to_i,
            score: r[2].to_i,
            errors: r[3].to_i
          }
        end
        raw.reject { |r| !r[:host] || r[:port].zero? }.map do |r|
          r[:home] = URI("http://#{r[:host]}:#{r[:port]}/")
          r
        end
      end
    end

    def save(list)
      @mutex.synchronize do
        AtomicFile.new(file).write(
          list.map do |r|
            [
              r[:host],
              r[:port],
              r[:score],
              r[:errors]
            ].join(',')
          end.join("\n")
        )
      end
    end

    def file
      reset unless File.exist?(@file)
      @file
    end
  end
end
