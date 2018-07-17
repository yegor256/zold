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

require 'time'
require 'openssl'
require_relative 'version'
require_relative 'key'
require_relative 'id'
require_relative 'txn'
require_relative 'tax'
require_relative 'amount'
require_relative 'signature'
require_relative 'atomic_file'

# The wallet.
#
# It is a text file with a name equal to the wallet ID, which is
# a hexadecimal number of 16 digits, for example: "0123456789abcdef".
# More details about its format is in README.md.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A single wallet
  class Wallet
    # The name of the main production network. All other networks
    # must have different names.
    MAIN_NETWORK = 'zold'

    # The extension of the wallet files
    EXTENSION = '.z'

    def initialize(file)
      @file = file
      @file = "#{file}#{EXTENSION}" if File.extname(file).empty?
    end

    def ==(other)
      to_s == other.to_s
    end

    def to_s
      id.to_s
    end

    def network
      n = lines[0].strip
      raise "Invalid network name '#{n}'" unless n =~ /^[a-z]{4,16}$/
      n
    end

    def protocol
      v = lines[1].strip
      raise "Invalid protocol version name '#{v}'" unless v =~ /^[0-9]+$/
      v.to_i
    end

    def exists?
      File.exist?(@file)
    end

    def path
      @file
    end

    def init(id, pubkey, overwrite: false, network: 'test')
      raise "File '#{@file}' already exists" if File.exist?(@file) && !overwrite
      raise "Invalid network name '#{network}'" unless network =~ /^[a-z]{4,16}$/
      AtomicFile.new(@file).write("#{network}\n#{PROTOCOL}\n#{id}\n#{pubkey.to_pub}\n\n")
    end

    def root?
      id == Id::ROOT
    end

    def id
      Id.new(lines[2].strip)
    end

    def balance
      txns.inject(Amount::ZERO) { |sum, t| sum + t.amount }
    end

    def sub(amount, invoice, pvt, details = '-', time: Time.now)
      raise 'The amount has to be of type Amount' unless amount.is_a?(Amount)
      raise "The amount can't be negative: #{amount}" if amount.negative?
      raise 'The pvt has to be of type Key' unless pvt.is_a?(Key)
      prefix, target = invoice.split('@')
      tid = max + 1
      raise 'Too many transactions already, can\'t add more' if max > 0xffff
      txn = Txn.new(
        tid,
        time,
        amount * -1,
        prefix,
        Id.new(target),
        details
      )
      txn = txn.signed(pvt, id)
      raise 'This is not the private right key for this wallet' unless Signature.new.valid?(key, id, txn)
      add(txn)
      txn
    end

    def add(txn)
      raise "Wallet amount will exceed MAX if applied #{txn}" if (balance.to_i + txn.amount.to_i).abs > Amount::MAX
      raise 'The txn has to be of type Txn' unless txn.is_a?(Txn)
      dup = txns.find { |t| t.bnf == txn.bnf && t.id == txn.id }
      raise "The transaction with the same ID and BNF already exists: #{dup}" unless dup.nil?
      raise "The tax payment already exists: #{txn}" if Tax.new(self).exists?(txn)
      File.open(@file, 'a') { |f| f.print "#{txn}\n" }
    end

    def has?(id, bnf)
      raise 'The txn ID has to be of type Integer' unless id.is_a?(Integer)
      raise 'The bnf has to be of type Id' unless bnf.is_a?(Id)
      !txns.find { |t| t.id == id && t.bnf == bnf }.nil?
    end

    def prefix?(prefix)
      key.to_pub.include?(prefix)
    end

    def key
      Key.new(text: lines[3].strip)
    end

    def income
      txns.each do |t|
        yield t unless t.amount.negative?
      end
    end

    def mtime
      File.mtime(@file)
    end

    def digest
      OpenSSL::Digest::SHA256.new(File.read(@file)).hexdigest
    end

    # Age of wallet in hours
    def age
      list = txns
      list.empty? ? 0 : (Time.now - list.min_by(&:date).date) / 60
    end

    def txns
      lines.drop(5)
        .each_with_index
        .map { |line, i| Txn.parse(line, i + 6) }
        .sort_by { |t| [t.date, t.amount * -1] }
    end

    def refurbish
      AtomicFile.new(@file).write(
        "#{network}\n#{protocol}\n#{id}\n#{key.to_pub}\n\n#{txns.map { |t| t.to_s + "\n" }.join}"
      )
    end

    private

    def max
      negative = txns.select { |t| t.amount.negative? }
      negative.empty? ? 0 : negative.max_by(&:id).id
    end

    def lines
      raise "Wallet file '#{@file}' is absent" unless File.exist?(@file)
      lines = AtomicFile.new(@file).read.split(/\n/)
      raise "Not enough lines in #{@file}, just #{lines.count}" if lines.count < 4
      lines
    end
  end
end
