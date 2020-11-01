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
require 'zold/metronome'

# Metronome test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestMetronome < Zold::Test
  def test_start_and_stop
    metronome = Zold::Metronome.new(test_log)
    list = []
    metronome.add(FakeRoutine.new(list))
    metronome.start do
      assert_wait { !list.empty? }
    end
  end

  def test_prints_to_text
    metronome = Zold::Metronome.new(test_log)
    metronome.add(FakeRoutine.new([]))
    metronome.start do |m|
      assert(!m.to_text.nil?)
    end
  end

  def test_prints_empty_to_text
    metronome = Zold::Metronome.new(test_log)
    metronome.start do |m|
      assert(!m.to_text.nil?)
    end
  end

  def test_continues_even_after_error
    metronome = Zold::Metronome.new(test_log)
    routine = BrokenRoutine.new
    metronome.add(routine)
    metronome.start do
      assert_wait { routine.count >= 2 }
      assert(routine.count > 1)
    end
  end

  class FakeRoutine
    def initialize(list)
      @list = list
    end

    def exec(i)
      @list << i
    end
  end

  class BrokenRoutine
    attr_reader :count
    def initialize
      @count = 0
    end

    def exec(i)
      @count = i
      sleep 0.1
      raise
    end
  end
end
