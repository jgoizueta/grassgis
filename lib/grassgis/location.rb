module GrassGis
  class Location
    def initialize(context)
      @context = context
      @configuration = @context.configuration
      @gisdbase = @configuration[:gisdbase]
      @location = @configuration[:location]
      @path = File.join(@gisdbase, @location)
    end

    attr_reader :path

    def to_s
      @location
    end

    def exists?
      File.directory?(@path)
    end

    def create!(options = {})
      raise Error, "Location #{@location} already exists" if exists?
      raise Error, "A file with the same name #{@location} exists" if File.exists?(@path)
      raise Error, "GRASSDBASE doesn't exist" unless File.directory?(@gisdbase)
      epsg = options[:epsg]
      limits = options[:limits]
      desc = options[:desc]
      raise Error, "An EPSG code is needed to define a new loaction" unless epsg
      @context.g.proj '-t', epsg: epsg, location: @location
      permanent = permanent_path
      if desc
        desc_file = File.join(permanent, 'MYNAME')
        File.write desc_file, desc
      end
      if limits
        w, s, e, n = limits
        res = options[:res]
        # @context.g.mapset mapset: 'PERMANENT', location: @location
        @context.change_mapset 'PERMANENT'
        @context.g.region w: w, s: s, e: e, n: n, res: res
        FileUtils.cp File.join(permanent, 'WIND'), File.join(permanent, 'DEFAULT_WIND')
      end
    end

    def mapset_path(mapset)
      File.join(@path, mapset)
    end

    def permanent_path
      mapset_path('PERMANENT')
    end
  end
end
