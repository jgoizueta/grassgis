module GrassGis
  # Convenient shortcuts and tools for use in GRASS sessions
  # Currently only implemented for GRASS 7
  module Tools
    def map_exists?(map, options = {})
      types = Array(options[:type])
      types = 'all' if types.empty?
      mapsets = []
      if map.include?('@')
        map, mapset = map.split('@')
        mapsets << mapset
      end
      mapsets += Array(options[:mapset])
      if mapsets.empty?
        g.list types.join(',')
      else
        g.list types.join(','), mapset: mapsets.join(',')
      end
      maps = output.split.map { |m| m.split('@').first }
      maps.include?(map)
    end

    def raster_exists?(map, options = {})
      map_exists? map, options.merge(type: 'rast')
    end

    def vector_exists?(map, options = {})
      map_exists? map, options.merge(type: 'vect')
    end

    def shell_to_hash
      Hash[output.lines.map{|l| l.strip.split('=')}]
    end

    def raster_info(map)
      r.info '-g', map
      shell_to_hash
    end

    def region_info
      g.region '-m'
      shell_to_hash
    end

    def raster_res(map)
      info = raster_info(map)
      info.values_at('ewres', 'nsres').map(&:to_i)
    end

    def region_res
      info = region_info
      info.values_at('ewres', 'nsres').map(&:to_i)
    end

    def current_mapset
      g.mapsets '-p'
      current_mapset = output.lines.to_a.last.split.first
    end

    def with_mapset(mapset)
      current = current_mapset
      if mapset != current
        change_mapset mapset
      end
      yield self
      if mapset != current
        change_mapset current
      end
    end

    def available_mapsets
      g.mapsets '-l'
      output.lines.to_a.last.split
    end

    def accessible_mapsets
      g.mapsets '-p'
      output.lines.to_a.last.split
    end

    def explicit_map_mapset(map)
      if map.include?('@')
        map.split('@').last
      end
    end

    def map_mapset(map, options = {})
      if map.include?('@')
        map.split('@').last
      else
        type = options[:type]
        raise "Must specify type of the map" unless type
        accessible = accessible_mapsets
        accessible.each do |mapset|
          return mapset if map_exists?(map, type: type, mapset: mapset)
        end
        available = available_mapsets - accessible
        available.each do |mapset|
          return mapset if map_exists?(map, type: type, mapset: mapset)
        end
        nil
      end
    end

    def remove_map(map, options = {})
      type = options[:type]
      raise "Must specify type to remove a map" unless type
      mapset = explicit_map_mapset(map) || options[:mapset] || map_mapset(map, type: type)
      raise "Map not found #{map} (#{type})" unless mapset
      with_mapset(mapset) do
        if grass_version >= GrassGis.version('7.0.0')
          g.remove '-f', type: type, name: map
        else
          param = { vector: 'vect', raster: 'rast', raster_3d: 'rast3d' }[type.to_sym]
          g.remove '-f', param => map
        end
      end
    end

    def copy_map(map, options = {})
      type = options[:type]
      raise "Must specify type to copy a map" unless type
      if map.include?('@')
        map, mapset = map.split('@').last
      end
      from_mapset = options[:from]
      if from_mapset && from_mapset != mapset
        raise "Inconsistent origin mapset"
      end
      from_mapset ||= mapset
      unless from_mapset
        from_mapset = map_mapset(map, type: options[:type])
      end
      to_mapset = options[:to]
      unless from_mapset && to_mapset
        raise "Must specify origin and destination mapsets"
      end
      if from_mapset != to_mapset
        original_map = "#{map}@#{from_mapset}"
        with_mapset to_mapset do
          if grass_version >= GrassGis.version('7.0.0')
            g.copy type => [original_map, map]
          else
            param = { vector: 'vect', raster: 'rast', raster_3d: 'rast3d' }[type.to_sym]
            g.copy param => [original_map, map]
          end
        end
        original_map
      end
    end

    def create_mapset(mapset)
      if true
        # TODO: if mapset optional argument added to Mapset constructor:
        # ms = GrassGis::Mapset.new(self, mapset)
        keep_mapset = configuration[:mapset]
        configuration[:mapset] = mapset
        ms = GrassGis::Mapset.new(self)
        ms.create! unless ms.exists?
        configuration[:mapset] = keep_mapset
      else
        # This will fail under windows
        current = current_mapset
        g.mapset '-c',
          mapset: mapset,
          location: configuration[:location],
          dbase: configuration[:gisdbase]
        g.mapset current
      end
    end

    def move_map(map, options = {})
      original_map = copy_map(map, options)
      remove_map original_map, type: options[:type]
    end

    def resamp_average(options = {})
      input_raster = options[:input]
      raise "Raster #{input_raster} not found" unless raster_exists?(input_raster)
      input_res = raster_res(input_raster)

      if options[:output_res]
        output_res = options[:output_res]
        unless output_res.is_a?(Array)
          output_res = [output_res, output_res]
        end
      else
        output_res = region_res
      end

      output_raster = options[:output]

      if options[:direction]
        unless raster_exists?("#{input_raster}_sin")
          g.region ewres: input_res[0], nsres: input_res[1]
          r.mapcalc "#{input_raster}_sin = sin(#{input_raster})"
        end
        unless raster_exists?("#{input_raster}_cos")
          g.region ewres: input_res[0], nsres: input_res[1]
          r.mapcalc "#{input_raster}_cos = cos(#{input_raster})"
        end
        g.region ewres: output_res[0], nsres: output_res[1]
        r.resamp.stats input: "#{input_raster}_cos", output: "#{output_raster}_cos"
        r.resamp.stats input: "#{input_raster}_sin", output: "#{output_raster}_sin"
        r.mapcalc "#{output_raster} = atan(#{output_raster}_cos,#{output_raster}_sin)"
        r.colors map: ouput_raster, raster: input_raster
        g.remove '-f', type: 'raster', name: ["#{output_raster}_cos", "#{output_raster}_sin"]
      else
        g.region ewres: output_res[0], nsres: output_res[1]
        r.resamp.stats input: input_raster, output: output_raster
        r.colors map: output_raster, raster: input_raster
      end
    end
  end
end
