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
require_relative 'fake_home'
require_relative 'test__helper'
require 'zold/key'
require 'zold/id'
require 'zold/wallet'
require 'zold/prefixes'
require 'zold/amount'
require 'zold/patch'

# Patch test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPatch < Zold::Test
  def test_builds_patch
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet
      second = home.create_wallet
      third = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      first.sub(Zold::Amount.new(zld: 39.0), "NOPREFIX@#{Zold::Id.new}", key)
      first.sub(Zold::Amount.new(zld: 11.0), "NOPREFIX@#{Zold::Id.new}", key)
      first.sub(Zold::Amount.new(zld: 3.0), "NOPREFIX@#{Zold::Id.new}", key)
      second.sub(Zold::Amount.new(zld: 44.0), "NOPREFIX@#{Zold::Id.new}", key)
      IO.write(third.path, IO.read(first.path))
      t = third.sub(Zold::Amount.new(zld: 10.0), "NOPREFIX@#{Zold::Id.new}", key)
      third.add(t.inverse(Zold::Id.new))
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.join(first) { false }
      patch.join(second) { false }
      patch.join(third) { false }
      assert_equal(true, patch.save(first.path, overwrite: true, allow_negative_balance: true))
      assert_equal(Zold::Amount.new(zld: -53.0), first.balance)
    end
  end

  def test_rejects_fake_positives
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet
      second = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      second.add(Zold::Txn.new(1, Time.now, Zold::Amount.new(zld: 11.0), 'NOPREFIX', Zold::Id.new, 'fake'))
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.join(first) { false }
      patch.join(second) { false }
      assert_equal(false, patch.save(first.path, overwrite: true))
      first.flush
      assert_equal(Zold::Amount::ZERO, first.balance)
    end
  end

  def test_accepts_negative_balance_in_root_wallet
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet(Zold::Id::ROOT)
      second = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      amount = Zold::Amount.new(zld: 333.0)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      second.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.join(first) { false }
      patch.join(second) { false }
      assert_equal(true, patch.save(first.path, overwrite: true))
      first.flush
      assert_equal(amount * -1, first.balance)
    end
  end

  def test_merges_similar_ids_but_different_signs
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet(Zold::Id::ROOT)
      second = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      second.sub(Zold::Amount.new(zld: 7.0), "NOPREFIX@#{Zold::Id.new}", key)
      first.add(
        Zold::Txn.new(
          1, Time.now, Zold::Amount.new(zld: 9.0),
          Zold::Prefixes.new(first).create, Zold::Id.new, 'fake'
        )
      )
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.join(first) { false }
      patch.join(second) { false }
      assert_equal(true, patch.save(first.path, overwrite: true))
      first.flush
      assert_equal(Zold::Amount.new(zld: 2.0).to_s, first.balance.to_s)
    end
  end

  def test_merges_fragmented_parts
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet(Zold::Id::ROOT)
      second = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      start = Time.parse('2017-07-19T21:24:51Z')
      first.add(
        Zold::Txn.new(
          1, start, Zold::Amount.new(zld: -2.0),
          'NOPREFIX', Zold::Id.new, 'first payment'
        ).signed(key, first.id)
      )
      second.add(
        Zold::Txn.new(
          2, start + 1, Zold::Amount.new(zld: -2.0),
          'NOPREFIX', Zold::Id.new, 'second payment'
        ).signed(key, first.id)
      )
      first.add(
        Zold::Txn.new(
          3, start + 2, Zold::Amount.new(zld: -2.0),
          'NOPREFIX', Zold::Id.new, 'third payment'
        ).signed(key, first.id)
      )
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.join(first) { false }
      patch.join(second) { false }
      assert_equal(true, patch.save(first.path, overwrite: true))
      first.flush
      assert_equal(3, first.txns.count)
      assert_equal(Zold::Amount.new(zld: -6.0).to_s, first.balance.to_s)
    end
  end

  def test_protocols_new_txns
    FakeHome.new(log: test_log).run do |home|
      first = home.create_wallet(Zold::Id::ROOT)
      second = home.create_wallet
      IO.write(second.path, IO.read(first.path))
      amount = Zold::Amount.new(zld: 333.0)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      target = Zold::Id.new
      second.sub(amount, "NOPREFIX@#{target}", key, 'some details')
      second.sub(amount * 2, "NOPREFIX@#{target}", key)
      patch = Zold::Patch.new(home.wallets, log: test_log)
      patch.legacy(first)
      Tempfile.open do |f|
        patch.join(second, ledger: f.path) { false }
        lines = IO.read(f).split("\n")
        assert_equal(2, lines.count)
        parts = lines[0].split(';')
        assert(!Zold::Txn.parse_time(parts[0]).nil?)
        assert_equal(1, parts[1].to_i)
        assert(!Zold::Txn.parse_time(parts[2]).nil?)
        assert_equal(Zold::Id::ROOT.to_s, parts[3])
        assert_equal(target.to_s, parts[4])
        assert_equal(amount, Zold::Amount.new(zents: parts[5].to_i))
        assert_equal('NOPREFIX', parts[6])
        assert_equal('some details', parts[7])
      end
    end
  end
end
