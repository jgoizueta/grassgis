module GrassGis
  class Mapset
    def initialize(context)
      @context = context
      @configuration = @context.configuration
      @location = Location.new(@context)
      @mapset = @configuration[:mapset]
      @path = File.join(@location.path, @mapset)
    end

    attr_reader :path

    def to_s
      @mapset
    end

    def exists?
      File.directory?(@path)
    end

    def create!(options = {})
      raise Error, "Mapset #{@mapset} already exists" if exists?
      raise Error, "A file with the same name #{@mapset} exists" if File.exists?(@path)
      raise Error, "Location doesn't exist" unless @location.exists?
      # @context.g.mapet '-c', mapset: @mapset, location: @location.to_s, dbase: @configuration[:gisdbase]
      FileUtils.mkdir_p @path
      permanent = @location.permanent_path
      FileUtils.cp File.join(permanent, 'DEFAULT_WIND'), File.join(@path, 'WIND')
    end
  end
end
