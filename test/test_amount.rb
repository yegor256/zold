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
require_relative 'test__helper'
require 'zold/amount'

# Amount test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestAmount < Zold::Test
  def test_parses_zld
    amount = Zold::Amount.new(zld: 14.95)
    assert(
      amount.to_s.include?('14.95ZLD'),
      "#{amount} is not equal to '14.95ZLD'"
    )
  end

  def test_prints_zld_with_many_digits
    amount = Zold::Amount.new(zld: 0.12345678)
    assert_equal('0.123', amount.to_zld(3))
    assert_equal('0.1235', amount.to_zld(4))
    assert_equal('0.12346', amount.to_zld(5))
    assert_equal('0.123457', amount.to_zld(6))
  end

  def test_compares_with_zero
    amount = Zold::Amount.new(zld: 0.00001)
    assert(!amount.zero?)
    assert(amount.positive?)
    assert(!amount.negative?)
    assert(amount != Zold::Amount::ZERO)
  end

  def test_parses_zents
    amount = Zold::Amount.new(zents: 900_000_000)
    assert(
      amount.to_s.include?('0.21ZLD'),
      "#{amount} is not equal to '0.21ZLD'"
    )
  end

  def test_compares_amounts
    amount = Zold::Amount.new(zents: 700_000_000)
    assert(
      amount > Zold::Amount::ZERO,
      "#{amount} is not greater than zero"
    )
  end

  def test_multiplies
    amount = Zold::Amount.new(zld: 1.2)
    assert(Zold::Amount.new(zld: 2.4), amount * 2)
  end

  def test_divides
    amount = Zold::Amount.new(zld: 8.2)
    assert(Zold::Amount.new(zld: 4.1), amount / 2)
  end
end
