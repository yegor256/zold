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
require 'tmpdir'
require_relative 'test__helper'
require_relative 'fake_home'
require 'zold/key'
require 'zold/id'
require 'zold/wallets'
require 'zold/amount'

# Wallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestWallets < Zold::Test
  def test_adds_wallet
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      id = Zold::Id.new
      wallets.acq(id) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
      end
    end
  end

  def test_lists_wallets_and_ignores_garbage
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      FileUtils.touch(File.join(home.dir, '0xaaaaaaaaaaaaaaaaaaahello'))
      FileUtils.mkdir_p(File.join(home.dir, 'a/b/c'))
      FileUtils.touch(File.join(home.dir, 'a/b/c/0000111122223333.z'))
      id = Zold::Id.new
      wallets.acq(id) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
      end
    end
  end

  def test_substracts_dir_path_from_full_path
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        wallets = Zold::Wallets.new(Dir.pwd)
        assert_equal('.', wallets.to_s)
      end
    end
  end

  def test_count_wallets
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        5.times { |i| FileUtils.touch("wallet_#{i}#{Zold::Wallet::EXT}") }
        wallets = Zold::Wallets.new(Dir.pwd)
        assert_equal(5, wallets.count)
      end
    end
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      assert_equal(1, wallets.count)
    end
  end
end
