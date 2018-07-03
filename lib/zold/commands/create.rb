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
require_relative '../wallet'
require_relative '../log'
require_relative '../id'

# CREATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Create command
  class Create
    def initialize(wallets:, log: Log::Quiet.new)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = <<~HELP.chomp
          Usage: zold create [options]
          Available options:
        HELP
        o.string '--public-key',
          'The location of RSA public key (default: ~/.ssh/id_rsa.pub)',
          require: true,
          default: '~/.ssh/id_rsa.pub'
        o.string '--network',
          "The name of the network (default: #{Wallet::MAIN_NETWORK}",
          require: true,
          default: Wallet::MAIN_NETWORK
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      create(mine.empty? ? Id.new : Id.new(mine[0]), opts)
    end

    private

    def create(id, opts)
      wallet = @wallets.find(id)
      key = Zold::Key.new(file: opts['public-key'])
      wallet.init(id, key, network: opts['network'])
      @log.info(wallet.id)
      @log.debug("Wallet #{Rainbow(wallet).green} created at #{@wallets.path}")
      wallet
    end
  end
end
