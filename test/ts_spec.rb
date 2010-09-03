require "main.rb"

describe RailsField do
  before do
    @field=RailsField.new("name,VARCHAR(45),45,-1,-1,1")
  end
  it "parses the name" do
    @field.name.should == "name"
  end
  it "gets correct field type" do
    @field.mysql_type.should == "VARCHAR"
  end
  it "gets correct length" do
    @field.length.should == "45"
  end
  it "gets correct precision" do
    @field.precision.should == "-1"
  end
  it "gets correct scale" do
    @field.scale.should == "-1"
  end
  it "gets not null value" do
    @field.is_not_null.should == "1"
  end
  it "knows whether field is input field" do
    @field.rails_input.should == true
  end
  it "updates migration fields correctly" do
    @field.migration_line("t.string :name").should == "t.string :name, :null => false, :limit => 45"
  end
end

describe RailsKey,"parsing" do
  before do
    @key=RailsKey.new("people,1,1")
  end
  it "parses the singular name" do
    @key.singular_name.should == "person"
  end
  it "parses the plural name" do
    @key.plural_name.should == "people"
  end
  it "parses the modality" do
    @key.many.should == "1"
  end
  it "parses the mandatory flag" do
    @key.mandatory.should == "1"
  end
end

describe RailsModel,"parsing" do
  before do
    @model = RailsModel.new("organisations:id,INT,-1,-1,-1,1#name,VARCHAR(45),45,-1,-1,1:")
  end
  it "parses the singular name" do
    @model.singular_name.should == "organisation"
  end
  it "parses the plural name" do
    @model.plural_name.should == "organisations"
  end
  it "parses the fields" do
    @model.fields.count.should == 2
  end
  it "parses the keys" do
    @model.keys.count.should == 0
  end
  it "generates scaffold correctly" do
    @model.scaffold_field_type_list.should == "name:string "
  end
  it "generates validation correctly" do
    @model.validation_line.should == "  validates :name, :presence => true"
  end
end

describe RailsModel, "update migration" do
  before do
    @model = RailsModel.new("line_item:id,INT,-1,-1,-1,1#quantity,INT(11),-1,-1,-1,1#orders_id,INT,-1,-1,-1,1#products_id,INT,-1,-1,-1,1#carts_id,INT,-1,-1,-1,1:orders,1,1#products,1,1#carts,1,1")
    @mfa =
["class CreateLineItems < ActiveRecord::Migration",
"  def self.up",
"    create_table :line_items do |t|",
"      t.integer :quantity",
"",
"      t.timestamps",
"    end",
"  end",
"",
"  def self.down",
"    drop_table :line_items",
"  end",
"end"]
    @new_fa = @model.modify_migration_file_array(@mfa)
  end
  it "updates the migration lines" do
    @new_fa.count.should == @mfa.count + 3
  end
  it "adds lookup column" do
    @new_fa[5].should == "      t.integer :order_id"
  end
end

describe Wbscaffold,"belongs to" do
  before do
    wbs = Wbscaffold.new("fake_input","~/fake_rails_base",[])
    wbs.models << RailsModel.new("carts:id,INT,-1,-1,-1,1:")
    wbs.models << RailsModel.new("line_item:id,INT,-1,-1,-1,1#quantity,INT(11),-1,-1,-1,1#orders_id,INT,-1,-1,-1,1#products_id,INT,-1,-1,-1,1#carts_id,INT,-1,-1,-1,1:orders,1,1#products,1,1#carts,1,1")
    wbs.models << RailsModel.new("products:id,INT,-1,-1,-1,1#title,VARCHAR(45),45,-1,-1,1#description,TEXT,-1,-1,-1,0#image_url,VARCHAR(45),45,-1,-1,0#price,FLOAT,-1,-1,-1,0:")
    wbs.models << RailsModel.new("orders:id,INT,-1,-1,-1,1#name,VARCHAR(45),45,-1,-1,1#address,VARCHAR(45),45,-1,-1,1#email,VARCHAR(45),45,-1,-1,1#pay_type,VARCHAR(45),45,-1,-1,1:")
    array = ["class LineItem < ActiveRecord::Base","end"]
    @new_array = wbs.find('line_item').prepare_model_changes(array, wbs)
  end
  it "adds validation to model" do
    @new_array[1].should == "  validates :quantity, :presence => true"
  end
  it "blah" do
    @new_array[2].should == "  belongs_to :order"
  end
  it "blah" do
    @new_array[3].should == "  belongs_to :product"
  end
  it "blah" do
    @new_array[4].should == "  belongs_to :cart"
  end
end

describe Wbscaffold,"has..." do
  before do
    wbs = Wbscaffold.new("fake_input","~/fake_rails_base",[])
    wbs.models << RailsModel.new("carts:id,INT,-1,-1,-1,1:")
    wbs.models << RailsModel.new("line_item:id,INT,-1,-1,-1,1#quantity,INT(11),-1,-1,-1,1#orders_id,INT,-1,-1,-1,1#products_id,INT,-1,-1,-1,1#carts_id,INT,-1,-1,-1,1:orders,1,1#products,1,1#carts,1,1")
    wbs.models << RailsModel.new("products:id,INT,-1,-1,-1,1#title,VARCHAR(45),45,-1,-1,1#description,TEXT,-1,-1,-1,0#image_url,VARCHAR(45),45,-1,-1,0#price,FLOAT,-1,-1,-1,0:")
    wbs.models << RailsModel.new("orders:id,INT,-1,-1,-1,1#name,VARCHAR(45),45,-1,-1,1#address,VARCHAR(45),45,-1,-1,1#email,VARCHAR(45),45,-1,-1,1#pay_type,VARCHAR(45),45,-1,-1,1:")
    wbs.models << RailsModel.new("testobjects:id,INT,-1,-1,-1,1#description,VARCHAR(11),11,-1,-1,1:orders,0,1")
    array = ["class Order < ActiveRecord::Base","end"]
    @new_array = wbs.find('order').prepare_model_changes(array, wbs)
  end
  it "handles validation" do
    @new_array[1].should == "  validates :name, :address, :email, :pay_type, :presence => true"
  end
  it "handles has_many" do
    @new_array[2].should == "  has_many :line_items"
  end
  it "handles has_one" do
    @new_array[3].should == "  has_one :testobject"
  end
end