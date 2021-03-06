require File.expand_path("../../spec_helper", __FILE__)

describe Ripple::Properties do
  require 'support/models/email'

  it "should make the model class have a property definition method" do
    Email.should respond_to(:property)
  end

  it "should add properties to the class via the property method" do
    Email.property :from, String
    Email.properties.should include(:from)
  end

  it "should make the model class have a collection of properties" do
    Email.should respond_to(:properties)
    Email.properties.should be_kind_of(Hash)
  end

  it "should make subclasses inherit properties from the parent class" do
    Email.properties[:foo] = "bar"
    class Forward < Email; end
    Forward.properties[:foo].should == "bar"
  end
end

describe Ripple::Property do
  it "should have a key symbol" do
    prop = Ripple::Property.new('foo', String)
    prop.should respond_to(:key)
    prop.key.should == :foo
  end

  it "should have a type" do
    prop = Ripple::Property.new('foo', String)
    prop.should respond_to(:type)
    prop.type.should == String
  end

  it "should capture extra options" do
    prop = Ripple::Property.new('foo', String, 'default' => "bar")
    prop.should respond_to(:options)
    prop.options.should == {:default => "bar"}
  end

  it "should expose validation options" do
    prop = Ripple::Property.new('foo', String, 'default' => "bar", :presence => true)
    prop.validation_options.should == {:presence => true}
  end

  describe "default value" do
    it "should be nil when not specified" do
      prop = Ripple::Property.new('foo', String)
      prop.default.should be_nil
    end

    it "should allow literal values" do
      prop = Ripple::Property.new('foo', String, :default => "bar")
      prop.default.should == "bar"
    end

    it "should cast to the proper type" do
      prop = Ripple::Property.new('foo', String, :default => :bar)
      prop.default.should == "bar"
    end

    it "should allow false for a Boolean" do
      prop = Ripple::Property.new('foo', Boolean, :default => false)
      prop.default.should == false
    end

    it "should allow lambdas for deferred evaluation" do
      prop = Ripple::Property.new('foo', String, :default => lambda { "bar" })
      prop.default.should == "bar"
    end
  end

  describe "casting a value" do
    describe "when type is Boolean" do
      before :each do
        @prop = Ripple::Property.new('foo', Boolean)
      end

      [0, 0.0, "", [], false, "f", "FALSE"].each do |v|
        it "should cast #{v.inspect} to false" do
          @prop.type_cast(v).should == false
        end
      end

      [1, 1.0, "true", "1", [1], true, "t", "TRUE"].each do |v|
        it "should cast #{v.inspect} to true" do
          @prop.type_cast(v).should == true
        end
      end

      it "should not cast nil" do
        @prop.type_cast(nil).should be_nil
      end
    end

    describe "when type is String" do
      before :each do
        @prop = Ripple::Property.new('foo', String)
      end

      it "should cast anything to a string using to_s" do
        @prop.type_cast("s").should == "s"
        @prop.type_cast(1).should == "1"
        @prop.type_cast(true).should == "true"
        @prop.type_cast(false).should == "false"
        if RUBY_VERSION < "1.9"
          @prop.type_cast([]).should == ""
        else
          @prop.type_cast([]).should == "[]"
        end
      end

      it "should not cast nil" do
        @prop.type_cast(nil).should be_nil
      end

    end

    describe "when type is an Integer type" do
      before :each do
        @prop = Ripple::Property.new(:foo, Integer)
      end

      [5.0, "5", "     5", "05", Rational(10,2)].each do |v|
        it "should cast #{v.inspect} to 5" do
          @prop.type_cast(v).should == 5
        end
      end

      [0.0, "0", "     000"].each do |v|
        it "should cast #{v.inspect} to 0" do
          @prop.type_cast(v).should == 0
        end
      end

      it "should not cast the blank string" do
        @prop.type_cast("").should be_nil
        @prop.type_cast("   ").should be_nil
      end

      [true, false, [], {}, :symbol, ["something else"]].each do |v|
        it "should raise an error casting #{v.inspect}" do
          lambda { @prop.type_cast(v) }.should raise_error(Ripple::PropertyTypeMismatch)
        end
      end
    end

    describe "when type is a Float type" do
      before :each do
        @prop = Ripple::Property.new(:foo, Float)
      end

      [0, "0", "0.0", "    0.0"].each do |v|
        it "should cast #{v.inspect} to 0.0" do
          @prop.type_cast(v).should == 0.0
        end
      end

      [5.0, "5", "     5.0", "05", Rational(10,2)].each do |v|
        it "should cast #{v.inspect} to 5.0" do
          @prop.type_cast(v).should == 5.0
        end
      end

      it "should not cast the blank string" do
        @prop.type_cast("").should be_nil
        @prop.type_cast("   ").should be_nil
      end

      [true, false, :symbol, [], {}].each do |v|
        it "should raise an error casting #{v.inspect}" do
          lambda { @prop.type_cast(v) }.should raise_error(Ripple::PropertyTypeMismatch)
        end
      end
    end

    describe "when type is a Numeric type" do
      before :each do
        @prop = Ripple::Property.new(:foo, Numeric)
      end

      [5.0, "5", "      5.0", "05"].each do |v|
        it "should cast #{v.inspect} to 5" do
          @prop.type_cast(v).should == 5
        end
      end

      [5.2, "5.2542", "   6.4", "0.5327284"].each do |v|
        it "should cast #{v.inspect} to a float" do
          @prop.type_cast(v).should be_kind_of(Float)
        end
      end

      it "should not cast the blank string" do
        @prop.type_cast("").should be_nil
        @prop.type_cast("   ").should be_nil
      end
    end

    describe "when type is a Time type" do
      before :each do
        @prop = Ripple::Property.new(:foo, Time)
      end

      ["Tue, 16 Mar 2010 12:00:00 -0000","2010/03/16 12:00:00 GMT", Time.utc(2010,03,16,12)].each do |v|
        it "should cast #{v.inspect} to #{Time.utc(2010,03,16,12).inspect}" do
          @prop.type_cast(v).should == Time.utc(2010,03,16,12)
        end
      end

      it "should not cast blank types" do
        @prop.type_cast([]).should be_nil
        @prop.type_cast({}).should be_nil
        @prop.type_cast("").should be_nil
        @prop.type_cast("  ").should be_nil
      end
    end

    describe "when type is a Date type" do
      before :each do
        @prop = Ripple::Property.new(:foo, Date)
      end

      ["Tue, 16 Mar 2010 00:00:00 -0000", "2010/03/16 12:00:00 GMT", Time.utc(2010,03,16,12), "2010/03/16"].each do |v|
        it "should cast #{v.inspect} to 2010/03/16" do
          @prop.type_cast(v).should == Date.civil(2010,3,16)
        end
      end

      it "should not cast blank types" do
        @prop.type_cast([]).should be_nil
        @prop.type_cast({}).should be_nil
        @prop.type_cast("").should be_nil
        @prop.type_cast("  ").should be_nil
      end
    end

    describe "when type is a Set type" do
      let(:prop) { Ripple::Property.new(:foo, Set) }

      it "casts an array to a a set" do
        prop.type_cast([1]).should be_a(Set)
        prop.type_cast([1]).to_a.should == [1]
      end

      it "raises an error when casting a non-enumerable" do
        expect {
          prop.type_cast(1)
        }.to raise_error(Ripple::PropertyTypeMismatch)
      end
    end
  end
end

describe Ripple::Document do
  let(:custom_data)        { Subscription::MyCustomType.new('bar') }
  let(:days_of_month)      { Set.new([1, 7, 15, 23]) }
  let(:subscription)       { Subscription.create!(:custom_data => custom_data, :days_of_month => days_of_month) }
  let(:found_subscription) { Subscription.find(subscription.key) }

  it 'allows properties with custom types to be saved and restored from riak' do
    found_subscription.custom_data.should == custom_data
  end

  it 'allows Set properties to be saved and restored from riak' do
    found_subscription.days_of_month.should == days_of_month
  end
end
