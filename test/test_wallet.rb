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
require 'zold/age'
require 'zold/id'
require 'zold/wallet'
require 'zold/txn'
require 'zold/thread_pool'
require 'zold/amount'
require 'zold/commands/pay'

# Wallet test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestWallet < Zold::Test
  def test_reads_empty_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert(wallet.txns.empty?)
      assert_equal(Zold::Amount::ZERO, wallet.balance)
    end
  end

  def test_generates_memo
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert(!wallet.mnemo.nil?)
    end
  end

  def test_reads_large_wallet
    key = Zold::Key.new(file: 'fixtures/id_rsa')
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet(Zold::Id.new('448b451bc62e8e16'))
      FileUtils.cp('fixtures/448b451bc62e8e16.z', wallet.path)
      start = Time.now
      wallet.txns
      wallet.sub(Zold::Amount.new(zld: 39.99), "NOPREFIX@#{Zold::Id.new}", key)
      time = Time.now - start
      assert(time < 0.5, "Too slow: #{Zold::Age.new(start)} seconds")
    end
  end

  def test_adds_transaction
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      assert(
        wallet.balance == amount * -3,
        "#{wallet.balance} is not equal to #{amount * -3}"
      )
    end
  end

  def test_adds_similar_transaction
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      id = Zold::Id.new
      wallet.sub(amount, "NOPREFIX@#{id}", key)
      wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      assert_raises do
        wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      end
      assert_raises do
        wallet.add(Zold::Txn.new(1, Time.now, amount * -1, 'NOPREFIX', id, '-'))
      end
      assert(wallet.balance.zero?)
    end
  end

  def test_checks_similar_transaction
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      id = Zold::Id.new
      wallet.sub(amount, "NOPREFIX@#{id}", key)
      wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      assert(wallet.includes_negative?(1))
      assert(wallet.includes_positive?(1, id))
    end
  end

  def test_refurbishes_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 5.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      before = IO.read(wallet.path)
      IO.write(wallet.path, IO.read(wallet.path) + "\n\n\n")
      wallet.refurbish
      assert_equal(amount * -2, wallet.balance)
      assert_equal(before, IO.read(wallet.path))
    end
  end

  def test_refurbishes_empty_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      before = IO.read(wallet.path)
      IO.write(wallet.path, IO.read(wallet.path) + "\n\n\n")
      wallet.refurbish
      assert_equal(before, IO.read(wallet.path))
    end
  end

  def test_positive_transactions_go_first
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      time = Time.now
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.add(Zold::Txn.new(1, time, Zold::Amount.new(zents: 1), 'NOPREFIX', Zold::Id.new, '-'))
      wallet.sub(Zold::Amount.new(zents: 2), "NOPREFIX@#{Zold::Id.new}", key, time: time)
      wallet.add(Zold::Txn.new(2, time, Zold::Amount.new(zents: 3), 'NOPREFIX', Zold::Id.new, '-'))
      wallet.sub(Zold::Amount.new(zents: 4), "NOPREFIX@#{Zold::Id.new}", key, time: time)
      assert_equal('3, 1, -2, -4', wallet.txns.map(&:amount).map(&:to_i).join(', '))
    end
  end

  def test_validate_key_on_payment
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa-2')
      assert_raises RuntimeError do
        wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      end
    end
  end

  def test_adds_transaction_and_reads_back
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      txn = wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.add(txn.inverse(Zold::Id.new))
      assert(!Zold::Wallet.new(wallet.path).txns[1].sign.end_with?("\n"))
    end
  end

  def test_calculates_wallet_age_in_hours
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      hours = 100
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 100 * 60 * 60,
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      assert_equal(hours, wallet.age.round)
    end
  end

  def test_flushes_and_reads_again
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now,
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      assert_equal(1, wallet.txns.count)
      assert_equal('test', wallet.network)
      wallet.flush
      assert_equal(1, wallet.txns.count)
      assert_equal('test', wallet.network)
    end
  end

  def test_returns_modified_time
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert(wallet.mtime > Time.now - 60 * 60)
    end
  end

  def test_returns_digest
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert_equal(64, wallet.digest.length)
    end
  end

  def test_raises_when_broken_format
    Dir.mktmpdir do |dir|
      file = File.join(dir, "0123456701234567#{Zold::Wallet::EXT}")
      IO.write(file, 'broken head')
      assert_raises(Zold::Head::CantParse) do
        Zold::Wallet.new(file).id
      end
      assert_raises(Zold::Txns::CantParse) do
        Zold::Wallet.new(file).txns
      end
    end
  end

  def test_returns_protocol
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert_equal(Zold::PROTOCOL, wallet.protocol)
    end
  end

  def test_iterates_income_transactions
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1, Time.now, Zold::Amount.new(zld: 39.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      wallet.add(
        Zold::Txn.new(
          2, Time.now, Zold::Amount.new(zld: 14.95),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      sum = Zold::Amount::ZERO
      wallet.txns.each do |t|
        sum += t.amount unless t.amount.negative?
      end
      assert(
        sum == Zold::Amount.new(zents: 235_965_503_242),
        "#{sum} (#{sum.to_i}) is not equal to #{Zold::Amount.new(zld: 54.94)}"
      )
    end
  end

  def test_sorts_them_always_right
    FakeHome.new(log: test_log).run do |home|
      time = Time.now
      txns = []
      50.times do
        txns << Zold::Txn.new(
          1,
          time,
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      end
      wallet = home.create_wallet
      empty = IO.read(wallet.path)
      text = ''
      10.times do
        IO.write(wallet.path, empty)
        txns.shuffle!
        txns.each { |t| wallet.add(t) }
        wallet.refurbish
        if text.empty?
          text = IO.read(wallet.path)
          next
        end
        assert_equal(text, IO.read(wallet.path))
      end
    end
  end

  def test_collects_memory_garbage
    skip
    require 'get_process_mem'
    start = GetProcessMem.new.bytes.to_i
    Zold::Hands.exec(20) do
      40.times do |i|
        wallet = Zold::Wallet.new('fixtures/448b451bc62e8e16.z')
        GC.start
        wallet.id
        wallet.txns.count
        test_log.debug("Memory: #{GetProcessMem.new.bytes.to_i}") if (i % 5).zero?
      end
    end
    GC.stress = true
    diff = GetProcessMem.new.bytes.to_i - start
    GC.stress = false
    test_log.debug("Memory diff is #{diff}")
    assert(diff < 20_000_000)
  end
end
