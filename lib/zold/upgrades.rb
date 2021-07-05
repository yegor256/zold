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

require_relative 'log'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  #
  # This class will write the version file to the zoldata directory.
  # The version file is a text file containing nothing but the version
  # of the data and a newline. It is named `version`, no extension.
  #
  # If the data is up-to-date, the version of the data is equal to
  # Zold::VERSION.
  #
  # By comparing Zold::VERSION with the data version we determine
  # which upgrade scripts will be executed.
  #
  # If the data version is the same as Zold::VERSION, the data is
  # up to date.
  #
  # If the data version is lower than Zold::VERSION, we will look into
  # the `upgrades/` directory and any scripts from the data version
  # up will be executed.
  #
  # The version of an upgrade script is extracted from the name
  # which is formatted as`<version>.rb`, so for instance `upgrades/0.0.1.rb` etc.
  #
  # If there is no version file, as it would if the data were created
  # by a version of Zold that doesn't have this class implemented yet,
  # all the upgrade scripts have to run.
  #
  # The upgrade scripts are loaded into the running Ruby interpreter
  # rather than being executed.
  class Upgrades
    def initialize(version, directory, opts, log: Log::VERBOSE)
      raise 'network can\'t be nil' if opts[:network].nil?
      @version = version
      @directory = directory
      @log = log
      @opts = opts
    end

    def run
      Dir.glob("#{@directory}/*.rb").select { |f| f =~ /^(\d+)\.rb$/ }.sort.each do |script|
        @version.apply(script)
      end
      command = @opts[:command]
      require_relative '../../upgrades/delete_banned_wallets'
      DeleteBannedWallets.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/2'
      UpgradeTo2.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/protocol_up'
      ProtocolUp.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/rename_foreign_wallets'
      RenameForeignWallets.new(Dir.pwd, @opts[:network], @log).exec
      return unless command == 'node'
      require_relative '../../upgrades/move_wallets_into_tree'
      MoveWalletsIntoTree.new(Dir.pwd, @log).exec
    end
  end
end
