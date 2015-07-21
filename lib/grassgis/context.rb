module GrassGis

  class Context
    ROOT_MODULES = %w(d g i r v s m p)

    def initialize(config)
      # TODO: set up GRASS environment
      locals = config[:locals] || {}
      locals.each do |var_name, value|
        define_singleton_method(var_name){ value }
      end
    end

    # setup access to the root modules in the context
    ROOT_MODULES.each do |root_module|
      define_method root_module.to_sym do
        var_name = "@#{root_module}"
        m = instance_variable_get(var_name)
        m ||= Module.new(root_module, configuration: @configuration)
        instance_variable_set var_name, m
        m
      end
    end
  end

  # Evaluate a block in a GRASS session environment
  #
  #     GrassGis.session configuration do
  #          r.resamp.stats '-n', input: "map1@mapset1", output: "map2"
  #     end
  #
  # Note that block is evaluated in a spacial context, so
  # that the lexical scope's self and instance variables
  # are not directly available inside it.
  # Local variables in the scope can be used to access self-related
  # information. Also, local values can be injected in the block
  # with the +:locals+ option:
  #
  #     this = self # make self available a local variable
  #     locals = { context: self } # inject locals
  #     GrassGis.session configuration.merge(locals:) do
  #          r.resamp.stats '-n', input: this.input, output: context.output
  #     end
  #
  def self.session(config, &blk)
    context = Context.new(config)
    context.instance_eval(&blk)
  end

end
