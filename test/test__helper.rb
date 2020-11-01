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

gem 'openssl'
require 'openssl'
require 'minitest/autorun'
require 'minitest/hooks/test'
require 'concurrent'
require 'timeout'

require 'minitest/fail_fast' if ENV['TEST_QUIET_LOG']

STDOUT.sync = true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start
if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

$LOAD_PATH.unshift('../lib')

require 'zold/hands'
Zold::Hands.start

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

module Zold
  class Test < Minitest::Test
    include Minitest::Hooks

    # We need this in order to make sure any test is faster than a minute. This
    # should help spotting tests that hang out sometimes. The number of seconds
    # to wait can be increased, but try to make it as little as possible,
    # in order to catch problems ealier.
    def around
      Timeout.timeout(180) do
        Thread.current.name = 'test'
        super
      end
    end

    def assert_wait(max: 30)
      assert_equal_wait(true, max: max) { yield }
    end

    def assert_equal_wait(expected, max: 30)
      start = Time.now
      loop do
        begin
          actual = yield
          if expected == actual
            assert_equal(expected, actual)
            break
          end
        rescue StandardError => e
          test_log.debug(e.message)
        end
        sleep 1
        sec = Time.now - start
        require_relative '../lib/zold/age'
        raise "'#{actual}' is not equal to '#{expected}' even after #{Zold::Age.new(start)} of waiting" if sec > max
      end
    end

    def test_log
      require_relative '../lib/zold/log'
      @test_log ||= ENV['TEST_QUIET_LOG'] ? Zold::Log::NULL : Zold::Log::VERBOSE
    end

    class TestLogger
      attr_accessor :msgs
      def initialize(log = Zold::Log::NULL)
        @log = log
        @msgs = []
      end

      def info(msg)
        @log.info(msg)
        @msgs << msg
      end

      def debug(msg)
        @log.debug(msg)
        @msgs << msg
      end

      def error(msg)
        @log.error(msg)
        @msgs << msg
      end
    end
  end
end
