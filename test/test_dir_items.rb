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
require 'threads'
require_relative 'test__helper'
require 'zold/age'
require 'zold/endless'
require 'zold/dir_items'

# DirItems test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestDirItems < Zold::Test
  def test_intensive_write_in_threads
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'hey.txt')
      back = Thread.start do
        Zold::Endless.new('test-diritems', log: test_log).run do
          Zold::DirItems.new(dir).fetch
        end
      end
      Threads.new(100).assert do
        start = Time.now
        File.open(file, 'w+') do |f|
          f.write('test')
        end
        test_log.info("Saved in #{Zold::Age.new(start)}")
        sleep 1
      end
      back.kill
    end
  end

  def test_lists_empty_dir
    Dir.mktmpdir do |dir|
      d = File.join(dir, 'path с пробелами')
      FileUtils.mkdir_p(d)
      assert_equal(0, Zold::DirItems.new(d).fetch.count)
    end
  end

  def test_lists_recursively
    Dir.mktmpdir do |dir|
      files = ['test1.txt', 'a/b/c/text', 'd/e/f/text', 'a/b/c/zz/text.1.2.3']
      files.each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      found = Zold::DirItems.new(dir).fetch
      assert_equal(files.count, found.count)
      files.each do |f|
        assert(found.include?(f), f)
      end
    end
  end

  def test_lists_non_recursively
    Dir.mktmpdir do |dir|
      files = ['1.txt', 'a/1.txt', 'a/b/1.txt', 'a/b/c/1.txt']
      files.each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      found = Zold::DirItems.new(dir).fetch(recursive: false)
      assert_equal(1, found.count)
    end
  end
end
