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
require_relative 'test__helper'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/amount'
require_relative '../lib/zold/patch'

# Patch test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPatch < Minitest::Test
  def test_builds_patch
    FakeHome.new.run do |home|
      first = home.create_wallet
      second = home.create_wallet
      third = home.create_wallet
      File.write(second.path, File.read(first.path))
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      first.sub(Zold::Amount.new(zld: 39.0), "NOPREFIX@#{Zold::Id.new}", key)
      first.sub(Zold::Amount.new(zld: 11.0), "NOPREFIX@#{Zold::Id.new}", key)
      first.sub(Zold::Amount.new(zld: 3.0), "NOPREFIX@#{Zold::Id.new}", key)
      second.sub(Zold::Amount.new(zld: 44.0), "NOPREFIX@#{Zold::Id.new}", key)
      File.write(third.path, File.read(first.path))
      t = third.sub(Zold::Amount.new(zld: 10.0), "NOPREFIX@#{Zold::Id.new}", key)
      third.add(t.inverse(first.id))
      patch = Zold::Patch.new(log: test_log)
      patch.join(first)
      patch.join(second)
      patch.join(third)
      FileUtils.rm(first.path)
      assert_equal(true, patch.save(first.path))
      assert_equal(Zold::Amount.new(zld: -43.0), first.balance)
    end
  end
end
