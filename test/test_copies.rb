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
require 'time'
require_relative 'fake_home'
require_relative 'test__helper'
require 'zold/id'
require 'zold/age'
require 'zold/copies'
require 'zold/dir_items'
require 'zold/wallet'

# Copies test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestCopies < Zold::Test
  def test_adds_and_removes_copies
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(File.join(dir, 'my/a/copies'), log: test_log)
      copies.add(content('alpha'), '192.168.0.1', 80, 1)
      copies.add(content('beta'), '192.168.0.2', 80, 3)
      copies.add(content('beta'), '192.168.0.3', 80, 7)
      copies.add(content('alpha'), '192.168.0.4', 80, 10)
      copies.add(content('hello-to-delete'), '192.168.0.5', 80, 10)
      copies.remove('192.168.0.5', 80)
      copies.clean
      assert_equal(2, copies.all.count, copies.all.map { |c| c[:name] }.join('; '))
      assert_equal(11, copies.all.find { |c| c[:name] == '1' }[:score])
    end
  end

  def test_lists_empty_dir
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(File.join(dir, 'xxx'), log: test_log)
      assert(copies.all.empty?, "#{copies.all.count} is not zero")
    end
  end

  def test_overwrites_host
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(File.join(dir, 'my/a/copies-2'), log: test_log)
      host = 'b1.zold.io'
      copies.add(content('z1'), host, 80, 5)
      copies.add(content('z1'), host, 80, 6)
      copies.add(content('z1'), host, 80, 7)
      assert(copies.all.count == 1, "#{copies.all.count} is not equal to 1")
      assert(copies.all[0][:score] == 7, "#{copies.all[0][:score]} is not 7")
    end
  end

  def test_master_first
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(File.join(dir, 'my/a/copies-2'), log: test_log)
      copies.add(content('z1'), 'edge-1', 80, 100, master: false)
      copies.add(content('z2'), 'master', 80, 1, master: true)
      copies.add(content('z1'), 'edge-2', 80, 50, master: false)
      copies.add(content('z1'), 'edge-3', 80, 400, master: false)
      assert(copies.all[0][:master])
    end
  end

  def test_cleans_copies
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(dir, log: test_log)
      copies.add(content('h1'), 'zold.io', 4096, 10, time: Time.now - 25 * 60 * 60)
      copies.add(content('h1'), 'zold.io', 4097, 20, time: Time.now - 26 * 60 * 60)
      assert(File.exist?(File.join(dir, "1#{Zold::Copies::EXT}")))
      copies.clean
      assert(copies.all.empty?, "#{copies.all.count} is not empty")
      assert(!File.exist?(File.join(dir, "1#{Zold::Copies::EXT}")))
    end
  end

  def test_cleans_broken_copies
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(dir, log: test_log)
      copies.add('broken wallet content', 'zold.io', 4096, 10, time: Time.now)
      copies.clean
      assert(copies.all.empty?, "#{copies.all.count} is not empty")
    end
  end

  def test_ignores_garbage
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(dir, log: test_log)
      copies.add(content('h1'), 'zold.io', 50, 80, time: Time.now - 25 * 60 * 60)
      FileUtils.mkdir(File.join(dir, '55'))
      assert_equal(1, copies.all.count)
    end
  end

  def test_sorts_them_by_score
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(dir, log: test_log)
      copies.add(content('content-1'), '1.zold.io', 80, 1)
      copies.add(content('content-2'), '2.zold.io', 80, 2)
      copies.add(content('content-3'), '3.zold.io', 80, 50)
      copies.add(content('content-4'), '4.zold.io', 80, 3)
      assert_equal('50 3 2 1', copies.all.map { |c| c[:score] }.join(' '))
    end
  end

  def test_ignores_too_old_scores
    Dir.mktmpdir do |dir|
      copies = Zold::Copies.new(dir, log: test_log)
      copies.add(content('h1'), 'zold.io', 50, 80, time: Time.now - 1000 * 60 * 60)
      assert_equal(0, copies.all[0][:score])
    end
  end

  private

  def content(text)
    id = Zold::Id.new('aaaabbbbccccdddd')
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet(id)
      amount = Zold::Amount.new(zld: 1.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, 'NOPREFIX@0000111122223333', key, text, time: Time.parse('2018-01-01T01:01:01Z'))
      IO.read(wallet.path)
    end
  end
end
