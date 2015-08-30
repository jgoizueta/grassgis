# Recipes can only be defined when input parameters, files and maps are specific
# (although an input file can be a directory with an indetermninate number of files inside)
# and there's no dependency between input parameters/files/maps and which products are
# generated. (so the generated products are also specific, except, again, for the contents
# of directories).
# Also, recipes shouldn't generate any non-declared maps, i.e. temporary or
# auxiliary maps should be removed before the recipe ends.
#
# Temporary maps & files support, e.g.: temporaries are declared,
# then recipe is executed in a block with a ensure which removes temporary maps
#
# Example:
#
#     GrassCookbook.recipe :dem_base_from_mdt05 do
#       description %{
#         Generate a DEM for the interest area at fixed 5m resolution
#         from CNIG's MDT05 data.
#       }
#
#       required_files 'data/MDT05'
#       generated_raster_maps 'dem_base'
#
#       process do |mdt05_sheets|
#         ...
#       end
#     end
#
#     GrassCookbook.recipe :dem_base_derived do
#      description %{
#        Generate DEM-derived maps from the 5m dem base:
#        slope, aspect and relief shading
#      }
#
#      required_raster_maps 'dem_base'
#      generated_raster_maps 'shade_base', 'slope_base', 'aspect_base'
#
#      process do
#        r.relief input: 'dem_base', output: 'shade_base'
#        r.slope.aspect elevation: 'dem_base',
#                       slope:     'slope_base',
#                       aspect:    'aspect_base'
#      end
#    end
#
#    GrassCookbook.recipe :working_dem do
#      description %{
#        Generate DEM data at working resolution
#      }
#
#      required_raster_maps 'dem_base', 'slope_base', 'aspect_base'
#      generated_raster_maps 'dem', 'slope', 'aspect'
#
#      process do |resolution|
#        ...
#      end
#    end
#
#    # Now use our recipes to compute some permanent base maps and
#    # alternative scenario mapsheets varying some parameter.
#
#
#    GrassGis.session grass_config do
#      # First generate maps using fixed parameters and move them to PERMANENT
#      fixed_parameters = { mdt05_sheets: %w(0244 0282) }
#      fixed_data = primary = GrassCookbook::Data[
#        parameters: fixed_parameters.keys,
#        files: GrassCookbook.existing_external_input_files
#      ]
#      plan = GrassCookbook.plan(fixed_data)
#      permanent = plan.last
#      GrassCookbook.replace_existing_products self, plan
#      GrassCookbook.execute self, fixed_parameters, plan
#      permanent.maps.each do |map, type|
#        move_map(map, type: type, to: 'PERMANENT')
#      end
#
#      # Then define some variations of other parameters and create a mapset
#      # for each variation, where maps dependent on the varying parameters
#      # will be put
#      variants = {
#        '10m' => { resolucion: 10 },
#        '25m' => { resolucion: 25 }
#      }
#      for variant_name, variant_parameters in variants
#         data = GrassCookbook::Data[parameters: variant_parameters.keys] + permanent
#         plan = GrassCookbook.plan(data)
#         GrassCookbook.replace_existing_products self, plan
#         GrassCookbook.execute self, fixed_parameters.merge(variant_parameters), plan
#         variant_maps = (plan.last - data).maps
#         create_mapset variant_name
#         variant_maps.each do |map, type|
#           move_map(map, type: type, to: variant_name)
#         end
#       end
#     end
#
#
module GrassCookbook

  # Datasets used by recipes, consist of parmeters, maps and files
  # (or directories). Recipes use them to define both required and
  # generated data.
  class Data
    def initialize(params = {})
      @parameters = params[:parameters] || []
      @files = params[:files] || []
      @maps = params[:maps] || []
    end

    attr_reader :parameters, :files, :maps

    def vector_maps
      @maps.select { |m, t| t == :vector }.map(&:first)
    end

    def raster_maps
      @maps.select { |m, t| t == :raster }
    end

    def merge!(data)
      data = Data[data]
      @parameters = (@parameters + data.parameters).uniq
      @maps = (@maps + data.maps).uniq
      @files = (@files + data.files).uniq
      self
    end

    def dup
      Data.new.merge! self
    end

    def self.[](params)
      unless params.is_a?(Data)
        params = Data.new(params)
      end
      params
    end

    def present?
      @parameters.size > 0 || @files.size > 0 || @maps.size > 0
    end

    def empty?
      !present?
    end

    def -(other)
      other = Data[other]
      Data[
        parameters: parameters - other.parameters,
        files: files - other.files,
        maps: maps - other.maps
      ]
    end

    def +(other)
      dup.merge! other
    end

    # data which is requiered but not provided here
    def missing(required)
      Data[required] - self
    end

    def to_s
      txt = "Datos:\n"
      txt << "  Parametros: #{parameters.inspect}\n"
      txt << "  Archivos: #{files.inspect}\n"
      txt << "  Mapas: #{maps.inspect}\n"
      txt
    end
  end

  @recipes = {}

  # A recipe uses some Data and generates other Data in
  # a GRASS session.
  class Recipe
    def initialize(options = {}, &blk)
      @id = options[:id].to_sym
      @description = options[:description] || "Proceso #{@id}"
      @process = blk
      @required_parameters = blk.parameters.map(&:last)
      @required_raster_maps = Array(options[:required_raster_maps])
      @required_vector_maps = Array(options[:required_vector_maps])
      @required_files = Array(options[:required_files])
      @generated_vector_maps = Array(options[:generated_vector_maps])
      @generated_raster_maps = Array(options[:generated_raster_maps])
      @generated_files = Array(options[:generated_files])
      @generated_parameters = Array(options[:generated_parameters])
    end

    attr_reader :id, :description
    attr_reader :required_raster_maps, :required_vector_maps, :required_files
    attr_reader :required_parameters
    attr_reader :generated_raster_maps, :generated_vector_maps, :generated_files
    attr_reader :generated_parameters

    # inputs
    def requirements
      Data[parameters: required_parameters, files: required_files, maps: required_maps]
    end

    # outputs
    def products
      Data[parameters: generated_parameters, files: generated_files, maps: generated_maps]
    end

    def required_maps
      required_raster_maps.map { |map| [map, :raster] } +
      required_vector_maps.map { |map| [map, :vector] }
    end

    def generated_maps
      generated_raster_maps.map { |map| [map, :raster] } +
      generated_vector_maps.map { |map| [map, :vector] }
    end

    # Can the recipe be done given provided input?
    def doable?(input)
      # input.missing(requirements).empty?
      (requirements - input).empty?
    end

    # Is the recipe unnecessary given existing data?
    def done?(existing)
      (products - existing).empty?
    end

    # Execute the recipe with given parameters # TODO: mapset PATH
    def cook(grass, parameters = {})
      # grass.g.mapsets '-p'
      # current_mapset = output.lines.last.split.first

      # Leave planning/checking if doable to the caller; not done here:
      # unless doable? GrassCookbook.available_data(grass, parameters)
      #   raise "Requirements for #{@id} not fulfilled"
      # end

      # Also not done here:
      # if done? GrassCookbook.available_data(grass, parameters)
      #   return
      # end

      args = parameters.values_at(*@required_parameters)
      # @process.call grass, *args
      # grass.session &@process, arguments: args
      # TODO: support in GrassGis for injecting/replacing locals
      grass.define_singleton_method(:parameters) { @parameters }
      grass.instance_exec *args, &@process
    end

    def to_s
      @description
    end

    def inspect
      "<GrassCookbook::Recipe #{@id.inspect}>"
    end

    def eql?(other)
      @id == other.id
    end

    def ==(other)
      eql? other
    end

    def hash
      @id.hash
    end
  end

  # DSL to define recipes
  class RecipeDsl
    def initialize(id)
      @id = id.to_sym
      @required_raster_maps = []
      @required_vector_maps = []
      @required_files = []
      @generated_raster_maps = []
      @generated_vector_maps = []
      @generated_files = []
      @generated_parameters = []
      @description = nil
    end

    def description(text)
      @description = GrassGis::Support.unindent(text)
    end

    def required_raster_maps(*maps)
      @required_raster_maps += maps
    end

    def required_vector_maps(*maps)
      @required_vector_maps += maps
    end

    def required_files(*files)
      @required_files += files
    end

    def generated_vector_maps(*maps)
      @generated_vector_maps += maps
    end

    def generated_raster_maps(*maps)
      @generated_raster_maps += maps
    end

    def generated_files(*files)
      @generated_files += files
    end

    def generated_parameters(*parameters)
      @generated_parameters += parameters
    end

    def process(&blk)
      @process = blk
    end

    def recipe
      Recipe.new(
        id: @id,
        required_maps: @required_maps,
        required_files: @required_files,
        generated_raster_maps: @generated_raster_maps,
        generated_vector_maps: @generated_vector_maps,
        generated_files: @generated_files,
        generated_parameters: @generated_parameters,
        &@process
      )
    end
  end

  class <<self
    def recipe(id, &blk)
      dsl = RecipeDsl.new(id)
      dsl.instance_eval &blk
      @recipes[id.to_sym] = dsl.recipe
    end

    def [](recipe)
      if recipe.is_a? Recipe
        recipe
      else
        @recipes[recipe.to_sym]
      end
    end

    def cook(grass, recipe, parameters)
      grass.log "Recipe: #{recipe}"
      self[recipe].cook grass, parameters
    end

    def all_files_used
      @recipes.values.map(&:required_files).flatten.uniq
    end

    def all_maps_used
      @recipes.values.map(&:required_maps).flatten(1).uniq
    end

    def all_files_possible
      @recipes.values.map(&:generated_files).flatten.uniq
    end

    def all_maps_possible
      @recipes.values.map(&:generated_maps).flatten(1).uniq
    end

    def existing_input_files
      all_files_used.select { |f| File.exists?(f) }
    end

    def existing_input_maps(grass)
      # TODO: use mapset PATH here (add as another parameters)
      path = []
      all_maps_used.select { |m, t| grass.map_exists?(m, type: t, mapset: path) }
    end

    # Generate ordered recipes and generated products (output)
    # than can be obtained with available inputdata.
    def plan(input_data)
      input = Data[input_data]
      existing = input.dup

      applied_recipes = []

      remaining_recipes = @recipes.values - applied_recipes

      while remaining_recipes.size > 0
        progress = false
        remaining_recipes.each do |recipe|
          unless recipe.done?(existing)
            if recipe.doable?(existing)
              progress = true
              applied_recipes << recipe
              existing.merge! recipe.products
            end
          end
        end
        break unless progress
        remaining_recipes -= applied_recipes
      end
      [applied_recipes, existing - input]
    end

    def available_data(grass, parameters)
      Data[
        parameters: parameters,
        files: existing_input_files,
        maps: existing_input_maps(grass)
      ]
    end

    def achievable_results(grass, parameters)
      inputs = available_data(grass, parameters)
      inputs + plan(inputs).last
    end

    # primary input files
    # input files that exist (and are not generated, so they are externally provided input)
    def existing_external_input_files
      existing_input_files - all_files_possible
    end

    def permantent_results(grass, fixed_parameters)
      primary = Data[parameters: fixed_parameters, files: existing_external_input_files]
      plan(primary).last
    end

    def missing_input(grass)
      Data[
        files: all_files_used - existing_input_files,
        maps: all_maps_used - existing_input_maps(grass)
      ]
    end

    def impossible_results(grass, parameters)
      possibilities = Data[
        files: all_files_possible,
        maps:  all_maps_possible
      ]
      possibilities - achievable_results(grass, parameters)
    end

    def execute(grass, parameters, plan)
      recipes, result = plan
      recipes.each do |recipe|
        cook grass, recipe, parameters
      end
      result
    end

    def replace_existing_products(grass, plan, parameters = nil)
      results = plan.last
      if parameters
        results.parameters.each do |parameter|
          parameters.delete parameter
        end
      end
      results.maps.each do |map, type|
        mapset = grass.explicit_map_mapset(map) || grass.current_mapset
        if grass.map_exists?(map, type: type, mapset: mapset)
          grass.remove_map(map, type: type, mapset: mapset)
        end
      end
      results.files.each do |file|
        if File.exists?(file)
          if File.directory?(file)
            FileUtils.rm_rf file
          else
            FileUtils.rm file
          end
        end
      end
    end

  end
end
