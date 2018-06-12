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

require_relative 'log'
require_relative 'wallet'
require_relative 'signature'
require_relative 'atomic_file'

# Patch.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A patch
  class Patch
    def initialize(log: Log::Quiet.new)
      @log = log
    end

    def to_s
      return 'empty' if @id.nil?
      "#{@txns.count} txns"
    end

    def join(wallet)
      if @id.nil?
        @id = wallet.id
        @key = wallet.key
        @txns = wallet.txns
        @log.debug("The baseline: #{@txns.count} transactions, the balance is #{wallet.balance}")
        @network = wallet.network
      end
      if wallet.network != @network
        raise "The wallet is from a different network '#{wallet.network}', ours is '#{@network}'"
      end
      raise 'Public key mismatch' if wallet.key != @key
      raise "Wallet ID mismatch: #{@id} != #{wallet.id}" if wallet.id != @id
      negative = @txns.select { |t| t.amount.negative? }
      max = negative.empty? ? 0 : negative.max_by(&:id).id
      wallet.txns.each do |txn|
        next if @txns.find { |t| t == txn }
        if txn.amount.negative?
          if txn.id <= max
            @log.debug("Transaction ID is less than max #{max}: #{txn.to_text}")
            next
          end
          if @txns.find { |t| t.id == txn.id }
            @log.debug("Transaction ##{txn.id} already exists: #{txn.to_text}")
            next
          end
          if !@txns.empty? && @txns.map(&:amount).inject(&:+) < txn.amount
            @log.debug("Transaction ##{txn.id} attempts to make the balance negative: #{txn.to_text}")
            next
          end
          unless Signature.new.valid?(@key, wallet.id, txn)
            @log.debug("Invalid RSA signature at transaction ##{txn.id} of #{wallet.id}: #{txn.to_text}")
            next
          end
        elsif !txn.sign.nil? && !txn.sign.empty?
          @log.debug("RSA signature is redundant at ##{txn.id} of #{wallet.id}: #{txn.to_text}")
          next
        end
        @log.debug("Merged on top: #{txn.to_text}")
        @txns << txn
      end
    end

    # Returns TRUE if the file was actually modified
    def save(file, overwrite: false)
      raise 'You have to join at least one wallet in' if @id.nil?
      before = ''
      before = AtomicFile.new(file).read if File.exist?(file)
      wallet = Wallet.new(file)
      wallet.init(@id, @key, overwrite: overwrite, network: @network)
      @txns.each { |t| wallet.add(t) }
      after = AtomicFile.new(file).read
      before != after
    end
  end
end
