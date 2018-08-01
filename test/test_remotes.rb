# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
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
require 'concurrent'
require 'concurrent/atomics'
require_relative 'test__helper'
require_relative '../lib/zold/log'
require_relative '../lib/zold/remotes'
require_relative '../lib/zold/verbose_thread'

# Remotes test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemotes < Minitest::Test
  class TestLogger
    attr_reader :msg
    def info(msg)
      @msg = msg
    end

    def debug(msg); end
  end

  def test_adds_remotes
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1')
      assert(1, remotes.all.count)
    end
  end

  def test_reads_broken_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      [
        ',0,0,0',
        'some garbage',
        '',
        "\n\n\n\n"
      ].each do |t|
        File.write(file, t)
        remotes = Zold::Remotes.new(file: file)
        assert(remotes.all.empty?, remotes.all)
      end
    end
  end

  def test_iterates_and_fails
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      ips = (0..50)
      ips.each { |i| remotes.add("0.0.0.#{i}", 9999) }
      remotes.iterate(Zold::Log::Quiet.new) { raise 'Intended' }
      ips.each { |i| assert(1, remotes.all[i][:errors]) }
    end
  end

  def test_iterates_them_all
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'rrr.csv'))
      remotes.clean
      5.times { |i| remotes.add("0.0.0.#{i}", 8080) }
      total = 0
      remotes.iterate(test_log) { total += 1 }
      assert_equal(5, total)
    end
  end

  def test_log_msg_of_iterates_when_fail
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('0.0.0.1', 9999)
      log = TestLogger.new
      remotes.iterate(log) { raise 'Intended' }
      assert(log.msg.include?(' in '))
    end
  end

  def test_log_msg_of_iterates_when_take_too_long
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file, timeout: 1)
      remotes.add('127.0.0.1')
      log = TestLogger.new
      remotes.iterate(log) { sleep(2) }
      assert(log.msg.include?('Took too long to execute'))
    end
  end

  def test_removes_remotes
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1')
      remotes.add('LOCALHOST', 433)
      remotes.remove('localhost', 433)
      assert(1, remotes.all.count)
    end
  end

  def test_resets_remotes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes'))
      remotes.clean
      remotes.reset
      remotes.reset
      assert(!remotes.all.empty?)
    end
  end

  def test_modifies_score
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1', 1024)
      remotes.rescore('127.0.0.1', 1024, 15)
      remotes.all.each do |r|
        assert_equal(15, r[:score])
        assert_equal('http://127.0.0.1:1024/', r[:home].to_s)
      end
    end
  end

  def test_tolerates_invalid_requests
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      remotes = Zold::Remotes.new(file: file)
      remotes.error('127.0.0.1', 1024)
      remotes.rescore('127.0.0.1', 1024, 15)
    end
  end

  def test_modifies_from_many_threads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'a.csv'))
      remotes.clean
      threads = 5
      pool = Concurrent::FixedThreadPool.new(threads)
      alive = true
      cycles = Concurrent::AtomicFixnum.new
      success = Concurrent::AtomicFixnum.new
      host = '192.168.0.1'
      remotes.add(host)
      threads.times do
        pool.post do
          while alive
            Zold::VerboseThread.new(test_log).run(true) do
              cycles.increment
              remotes.error(host)
              success.increment
            end
          end
        end
      end
      sleep 0.1 while cycles.value < 50
      alive = false
      pool.shutdown
      pool.wait_for_termination
      assert_equal(cycles.value, success.value)
      assert_equal(0, remotes.all.reject { |r| r[:host] == host }.size)
    end
  end

  def test_adds_from_many_threads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'xx.csv'))
      remotes.clean
      threads = 5
      pool = Concurrent::FixedThreadPool.new(threads)
      done = Concurrent::AtomicFixnum.new
      latch = Concurrent::CountDownLatch.new(1)
      threads.times do |i|
        pool.post do
          Zold::VerboseThread.new(test_log).run(true) do
            latch.wait(10)
            remotes.add('127.0.0.1', 8080 + i)
            done.increment
          end
        end
      end
      latch.count_down
      sleep 0.1 until done.value == threads
      assert_equal(threads, remotes.all.count)
    end
  end

  def test_quickly_ads_and_reads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-90.csv'))
      remotes.clean
      threads = 20
      pool = Concurrent::FixedThreadPool.new(threads)
      done = Concurrent::AtomicFixnum.new
      start = Time.now
      alive = true
      100.times { |i| remotes.add('192.168.0.1', 8080 + i) }
      threads.times do |i|
        pool.post do
          loop do
            break unless alive
            Zold::VerboseThread.new(test_log).run(true) do
              remotes.add('127.0.0.1', 8080 + i)
              remotes.error('127.0.0.1', 8080 + i)
              remotes.all
              remotes.iterate(test_log) { done.increment }
              remotes.remove('127.0.0.1', 8080 + i)
            end
          end
        end
      end
      sleep 0.1 while done.value < 1000
      alive = false
      pool.shutdown
      pool.wait_for_termination(10)
      test_log.info("Total time: #{Time.now - start}")
    end
  end

  def test_empty_remotes
    remotes = Zold::Remotes::Empty.new(file: '/tmp/empty')
    assert(remotes.is_a?(Zold::Remotes))
  end

  def test_error_counter
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'remotes')
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1', 1024)
      remotes.error('127.0.0.1', 1024)
      assert(remotes.errors('127.0.0.1', 1024) == 1)
      log = TestLogger.new
      remotes.iterate(log) {}
      assert(remotes.errors('127.0.0.1', 1024).zero?)
    end
  end
end
