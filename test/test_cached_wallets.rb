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
require 'zold/cached_wallets'
require 'zold/amount'

# CachedWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestCachedWallets < Zold::Test
  def test_adds_wallet
    Dir.mktmpdir do |dir|
      wallets = Zold::CachedWallets.new(Zold::Wallets.new(dir))
      id = Zold::Id.new
      first = nil
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
        first = wallet
      end
      wallets.acq(id) do |wallet|
        assert_equal(first, wallet)
      end
    end
  end

  def test_flushes_correctly
    Dir.mktmpdir do |dir|
      wallets = Zold::CachedWallets.new(Zold::Wallets.new(dir))
      id = Zold::Id.new
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      body = wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        IO.read(wallet.path)
      end
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.sub(Zold::Amount.new(zld: 1.0), "NOPREFIX@#{Zold::Id.new}", key)
      end
      assert_equal(1, wallets.acq(id, &:txns).count)
      wallets.acq(id, exclusive: true) do |wallet|
        IO.write(wallet.path, body)
      end
      assert_equal(0, wallets.acq(id, &:txns).count)
    end
  end
end
