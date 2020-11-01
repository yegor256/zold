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
require 'concurrent'
require_relative 'test__helper'
require 'zold/hands'

# Hands test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestHands < Zold::Test
  def test_runs_in_many_threads
    idx = Concurrent::AtomicFixnum.new
    threads = 50
    Zold::Hands.exec(threads) do
      idx.increment
    end
    assert_equal(threads, idx.value)
  end

  def test_runs_with_empty_set
    Zold::Hands.exec(5, []) do
      # nothing
    end
  end

  def test_runs_with_index
    idx = Concurrent::AtomicFixnum.new
    indexes = Set.new
    Zold::Hands.exec(10, %w[a b c]) do |_, i|
      idx.increment
      indexes << i
    end
    assert_equal(3, idx.value)
    assert_equal('0 1 2', indexes.to_a.sort.join(' '))
  end

  def test_runs_with_exceptions
    assert_raises do
      Zold::Hands.exec(5) do |i|
        if i == 4
          sleep 0.1
          raise 'intended'
        end
      end
    end
  end
end
