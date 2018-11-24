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

require 'rainbow'
require 'uri'
require 'backtrace'
require 'patron'
require 'zold/score'
require_relative 'version'

# HTTP page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Http page
  class Http
    # HTTP header we add to each HTTP request, in order to inform
    # the other node about the score. If the score is big enough,
    # the remote node will add us to its list of remote nodes.
    SCORE_HEADER = 'X-Zold-Score'

    # HTTP header we add, in order to inform the node about our
    # version. This is done mostly in order to let the other node
    # reboot itself, if the version is higher.
    VERSION_HEADER = 'X-Zold-Version'

    # HTTP header we add, in order to inform the node about our
    # network. This is done in order to isolate test networks from
    # production one.
    NETWORK_HEADER = 'X-Zold-Network'

    # HTTP header we add, in order to inform the node about our
    # protocol.
    PROTOCOL_HEADER = 'X-Zold-Protocol'

    # Read timeout in seconds
    READ_TIMEOUT = 2
    private_constant :READ_TIMEOUT

    # Connect timeout in seconds
    CONNECT_TIMEOUT = 0.8
    private_constant :CONNECT_TIMEOUT

    def initialize(uri:, score: Score::ZERO, network: 'test')
      @uri = uri.is_a?(URI) ? uri : URI(uri)
      @score = score
      @network = network
    end

    def get(timeout: READ_TIMEOUT)
      build_session(timeout: timeout)
        .get(path)
    rescue StandardError => e
      Error.new(e)
    end

    def put(body, timeout: READ_TIMEOUT)
      build_session(
        timeout: timeout,
        additional_header: {
          'Content-Type': 'text/plain',
          'Content-Length': body.length.to_s
        }
      )
        .put(path, body)
    rescue StandardError => e
      Error.new(e)
    end

    private

    # The error, if connection fails
    class Error
      def initialize(ex)
        @ex = ex
      end

      def to_s
        "#{status}: #{status_line}\n#{body}"
      end

      def body
        Backtrace.new(@ex).to_s
      end

      def status
        599
      end

      def status_line
        @ex.message
      end

      def headers
        {}
      end
    end

    def build_session(timeout:, additional_header: {})
      Patron::Session.new(
        timeout: timeout,
        connect_timeout: CONNECT_TIMEOUT,
        base_url: base_url,
        headers: headers.merge(additional_header)
      )
    end

    def base_url
      "#{@uri.scheme}://#{@uri.host}:#{@uri.port}"
    end

    def path
      path = @uri.path
      path += '?' + @uri.query if @uri.query

      path
    end

    def headers
      headers = {
        'User-Agent': "Zold #{VERSION}",
        'Connection': 'close',
        'Accept-Encoding': 'gzip'
      }
      headers[Http::VERSION_HEADER] = Zold::VERSION
      headers[Http::PROTOCOL_HEADER] = Zold::PROTOCOL.to_s
      headers[Http::NETWORK_HEADER] = @network
      headers[Http::SCORE_HEADER] = @score.reduced(4).to_text if @score.valid? && !@score.expired? && @score.value > 3
      headers
    end
  end
end
