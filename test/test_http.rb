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
require 'uri'
require 'webmock/minitest'
require 'zold/score'
require 'random-port'
require_relative 'test__helper'
require 'zold/http'
require 'zold/verbose_thread'

# Http test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestHttp < Zold::Test
  def test_pings_broken_uri
    stub_request(:get, 'http://bad-host/').to_return(status: 500)
    res = Zold::Http.new(uri: 'http://bad-host/').get
    assert_equal(500, res.status)
    assert_equal('', res.body)
  end

  def test_pings_with_exception
    stub_request(:get, 'http://exception/').to_return { raise 'Intentionally' }
    res = Zold::Http.new(uri: 'http://exception/').get
    assert_equal(599, res.status)
    assert(res.body.include?('Intentionally'))
    assert(!res.headers['nothing'])
  end

  def test_pings_live_uri
    stub_request(:get, 'http://good-host/').to_return(status: 200)
    res = Zold::Http.new(uri: 'http://good-host/').get
    assert_equal(200, res.status)
  end

  def test_sends_valid_network_header
    stub_request(:get, 'http://some-host-1/')
      .with(headers: { 'X-Zold-Network' => 'xyz' })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-1/', network: 'xyz').get
    assert_equal(200, res.status)
  end

  def test_sends_valid_protocol_header
    stub_request(:get, 'http://some-host-2/')
      .with(headers: { 'X-Zold-Protocol' => Zold::PROTOCOL })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-2/').get
    assert_equal(200, res.status)
  end

  def test_terminates_on_timeout
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          server.accept
          sleep 400
        end
      end
      sleep 0.25
      res = Zold::Http.new(uri: "http://127.0.0.1:#{port}/").get(timeout: 0.1)
      assert_equal(599, res.status, res)
      assert_equal('', res.status_line, res)
      thread.kill
      thread.join
    end
  end

  def test_doesnt_terminate_on_long_call
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          client = server.accept
          client.puts("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\n")
          sleep 1
          client.puts('Good')
          client.close
        end
      end
      sleep 0.25
      res = Zold::Http.new(uri: "http://127.0.0.1:#{port}/").get(timeout: 2)
      assert_equal(200, res.status, res)
      thread.kill
      thread.join
    end
  end

  def test_sends_correct_http_headers
    WebMock.allow_net_connect!
    body = ''
    RandomPort::Pool::SINGLETON.acquire do |port|
      latch = Concurrent::CountDownLatch.new(1)
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new('127.0.0.1', port)
          latch.count_down
          socket = server.accept
          loop do
            line = socket.gets
            break if line.eql?("\r\n")
            test_log.info(line.inspect)
            body += line
          end
          socket.print("HTTP/1.1 200 OK\r\n")
          socket.print("Content-Length: 4\r\n")
          socket.print("\r\n")
          socket.print('Done')
          socket.close
        end
      end
      latch.wait
      res = Tempfile.open do |f|
        IO.write(f, 'How are you?')
        Zold::Http.new(uri: "http://127.0.0.1:#{port}/").put(f)
      end
      assert_equal(200, res.status, res)
      assert(body.include?('Content-Length: 12'), body)
      assert(body.include?('Content-Type: text/plain'))
      headers = body.split("\n").select { |t| t =~ /^[a-zA-Z-]+:.+$/ }
      assert_equal(headers.count, headers.uniq.count)
      thread.kill
      thread.join
    end
  end

  def test_sends_valid_version_header
    stub_request(:get, 'http://some-host-3/')
      .with(headers: { 'X-Zold-Version' => Zold::VERSION })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-3/').get
    assert_equal(200, res.status, res)
  end

  def test_uploads_file
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      latch = Concurrent::CountDownLatch.new(1)
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          latch.count_down
          socket = server.accept
          body = ''
          stops = 0
          loop do
            part = socket.read_nonblock(5, exception: false)
            if part == :wait_readable
              break if stops > 5
              stops += 1
              sleep 0.001
            else
              body += part
              stops = 0
            end
          end
          socket.close_read
          socket.print("HTTP/1.1 200 OK\nContent-Length: #{body.length}\n\n#{body}")
          socket.close_write
        end
      end
      latch.wait
      content = "how are you\nmy friend"
      res = Tempfile.open do |f|
        IO.write(f, content)
        Zold::Http.new(uri: "http://localhost:#{port}/").put(f)
      end
      assert_equal(200, res.status, res)
      assert(res.body.include?(content), res)
      thread.kill
      thread.join
    end
  end

  def test_downloads_file
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      content = "how are you\nmy friend" * 1000
      latch = Concurrent::CountDownLatch.new(1)
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          latch.count_down
          socket = server.accept
          socket.print("HTTP/1.1 200 OK\nContent-Length: #{content.length}\n\n#{content}")
          socket.close_write
        end
      end
      latch.wait
      body = Tempfile.open do |f|
        Zold::Http.new(uri: "http://localhost:#{port}/").get_file(f)
        IO.read(f)
      end
      assert(body.include?(content), body)
      thread.kill
      thread.join
    end
  end
end
