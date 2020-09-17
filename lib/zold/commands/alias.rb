# frozen_string_literal: true

require 'slop'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../log'

module Zold
  # Command to set an alias for wallet ID
  class Alias
    prepend ThreadBadge

    def initialize(wallets:, log: Log::NULL)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold alias [args]
    #{Rainbow('alias set <wallet> <alias>').green}
      Make wallet known under an alias.
    #{Rainbow('alias remove <alias>').green}
      Remove an alias.
    #{Rainbow('alias show <alias>').green}
      Show where the alias is pointing to.
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      command = mine[0]
      raise "A command is required, try 'zold alias --help'" unless command
      case command
      when 'set'    then set(mine[1], mine[2])
      when 'remove' then remove(mine[1])
      when 'show'   then show(mine[1])
      end
    end

    # @todo #323:30min Implement the set command.
    #  The set command expects 'wallet' which is the wallet id
    #  and 'alias' (here called 'name' as alias is a Ruby keyword).
    #  It writes this info into the alias file as described in #279.
    def set(_wallet, _name)
      raise NotImplementedError, 'This is not yet implemented'
    end

    # @todo #323:30min Implement the remove command.
    #  The remove command expect an 'alias' (here called 'name' as alias
    #  is a Ruby keyword).
    #  It removes given alias from the alias file as described in #279.
    def remove(_name)
      raise NotImplementedError, 'This is not yet implemented'
    end

    # @todo #323:30min Implement the show command.
    #  The show command expect an 'alias' (here called 'name' as alias
    #  is a Ruby keyword).
    #  It prints out wallet id corresponding with given alias from the alias file as described in #279.
    def show(_name)
      raise NotImplementedError, 'This is not yet implemented'
    end
  end
end
