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

require 'rainbow'
require 'uri'
require 'backtrace'
require 'zold/score'
require 'typhoeus'
require_relative 'version'

# HTTP page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Some clients waits for status method in response
  class HttpResponse < SimpleDelegator
    def status
      code.zero? ? 599 : code
    end

    def status_line
      status_message || ''
    end

    def to_s
      "#{status}: #{status_line}\n#{body}"
    end
  end

  # The error, if connection fails
  class HttpError < HttpResponse
    def initialize(ex)
      @ex = ex
    end

    def body
      Backtrace.new(@ex).to_s
    end

    def status
      599
    end

    def status_line
      @ex.message || ''
    end

    def headers
      {}
    end
  end

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
      HttpResponse.new(
        Typhoeus::Request.get(
          @uri,
          accept_encoding: 'gzip',
          headers: headers,
          connecttimeout: CONNECT_TIMEOUT,
          timeout: timeout
        )
      )
    rescue StandardError => e
      HttpError.new(e)
    end

    def get_file(file)
      File.open(file, 'w') do |f|
        request = Typhoeus::Request.new(
          @uri,
          accept_encoding: 'gzip',
          headers: headers,
          connecttimeout: CONNECT_TIMEOUT
        )
        request.on_body do |chunk|
          f.write(chunk)
        end
        request.run
        response = new HttpResponse(request)
        raise "Invalid response code #{response.status}" unless response.status == 200
        response
      end
    rescue StandardError => e
      HttpError.new(e)
    end

    def put(file)
      request = Typhoeus::Request.new(
        @uri,
        method: :put,
        accept_encoding: 'gzip',
        headers: headers.merge(
          'Content-Type': 'text/plain'
        ),
        connecttimeout: CONNECT_TIMEOUT,
        timeout: 2 + File.size(file) * 0.01 / 1024
      )
      easy = Typhoeus::EasyFactory.new(request).get
      easy.infilesize = file.size
      easy.set_read_callback(file)
      easy.perform
      HttpResponse.new(request.response)
    rescue StandardError => e
      HttpError.new(e)
    end

    private

    def headers
      headers = {
        'User-Agent': "Zold #{VERSION}",
        'Connection': 'close',
        'Accept-Encoding': 'gzip'
      }
      headers[Http::VERSION_HEADER] = Zold::VERSION
      headers[Http::PROTOCOL_HEADER] = Zold::PROTOCOL.to_s
      headers[Http::NETWORK_HEADER] = @network
      headers[Http::SCORE_HEADER] = @score.reduced(4).to_s if @score.valid? && !@score.expired? && @score.value > 3
      headers
    end
  end
end
