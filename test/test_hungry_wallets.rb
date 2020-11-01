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
require 'webmock/minitest'
require_relative 'test__helper'
require_relative 'fake_home'
require 'zold/key'
require 'zold/thread_pool'
require 'zold/wallets'
require 'zold/hungry_wallets'

# HungryWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestHungryWallets < Zold::Test
  def test_pulls_wallet
    FakeHome.new(log: test_log).run do |home|
      id = Zold::Id.new
      get = stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 404)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      pool = Zold::ThreadPool.new('test', log: test_log)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: test_log
      )
      wallets.acq(id) { |w| assert(!w.exists?) }
      pool.join(2)
      assert_requested(get, times: 1)
    end
  end

  def test_doesnt_pull_twice_if_not_found
    FakeHome.new(log: test_log).run do |home|
      id = Zold::Id.new
      get = stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 404)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      pool = Zold::ThreadPool.new('test', log: test_log)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: test_log
      )
      3.times do
        wallets.acq(id) { |w| assert(!w.exists?) }
        sleep 0.2
      end
      pool.join(2)
      assert_requested(get, times: 1)
    end
  end

  def test_doesnt_pull_wallet_if_exists
    FakeHome.new(log: test_log).run do |home|
      pool = Zold::ThreadPool.new('test', log: test_log)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      wallet = home.create_wallet
      get = stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(status: 200)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: test_log
      )
      wallets.acq(wallet.id) { |w| assert(w.exists?) }
      pool.join(2)
      assert_requested(get, times: 0)
    end
  end
end
