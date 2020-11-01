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
require 'zold/id'

# ID test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestId < Zold::Test
  def test_generates_new_id
    50.times do
      id = Zold::Id.new
      assert id.to_s.length == 16
    end
  end

  def test_list_of_banned_ids_is_not_empty
    assert(!Zold::Id::BANNED.empty?)
  end

  def test_checks_for_root
    assert(Zold::Id::ROOT.root?)
  end

  def test_generates_id_only_once
    id = Zold::Id.new
    before = id.to_s
    5.times do
      assert id.to_s == before
    end
  end

  def test_parses_id
    hex = 'ff01889402fe0954'
    id = Zold::Id.new(hex)
    assert(id.to_s == hex, "#{id} is not equal to #{hex}")
  end

  def test_compares_two_ids_by_text
    id = Zold::Id.new.to_s
    assert_equal(Zold::Id.new(id), Zold::Id.new(id))
  end

  def test_compares_two_ids
    assert Zold::Id.new(Zold::Id::ROOT.to_s) == Zold::Id.new('0000000000000000')
  end
end
