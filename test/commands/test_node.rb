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
require 'tmpdir'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/node'
require_relative '../../lib/zold/commands/fetch'
require_relative '../../lib/zold/commands/push'
require_relative '../node/fake_node'

# NODE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestNode < Minitest::Test
  def test_push_and_fetch
    FakeNode.new(log: test_log).run do |port|
      Dir.mktmpdir 'test' do |dir|
        id = Zold::Id.new
        wallets = Zold::Wallets.new(dir)
        wallet = wallets.find(id)
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        remotes = Zold::Remotes.new(File.join(dir, 'remotes.csv'))
        remotes.clean
        remotes.add('localhost', port)
        Zold::Push.new(wallets: wallets, remotes: remotes, log: test_log).run(['push', '--sync'])
        Zold::Fetch.new(
          wallets: wallets, copies: File.join(dir, 'copies'),
          remotes: remotes, log: test_log
        ).run(['fetch'])
        copies = Zold::Copies.new(File.join(dir, "copies/#{id}"))
        assert_equal(1, copies.all.count)
        assert_equal('1', copies.all[0][:name])
        assert_equal(0, copies.all[0][:score])
      end
    end
  end
end
