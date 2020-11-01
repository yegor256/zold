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
require 'open3'
require 'English'
require_relative 'test__helper'
require 'zold/version'
require 'zold/age'

# Zold main module test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestZold < Zold::Test
  Dir.new('fixtures/scripts').select { |f| f =~ /\.sh$/ && !f.start_with?('_') }.each do |f|
    method = "test_#{f.gsub(/\.sh$/, '').gsub(/[^a-z]/, '_')}"
    define_method(method) do
      start = Time.now
      test_log.info("\n\n#{method} running (script at #{f})...")
      Dir.mktmpdir do |dir|
        FileUtils.cp('fixtures/id_rsa.pub', dir)
        FileUtils.cp('fixtures/id_rsa', dir)
        script = File.join(dir, f)
        IO.write(script, IO.read('fixtures/scripts/_head.sh') + IO.read(File.join('fixtures/scripts', f)))
        bin = File.join(Dir.pwd, 'bin/zold')
        out = []
        Dir.chdir(dir) do
          Open3.popen2e("/bin/bash #{f} #{bin} 2>&1") do |stdin, stdout, thr|
            stdin.close
            until stdout.eof?
              line = stdout.gets
              test_log.info(line)
              out << line
            end
            code = thr.value.to_i
            assert_equal(0, code, "#{f}\n#{out.join}")
          end
        end
        sleep 1 # It's a workaround, I can't fix the bug (tests crash sporadically)
      end
      test_log.info("\n\n#{f} done in #{Zold::Age.new(start)}")
    end
  end

  def test_help
    stdout = exec('--help')
    assert(stdout.include?('Usage: zold'))
  end

  def test_show_version
    stdout = exec('--version')
    assert(stdout.include?(Zold::VERSION))
  end

  def test_create_new_wallet
    Dir.mktmpdir do |dir|
      FileUtils.cp('fixtures/id_rsa.pub', dir)
      FileUtils.cp('fixtures/id_rsa', dir)
      stdout = exec(
        '--verbose --trace create --public-key=id_rsa.pub',
        dir
      )
      assert(stdout.include?('created at'))
    end
  end

  private

  def exec(tail, dir = Dir.pwd)
    bin = File.expand_path(File.join(Dir.pwd, 'bin/zold'))
    stdout = `cd #{dir} && #{bin} #{tail} 2>&1`
    unless $CHILD_STATUS.exitstatus.zero?
      puts stdout
      assert_equal($CHILD_STATUS.exitstatus, 0)
    end
    stdout
  end
end
