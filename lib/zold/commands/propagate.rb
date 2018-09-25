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

require 'slop'
require 'rainbow'
require_relative 'args'
require_relative '../log'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../prefixes'

# PROPAGATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # PROPAGATE pulling command
  class Propagate
    def initialize(wallets:, log: Log::Quiet.new)
      @wallets = wallets
      @log = log
    end

    # Returns list of Wallet IDs which were affected
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = <<~HELP.chomp
          Usage: zold propagate [ID...] [options]
          Available options:
        HELP
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      mine = @wallets.all if mine.empty?
      modified = []
      mine.map { |i| Id.new(i) }.each do |id|
        modified += propagate(id, opts)
      end
      modified
    end

    private

    # Returns list of Wallet IDs which were affected
    def propagate(id, _)
      modified = []
      @wallets.find(id) do |wallet|
        wallet.txns.select { |t| t.amount.negative? }.each do |t|
          next if t.bnf == id
          @wallets.find(t.bnf) do |target|
            unless target.exists?
              @log.debug("#{t.amount * -1} to #{t.bnf}: wallet is absent")
              next
            end
            unless target.network == wallet.network
              @log.error("#{t.amount * -1} to #{t.bnf}: network mismatch, '#{target.network}'!='#{wallet.network}'")
              next
            end
            next if target.has?(t.id, id)
            unless target.prefix?(t.prefix)
              @log.error("#{t.amount * -1} to #{t.bnf}: wrong prefix")
              next
            end
            target.add(t.inverse(id))
            @log.info("#{t.amount * -1} arrived to #{t.bnf}: #{t.details}")
            modified << t.bnf
          end
        end
      end
      modified.uniq!
      @log.debug("Wallet #{id} propagated successfully, #{modified.count} wallets affected")
      modified
    end
  end
end
