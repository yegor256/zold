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
require_relative '../id'
require_relative '../wallet'
require_relative '../patch'

# MERGE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # MERGE pulling command
  class Merge
    def initialize(wallets:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    # Returns the array of modified wallets (IDs)
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold merge [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      mine = @wallets.all if mine.empty?
      modified = []
      mine.each do |id|
        next unless merge(Id.new(id), Copies.new(File.join(@copies, id)), opts)
        modified << Id.new(id)
        require_relative 'propagate'
        modified += Propagate.new(wallets: @wallets, log: @log).run(args)
      end
      modified
    end

    private

    def merge(id, cps, _)
      raise "There are no remote copies of #{id}, try FETCH first" if cps.all.empty?
      wallet = @wallets.find(id)
      cps = cps.all.sort_by { |c| c[:score] }.reverse
      patch = Patch.new
      main = Wallet.new(cps[0][:path])
      patch.start(main)
      cps[1..-1].each do |c|
        extra = Wallet.new(c[:path])
        if extra.network != main.network
          @log.error("The wallet is from a different network '#{extra.network}', ours is '#{main.network}'")
          next
        end
        if extra.key != main.key
          @log.error('Public key mismatch')
          next
        end
        patch.join(extra)
      end
      modified = patch.save(wallet.path, overwrite: true)
      if modified
        @log.debug("#{cps.count} copies merged successfully into #{wallet.path}")
      else
        @log.debug("Nothing changed in #{wallet.id} after merge of #{cps.count} copies")
      end
      modified
    end
  end
end
