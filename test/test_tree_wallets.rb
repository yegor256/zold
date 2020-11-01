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
require 'zold/wallet'
require 'zold/key'
require 'zold/id'
require 'zold/tree_wallets'

# TreeWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestTreeWallets < Zold::Test
  def test_adds_wallet
    Dir.mktmpdir do |dir|
      wallets = Zold::TreeWallets.new(dir)
      id = Zold::Id.new('abcd0123abcd0123')
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert(wallet.path.end_with?('/a/b/c/d/abcd0123abcd0123.z'), wallet.path)
      end
      assert_equal(1, wallets.all.count)
      assert_equal(id, wallets.all[0])
    end
  end

  def test_adds_many_wallets
    Dir.mktmpdir do |dir|
      wallets = Zold::TreeWallets.new(dir)
      10.times do
        id = Zold::Id.new
        wallets.acq(id, exclusive: true) do |wallet|
          wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        end
      end
      assert_equal(10, wallets.all.count)
    end
  end

  def test_count_tree_wallets
    files = [
      "0000111122223333#{Zold::Wallet::EXT}",
      "a/b/d/e/0000111122223333#{Zold::Wallet::EXT}",
      "a/b/0000111122223333#{Zold::Wallet::EXT}"
    ]
    garbage = [
      '0000111122223333',
      '0000111122223333.lock',
      'a/b/c-0000111122223333'
    ]
    Dir.mktmpdir do |dir|
      (files + garbage).each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      wallets = Zold::TreeWallets.new(dir)
      assert_equal(files.count, wallets.count)
    end
  end
end
