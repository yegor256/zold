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

require 'openssl'
require 'time'
require_relative 'remotes'
require_relative 'ext/score'

# The score.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Score
  class Score
    # Default strength for the entire system, in production mode.
    STRENGTH = 6

    # Default number of cores to use for score calculation
    CORES = 3

    attr_reader :time, :host, :port, :invoice, :strength
    # time: UTC ISO 8601 string
    def initialize(time, host, port, invoice, suffixes = [], strength: STRENGTH)
      raise "Invalid host name: #{host}" unless host =~ /^[a-z0-9\.-]+$/
      raise 'Time must be of type Time' unless time.is_a?(Time)
      raise 'Port must be of type Integer' unless port.is_a?(Integer)
      raise "Invalid TCP port: #{port}" if port <= 0 || port > 65_535
      raise "Invoice '#{invoice}' has wrong format" unless invoice =~ /^[a-zA-Z0-9]{8,32}@[a-f0-9]{16}$/
      @time = time
      @host = host
      @port = port
      @invoice = invoice
      @suffixes = suffixes
      @strength = strength
      @created = Time.now
    end

    # The default no-value score.
    ZERO = Score.new(Time.now, 'localhost', 80, 'NOPREFIX@ffffffffffffffff')

    def self.parse_json(json)
      raise "Time in JSON is broken: #{json}" unless json['time'] =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
      raise "Host is wrong: #{json}" unless json['host'] =~ /^[0-9a-z\.\-]+$/
      raise "Port is wrong: #{json}" unless json['port'].is_a?(Integer)
      raise "Invoice is wrong: #{json}" unless json['invoice'] =~ /^[a-zA-Z0-9]{8,32}@[a-f0-9]{16}$/
      raise "Suffixes not array: #{json}" unless json['suffixes'].is_a?(Array)
      Score.new(
        Time.parse(json['time']), json['host'],
        json['port'], json['invoice'], json['suffixes'],
        strength: json['strength']
      )
    end

    def self.parse(text)
      re = Regexp.new(
        '^' + [
          '([0-9]+)/(?<strength>[0-9]+):',
          ' (?<time>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          ' (?<host>[0-9a-z\.\-]+)',
          ' (?<port>[0-9]+)',
          ' (?<invoice>[a-zA-Z0-9]{8,32}@[a-f0-9]{16})',
          '(?<suffixes>( [a-zA-Z0-9]+)*)'
        ].join + '$'
      )
      m = re.match(text.strip)
      raise "Invalid score '#{text}', doesn't match: #{re}" if m.nil?
      Score.new(
        Time.parse(m[:time]), m[:host],
        m[:port].to_i, m[:invoice],
        m[:suffixes].split(' '),
        strength: m[:strength].to_i
      )
    end

    def self.parse_text(text)
      parts = text.split(' ', 7)
      Score.new(
        Time.at(parts[1].hex),
        parts[2],
        parts[3].hex,
        "#{parts[4]}@#{parts[5]}",
        parts[6] ? parts[6].split(' ') : [],
        strength: parts[0].to_i
      )
    end

    def hash
      raise 'Score has zero value, there is no hash' if @suffixes.empty?
      @suffixes.reduce(prefix) do |pfx, suffix|
        OpenSSL::Digest::SHA256.new("#{pfx} #{suffix}").hexdigest
      end
    end

    def to_mnemo
      "#{value}:#{@time.strftime('%H%M')}"
    end

    def to_text
      pfx, bnf = @invoice.split('@')
      [
        @strength,
        @time.to_i.to_s(16),
        @host,
        @port.to_s(16),
        pfx,
        bnf,
        @suffixes.join(' ')
      ].join(' ')
    end

    def to_s
      [
        "#{value}/#{@strength}:",
        @time.utc.iso8601,
        @host,
        @port,
        @invoice,
        @suffixes.join(' ')
      ].join(' ')
    end

    def to_h
      {
        value: value,
        host: @host,
        port: @port,
        invoice: @invoice,
        time: @time.utc.iso8601,
        suffixes: @suffixes,
        strength: @strength,
        hash: value.zero? ? nil : hash,
        expired: expired?,
        valid: valid?,
        age: (age / 60).round,
        created: @created.utc.iso8601
      }
    end

    def reduced(max = 4)
      Score.new(
        @time, @host, @port, @invoice,
        @suffixes[0..[max, @suffixes.count].min - 1], strength: @strength
      )
    end

    def next
      raise 'This score is not valid' unless valid?
      return Score.new(Time.now, @host, @port, @invoice, [], strength: @strength) if self.expired?
      idx = ScoreExt.calculate_nonce_multi_core(
        CORES,
        "#{@suffixes.empty? ? prefix : hash} ", @strength
      )
      suffix = idx.to_s(16)
      score = Score.new(
        @time, @host, @port, @invoice, @suffixes + [suffix],
        strength: @strength
      )
      return score if score.valid?
      raise 'Invalid score calculated'
    end

    def age
      Time.now - @time
    end

    def expired?(hours = 24)
      age > hours * 60 * 60
    end

    def prefix
      "#{@time.utc.iso8601} #{@host} #{@port} #{@invoice}"
    end

    def valid?
      @suffixes.empty? || hash.end_with?('0' * @strength)
    end

    def value
      @suffixes.length
    end
  end
end
