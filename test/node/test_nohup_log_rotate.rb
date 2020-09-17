# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
require_relative '../test__helper'
require_relative '../../lib/zold/commands/node'

class TestNohupLogRotate < Zold::Test
  def test_print
    logger = Zold::Node::NohupLogRotate.new('/tmp/zold.log', 'daily')

    logger.print('message 1')
    assert(IO.read('/tmp/zold.log').match?('message 1'))

    today_date = Date.today
    tomorrow_date = today_date.next_day

    Time.stub :now, tomorrow_date.to_time do
      logger.print('message 2')
      assert(IO.read('/tmp/zold.log').match?('message 2'))
      assert(IO.read("/tmp/zold.log.#{today_date.strftime('%Y%m%d')}").match?('message 1'))
    end
  ensure
    FileUtils.rm(Dir.glob('/tmp/zold.log*'))
  end
end
