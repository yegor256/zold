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

require 'minitest/autorun'
require 'concurrent'
require 'threads'
require_relative 'test__helper'
require_relative 'fake_home'
require 'zold/key'
require 'zold/id'
require 'zold/wallets'
require 'zold/sync_wallets'
require 'zold/amount'

# SyncWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestSyncWallets < Zold::Test
  def test_adds_wallet
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      id = Zold::Id.new
      home.create_wallet(id)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      amount = Zold::Amount.new(zld: 5.0)
      Threads.new(5).assert(100) do
        wallets.acq(id, exclusive: true) do |wallet|
          wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
          wallet.refurbish
        end
      end
      # assert_equal_wait(amount * -100, max: 4) do
      #   wallets.acq(id, &:balance)
      # end
    end
  end
end
