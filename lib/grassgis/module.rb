module GrassGis

  # Generate and execute GRASS commands
  #
  #     r = GrassGis::Module.new('r')
  #     r.resamp.stats '-n', input: "map1@mapset1", output: "map2"
  #
  # To execute a command without arguments, +run+ must be invoked explicitly:
  #
  #     g = GrassGis::Module.new('g')
  #     g.region.run
  #
  class Module
    def initialize(id, options = {})
      @id = id.to_s
      @parent = options[:parent]
      @context = options[:context]
    end

    def name
      if @parent
        "#{@parent.name}.#{@id}"
      else
        @id
      end
    end

    # Executes the command (with given arguments)
    # returns a SysCmd object (with status, status_value, output, error_output methods)
    def run(*args)
      stdin = nil
      cmd = SysCmd.command name do
        args.each do |arg|
          case arg
          when Hash
            arg.each do |key, value|
              next if value.nil?
              case value
              when Array
                value = value*","
              when String
                if value.include?("\n")
                  raise "Cannot pass multiple options through STDIN" if stdin
                  stdin = Support.unindent(value)
                  value = "-"
                  input stdin
                end
              end
              option key.to_s, equal_value: value
            end
          else
            option arg
          end
        end
      end
      if @context
        @context.execute cmd
      end
      cmd
    end

    def method_missing(method, *args)
      m = Module.new(method, parent: self, context: @context)
      if args.size > 0
        m.run *args
      else
        m
      end
    end

  end

end
