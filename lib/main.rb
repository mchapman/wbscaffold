require 'active_support/inflector'

class RailsField
  attr_reader :name, :mysql_type, :length, :precision, :scale, :is_not_null

  def initialize(field_string)
    @name, @mysql_type, @length, @precision, @scale, @is_not_null = field_string.split(/\s*\,\s*/)
#    @name = @name.singularize
    if @mysql_type[0..6]=='VARCHAR'
      @mysql_type = 'VARCHAR'
    end
  end

  def rails_field_type
    case @mysql_type
    when "FLOAT","DATE","TEXT","DATETIME"
       rails_type = @mysql_type.downcase
    when "INT"
        rails_type = 'integer'
    when "VARCHAR"
      rails_type = 'string'
    when "BIT"
      rails_type = 'boolean'
    else
      raise "Unsupported data type #{@mysql_type}"
    end
    return rails_type
  end

  def scaffold_instruction
    if @name == 'id' or @name[-3..-1] == '_id'
      result = ""
    else
      result = "#{name}:#{rails_field_type} "
    end
    return result
  end

  def migration_line(rails_scaffold_line)
    result = rails_scaffold_line
    result = result + ", :null => false" if is_not_null == "1"
    result = result + ", :limit => #{@length}" if @mysql_type == 'VARCHAR'
    result = result + ", :precision => #{precision}" if @precision != "-1"
    result = result + ", :scale => #{scale}" if @scale != "-1"
    return result
  end

end

class RailsKey
  attr_reader :singular_name, :plural_name, :many, :mandatory

  def initialize(key_string)
    name, @many, @mandatory = key_string.split(/\s*\,\s*/)[0]
    @singular_name = name.singularize
    @plural_name = @singular_name.pluralize
  end

end

class RailsModel
  attr_reader :singular_name, :plural_name, :fields, :keys

  def initialize(a_string)
    name, fields_string, keys_string = a_string.split(/\s*\:\s*/)
    @plural_name = name.pluralize
    @singular_name = plural_name.singularize
    @fields = []
    fields_string.split(/\s*\#\s*/).each { |a_field_string| @fields << RailsField.new(a_field_string)} unless fields_string.nil?
    @keys = []
    keys_string.split(/\s*\#\s*/).each { |a_key_string| @keys << RailsKey.new(a_key_string)} unless keys_string.nil?
  end

#def modelize(table_name)
#  table_name.singularize.camelize.gsub('_','')
#end

  def scaffold_field_type_list
    list = ""
    @fields.each {|field| list << field.scaffold_instruction}
    list
  end

  def generate_scaffold
    system("rails generate scaffold #{@singular_name} #{scaffold_field_type_list}")
  end

  def get_migration_name_in_folder(railsbase)
    result = nil
    partial_name = "_create_#{plural_name}.rb"
    partial_length = partial_name.length
    Dir.entries("#{railsbase}/db/migrate").each { |filename| result = filename if filename[-partial_length..-1] == partial_name }
    if result.nil?
      raise "No migration file for '#{name}'.  Perhaps you weren't following rails conventions of plurality?"
    end
    return result
  end

  def find_field(field_name)
    result = nil
    fields.each {|field| result = field if field.name == field_name }
    return result
  end

  def find_key(key_singular_name)
    result = nil
    keys.each {|key| result = key if key.singular_name == key_singular_name }
    return result
  end

  def complete_migration_file(railsbase)
    f = File.new("#{railsbase}/db/migrate/#{get_migration_name_in_folder(railsbase)}",'r+')
    fa = f.readlines
    f.rewind
    section = 0    # 0=before fields, 1=in fields section, 2=after fields
    fa.each do |line|
      if (section < 2)
        if line =~ /t.[\w]* :([\w_]*)$/   # extract the field name, only if it is last thing on the line
          section = 1
          field = find_field($1)
          line = field.migration_line(line.chomp)
        elsif line.strip == 't.timestamps'
          section = 2
          # add any foreign key fields here
          keys.each do |key|
            field_name = "#{key.singular_name}_id"
            field = find_field(field_name)
            if field.nil?
              # The workbench diagram was not properly "rails-ified"
              # Just create an integer field, and warn if the plural equivalent isn't found
              puts "Warning: Would have expected to find field #{field_name} in #{plural_name} table" if find_field("#{key.plural_name}_id").nil?
              f.puts("      t.integer :#{field_name}")
            else
              insert_line = "      t.#{field.rails_field_type} :#{field_name}"
              f.puts(field.migration_line(insert_line))
            end
          end
        end
      end
      f.puts(line)
    end
  end

  # Add validation, belongs to, etc to models
  def update_model(wbs)
    f = File.new("#{wbs.railsbase}/app/models/#{singular_name}.rb",'r+')
    fa = f.readlines
    f.rewind
    f.puts(fa[0])

    # handle validation for not nulls
    validates = ""
    fields.each {|field| validates = "#{validates} :#{field.name}," if field.is_not_null == 1 }
    f.puts("  validates #{validates} :presence => true") if validates != ""

    # handle belongs_to
    keys.each {|key| f.puts("  belongs_to :#{key.singular_name}")}

    # handle has_one and has_many
    wbs.models.each do |model|
      key = model.find_key(singular_name)
      if not key.nil?
        if key.many
          f.puts("  has_many :#{key.plural_name}")
        else
          f.puts("  has_one :#{key.singular_name}")
        end
      end
    end
    f.puts(fa[1])
  end

end

class Wbscaffold

  attr_reader :models, :railsbase

  def initialize(default_input, default_railsbase, args)
    @models = []
    @input = default_input
    @railsbase = default_railsbase
    nocheck = false
    args.each do |arg|
      if arg =~ /^-input=/i
        @input = $'
      elsif arg =~ /^-railsbase=/i
        @railsbase = $'
      elsif arg == '-nocheck'
        nocheck = true
      end
    end
    if @input.nil? or @railsbase.nil? then
      raise "Must specify input file and rails base folder"
    end
    if nocheck == false
      if Dir.exist?@railsbase
        raise "Only works with new rails base folders"
      end
    end
  end

  def parse_input_file
    @models = []
    f = File.new(@input)
    while line = f.gets
      @models << RailsModel.new(line.chomp) if line =~ /\w/       # otherwise you get a blank line - must be a more elegant way but I don't know it yet
    end
  end

  def create_rails_app
    if @railsbase =~ /\/([^\/]*)$/                # look for the last / character
      project_folder = $`
      rails_folder = $1
    else
      project_folder = Dir.getwd
      rails_folder = @railsbase
    end
    Dir.chdir(project_folder) do
      system("rails new #{rails_folder} -d mysql")   # Tried to find a way of using ` to capture the output but gave up
      Dir.chdir(rails_folder) do
        models.each do |model|
          puts "Processing #{model.plural_name}"
          model.generate_scaffold
          model.complete_migration_file(railsbase)
          model.update_model(self)
        end
      end
    end
  end
  
  def find(model_name)
    result = nil
    models.each {|model| result = model if model.name == model_name }
    return result
  end

end

if __FILE__ == $0
  wbs = Wbscaffold.new('/home/mark/Documents/Structure.exp', '/home/mark/Projects/TestScaff', ARGV)
#  wbs = Wbscaffold.new('/home/mark/Documents/Structure.exp', '/home/mark/Projects/TestScaff', ["-nocheck"])
  wbs.parse_input_file
  wbs.create_rails_app
#  model = wbs.find('organisation_addresses')
#  model.update_model(wbs)
end
