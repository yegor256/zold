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

require 'minitest/autorun'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/amount'

# Wallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestWallets < Minitest::Test
  def test_adds_wallet
    FakeHome.new.run do |home|
      wallets = home.wallets
      id = Zold::Id.new
      wallet = wallets.find(id)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      assert_equal(1, wallets.all.count)
    end
  end

  def test_lists_wallets_and_ignores_garbage
    FakeHome.new.run do |home|
      wallets = home.wallets
      FileUtils.touch(File.join(home.dir, '0xaaaaaaaaaaaaaaaaaaahello'))
      id = Zold::Id.new
      wallet = wallets.find(id)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      assert_equal(1, wallets.all.count)
    end
  end

  def test_return_full_directory_path_if_different_from_current_directory
    FakeHome.new.run do |home|
      assert Dir.pwd != home.wallets.to_s
      assert_equal(home.dir, home.wallets.to_s)
    end
  end
end
