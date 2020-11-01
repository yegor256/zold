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
require 'zold/age'

# Age test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestAge < Zold::Test
  def test_prints_age
    assert_equal('10m', Zold::Age.new(Time.now - 10 * 60).to_s)
    assert_equal('5.5s', Zold::Age.new(Time.now - 5.5).to_s)
    assert_equal('?', Zold::Age.new(nil).to_s)
    assert(!Zold::Age.new(Time.now.utc.iso8601).to_s.nil?)
  end

  def test_prints_all_ages
    [
      0,
      1,
      63,
      63 * 60,
      27 * 60 * 60,
      13 * 24 * 60 * 60,
      30 * 24 * 60 * 60,
      5 * 30 * 24 * 60 * 60,
      15 * 30 * 24 * 60 * 60,
      8 * 12 * 30 * 24 * 60 * 60
    ].each do |s|
      assert(!Zold::Age.new(Time.now - s).to_s.nil?)
    end
  end
end
