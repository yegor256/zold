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
require 'zold/score'
require 'time'
require_relative 'test__helper'
require_relative 'fake_home'
require 'zold/id'
require 'zold/txn'
require 'zold/wallet'
require 'zold/tax'
require 'zold/key'
require 'zold/amount'
require 'zold/prefixes'

# Tax test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestTax < Zold::Test
  def test_print_fee
    test_log.info("Fee in zents: #{Zold::Tax::FEE.to_i}")
  end

  def test_calculates_tax_for_one_year
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      a = 10_000
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - a * 60 * 60,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      tax = Zold::Tax.new(wallet)
      assert_equal(Zold::Tax::FEE * a, tax.debt, tax.to_text)
    end
  end

  def test_calculates_debt
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      (1..30).each do |i|
        wallet.add(
          Zold::Txn.new(
            i + 1,
            Time.now - 24 * 60 * 60 * 365 * 10,
            Zold::Amount.new(zld: i.to_f),
            'NOPREFIX', Zold::Id.new, '-'
          )
        )
      end
      score = Zold::Score.new(
        host: 'localhost', port: 80, invoice: 'NOPREFIX@cccccccccccccccc',
        suffixes: %w[A B C D E F G H I J K L M N O P Q R S T U V]
      )
      tax = Zold::Tax.new(wallet)
      debt = tax.debt
      txn = tax.pay(Zold::Key.new(file: 'fixtures/id_rsa'), score)
      assert_equal(debt, txn.amount * -1)
    end
  end

  def test_prints_tax_formula
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      tax = Zold::Tax.new(wallet)
      assert(!tax.to_text.nil?)
    end
  end

  def test_takes_tax_payment_into_account
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zents: 95_596_800)
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now,
          amount * -1,
          'NOPREFIX', Zold::Id.new('912ecc24b32dbe74'),
          "TAXES 6 5b5a21a9 b2.zold.io 1000 DCexx0hG 912ecc24b32dbe74 \
386d4a ec9eae 306e3d 119d073 1c00dba 1376703 203589 5b55f7"
        )
      )
      tax = Zold::Tax.new(wallet, strength: 6)
      assert_equal(amount, tax.paid)
      assert(tax.debt < Zold::Amount::ZERO, tax.debt)
    end
  end

  def test_filters_out_incoming_payments
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zents: 95_596_800)
      prefix = Zold::Prefixes.new(wallet).create(8)
      score = Zold::Score.new(
        time: Time.now, host: 'localhost', port: 4096,
        invoice: "#{prefix}@#{wallet.id}", strength: 1
      )
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now,
          amount,
          'NOPREFIX', Zold::Id.new('0000111122223333'),
          "TAXES #{score}"
        )
      )
      wallet.add(
        Zold::Txn.new(
          2,
          Time.now,
          amount * -1,
          'NOPREFIX', Zold::Id.new('912ecc24b32dbe74'),
          "TAXES 6 5b5a21a9 b2.zold.io 1000 DCexx0hG 912ecc24b32dbe74 \
386d4a ec9eae 306e3d 119d073 1c00dba 1376703 203589 5b55f7"
        )
      )
      tax = Zold::Tax.new(wallet, strength: 6, ignore_score_weakness: true)
      assert_equal(amount, tax.paid)
      # assert(tax.debt < Zold::Amount::ZERO, tax.debt)
    end
  end

  def test_checks_existence_of_duplicates
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      target = home.create_wallet
      invoice = "#{Zold::Prefixes.new(target).create}@#{target.id}"
      tax = Zold::Tax.new(wallet)
      score = Zold::Score.new(
        host: 'localhost', port: 80, invoice: invoice,
        suffixes: %w[A B C D E F G H I J K L M N O P Q R S T U V]
      )
      tax.pay(Zold::Key.new(file: 'fixtures/id_rsa'), score)
      assert(tax.exists?(tax.details(score)))
      assert(!tax.exists?('-'))
    end
  end
end
