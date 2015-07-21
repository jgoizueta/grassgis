require 'tempfile'

module GrassGis

  class Context
    ROOT_MODULES = %w(d g i r v s m p)
    REQUIRED_CONFIG = [:gisbase, :location]

    def initialize(config)
      # apply configuration defaults
      config[:gisdbase] ||= File.join(ENV['HOME'], 'grassdata')
      config[:mapset]  ||= ENV['USER']
      config[:version] ||= File.read(File.join(config[:gisbase], 'etc', 'VERSIONNUMBER')).split.first
      config[:message_format] ||= 'plain'
      config[:true_color] = true unless config.has_key?(:true_color)
      config[:transparent] = true unless config.has_key?(:transparent)
      config[:png_auto_write] = true unless config.has_key?(:png_auto_write)
      config[:gnuplot] ||= 'gnuplot -persist'
      @config = config

      locals = config[:locals] || {}
      locals.each do |var_name, value|
        define_singleton_method(var_name){ value }
      end
    end

   def allocate
     @gisrc = Tempfile.new('gisrc')
     @gisrc.puts "LOCATION_NAME: #{@config[:location]}"
     @gisrc.puts "GISDBASE: #{@config[:gisdbase]}"
     @gisrc.puts "MAPSET: #{@config[:mapset]}"
     @gisrc.close
     ENV['GISRC'] = @gisrc.path
     ENV['GISBASE'] = @config[:gisbase]
     ENV['GRASS_VERSION'] = @config[:version]
     ENV['GRASS_MESSAGE_FORMAT'] = @config[:message_format].to_s
     ENV['GRASS_TRUECOLOR'] = bool_var(@config[:true_color])
     ENV['GRASS_TRANSPARENT'] = bool_var(@config[:transparent])
     ENV['GRASS_PNG_AUTO_WRITE'] = bool_var(@config[:png_auto_write])
     ENV['GRASS_GNUPLOT'] = @config[:gnuplot]
     @path = ENV['PATH']
     paths = []
     paths << File.join(@config[:gisbase], 'bin')
     paths << File.join(@config[:gisbase], 'scripts')
     paths << @path
     ENV['PATH'] = paths.join(File::PATH_SEPARATOR)
     @ld_path = ENV['LD_LIBRARY_PATH']
     ld_path = File.join(@config[:gisbase], 'lib')
     if @ld_path
       ENV['LD_LIBRARY_PATH'] = [ld_path, @ld_path].join(File::PATH_SEPARATOR)
     else
       ENV['LD_LIBRARY_PATH'] = ld_path
     end
     ENV['GRASS_LD_LIBRARY_PATH'] = ENV['LD_LIBRARY_PATH']
     @man_path = ENV['MANPATH']
     man_path = File.join(@config[:gisbase], 'man')
     if @man_path
       ENV['MANPATH'] = [man_path, @man_path].join(File::PATH_SEPARATOR)
     else
       ENV['MANPATH'] = man_path
     end
   end

    def dispose
      @gisrc.unlink if @gisrc
      @gisrc = nil
      ENV['PATH'] = @path if @path
      @path = nil
      ENV['LD_LIBRARY_PATH'] = @ld_path
      ENV['MANPATH'] = @man_path
    end

    # setup access to the root modules in the context
    ROOT_MODULES.each do |root_module|
      define_method root_module.to_sym do
        var_name = "@#{root_module}"
        m = instance_variable_get(var_name)
        m ||= Module.new(root_module, configuration: @config)
        instance_variable_set var_name, m
        m
      end
    end

    private

    def bool_var(value)
      value ? 'TRUE' : 'FALSE'
    end

  end

  # Evaluate a block in a GRASS session environment
  # The configuration must include at leaast:
  #
  # * :gibase The base GRASS instalation directory
  # * :location The location to work with
  #
  # Optional parameters:
  #
  # * :gisdbase The base GRASS data directory
  # * :mapset The default mapset
  # * :version The GRASS version
  #
  # Example:
  #
  #     configuration = {
  #       gisbase: '/usr/local/Cellar/grass-70/7.0.0/grass-7.0.0',
  #       location: 'world'
  #     }
  #
  #     GrassGis.session configuration do
  #       r.resamp.stats '-n', input: "map1@mapset1", output: "map2"
  #       cmd = g.list 'vect'
  #       puts cmd.output
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
    context.allocate
    context.instance_eval(&blk)
  ensure
    context.dispose
  end

end
