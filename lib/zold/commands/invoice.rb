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
require_relative 'args'
require_relative '../log'
require_relative '../prefixes'

# INVOICE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Generate invoice
  class Invoice
    def initialize(wallets:, log: Log::Quiet.new)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = <<~HELP.chomp
          Usage: zold invoice ID [options]
          Where:
              'ID' is the wallet ID of the money receiver
          Available options:
        HELP
        o.integer '--length',
          'The length of the invoice prefix (default: 8)',
          default: 8
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'Receiver wallet ID is required' if mine[0].nil?
      id = Zold::Id.new(mine[0])
      wallet = @wallets.find(id)
      raise "Wallet #{id} doesn\'t exist in #{@wallets}, do 'zold pull' first" unless wallet.exists?
      invoice(wallet, opts)
    end

    private

    def invoice(wallet, opts)
      invoice = "#{Prefixes.new(wallet).create(opts[:length])}@#{wallet.id}"
      @log.info(invoice)
      invoice
    end
  end
end
